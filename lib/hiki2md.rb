# -*- coding: utf-8 -*-
require 'hiki2md/version'
require 'cgi'
require 'thread'

class Hiki2md
  IMAGE_EXTENSIONS = %w[.jpg .jpeg .gif .png .bmp .svg].freeze
  UNSAFE_URI_SCHEMES = %w[javascript data vbscript].freeze
  MAX_MARKDOWN_LIST_DEPTH = 100
  MAX_BLOCKQUOTE_RECURSION = 100
  PLUGIN_TOKEN_RE = /\0(\d+)\0/
  BRACKET_LINK_RE = /\[\[.+?\]\]/
  URI_RE = /(?:https?|ftp|file|mailto):[A-Za-z0-9;\/?:@&=+$,\-_.!~*'()#%]+/
  WIKI_NAME_RE = /\b(?:[A-Z]+[a-z\d]+){2,}\b/
  MODIFIER_RE = /'''.+?'''|''.+?''|==.+?==|``.+?``/
  INLINE_RE = Regexp.union(
    /\0\d+\0/,
    BRACKET_LINK_RE,
    URI_RE,
    MODIFIER_RE,
    /\^?#{WIKI_NAME_RE}/
  )

  def initialize(interwiki_map: {}, use_wiki_name: true, preserve_plugins: false)
    @interwiki_map = interwiki_map
    @use_wiki_name = use_wiki_name
    @preserve_plugins = preserve_plugins
    @conversion_mutex = Mutex.new
  end

  def convert(source)
    @conversion_mutex.synchronize do
      normalized = source.to_s.gsub(/\r\n?/, "\n")
      nul_replacement = normalized.encoding == Encoding::UTF_8 ? "\uFFFD" : '?'
      normalized = normalized.gsub("\0", nul_replacement)
      @source_template = normalized[0, 0]
      escaped = extract_plugins(normalized)
      convert_lines(escaped.split(/\n/))
    end
  end

  # Legacy public API. Conversion itself uses the structure-preserving table
  # renderer below, but callers of these helpers retain the previous output.
  def make_matrix(contents)
    matrix = []
    contents.each do |line|
      row = line.split('||')
      row.shift
      matrix << row
    end

    matrix.each_with_index do |line, row_index|
      line.each_with_index do |cell, column_index|
        next unless cell =~ /\^+/

        matrix[row_index][column_index] = Regexp.last_match.post_match
        Regexp.last_match.size.times do |offset|
          matrix[row_index + offset + 1] ||= []
          matrix[row_index + offset + 1].insert(column_index, ' ')
        end
      end
    end

    max_columns = 0
    matrix.each_with_index do |line, row_index|
      column_count = line.size
      target_column = 0
      line.each do |cell|
        if cell =~ />+/
          matrix[row_index][target_column] = Regexp.last_match.post_match
          Regexp.last_match.size.times do
            target_column += 1
            matrix[row_index][target_column] = ''
          end
          column_count += Regexp.last_match.size
        else
          matrix[row_index][target_column] = cell
          target_column += 1
        end
      end
      max_columns = column_count if column_count > max_columns
    end

    [matrix, max_columns]
  end

  def make_table(table_contents)
    contents, max_columns = make_matrix(table_contents)
    alignment = '|'
    max_columns.times { alignment << ':----|' }
    alignment << "\n"
    table = "\n"

    contents.each_with_index do |line, index|
      row = '|'
      line.each { |cell| row << "#{cell}|" }
      table << row << "\n"
      table << alignment if index.zero?
    end

    table
  end

  private

  def convert_lines(lines, blockquote_recursion: 0)
    output = []
    index = 0

    while index < lines.length
      line = lines[index]

      case line
      when %r{\A//}
        index += 1
      when /\A<<<\s*(\w+)?/
        block, index = convert_block_pre(lines, index, Regexp.last_match(1))
        output << block
      when /\A[ \t]/
        block, index = convert_indented_pre(lines, index)
        output << block
      when /\A""[ \t]?/
        block, index = convert_blockquote(lines, index, blockquote_recursion)
        output << block
      when /\A[*#]+/
        block, index = convert_list(lines, index)
        output << block
      when /\A\|\|/
        table_lines, index = collect_block(lines, index, /\A\|\|/)
        output << render_table(table_lines)
      when /\A:/
        block, index = convert_definition_list(lines, index)
        output << block
      when /\A----\z/
        output << "\n---\n"
        index += 1
      else
        if plugin_only_line?(line) && !@preserve_plugins
          index += 1
          next
        end

        output << convert_regular_line(line)
        index += 1
      end
    end

    join_output(output)
  end

  def convert_regular_line(line)
    if /\A(!{1,5})(.*)\z/ =~ line
      level = Regexp.last_match(1).length + 1
      title = strip_hiki_whitespace(Regexp.last_match(2))
      converted_title = escape_markdown_heading_closer(convert_inline(title))
      return "#{'#' * level} #{converted_title}"
    end

    converted = convert_inline(line.sub(/[ \t]+\z/, ''))
    escape_markdown_block_start(converted)
  end

  def join_output(chunks)
    chunks.each_with_index.each_with_object(@source_template.dup) do |(chunk, index), joined|
      if index > 0
        previous = chunks[index - 1]
        separator = if chunk.empty? || previous.empty?
                      "\n"
                    elsif html_block?(chunk) || html_block?(previous) ||
                          block_requires_blank_after?(previous)
                      "\n\n"
                    else
                      "\n"
                    end
        joined << separator
      end
      joined << chunk
    end
  end

  def html_block?(chunk)
    chunk.start_with?('<dl>', '<table>', '<ul>', '<ol>')
  end

  def block_requires_blank_after?(chunk)
    chunk.start_with?('>', '- ', '1. ')
  end

  def convert_list(lines, index)
    entries = []

    while index < lines.length
      line = lines[index]

      if %r{\A//} =~ line
        index += 1
        next
      end

      match = /\A([*#]+)[ \t]?(.*)\z/.match(line)
      break unless match

      markers = match[1]
      entries << {
        level: markers.length,
        type: markers.start_with?('*') ? :unordered : :ordered,
        content: strip_hiki_whitespace(match[2])
      }
      index += 1
    end

    deepest_level = entries.map { |entry| entry[:level] }.max || 0
    converted = if deepest_level > MAX_MARKDOWN_LIST_DEPTH
                  render_html_list(entries)
                else
                  render_markdown_list(entries)
                end
    [converted, index]
  end

  def render_markdown_list(entries)
    converted = []
    types = []

    entries.each do |entry|
      level = entry[:level]
      type = entry[:type]
      previous_depth = types.length

      if level > types.length
        types << type while types.length < level
      elsif level < types.length
        types = types.first(level)
      else
        types[level - 1] = type
      end

      ((previous_depth + 1)...level).each do |missing_level|
        converted << render_list_item(types, missing_level, '<!-- -->')
      end

      item = escape_markdown_block_start(convert_inline(entry[:content]))
      converted << render_list_item(types, level, item)
    end

    converted.join("\n")
  end

  def render_list_item(types, level, item)
    indent = types.first(level - 1).inject(0) do |width, ancestor_type|
      width + (ancestor_type == :ordered ? 3 : 2)
    end
    marker = types[level - 1] == :ordered ? '1.' : '-'
    "#{' ' * indent}#{marker} #{item}"
  end

  def render_html_list(entries)
    rendered = @source_template.dup
    types = []
    level = 0

    entries.each do |entry|
      new_level = entry[:level]
      type = entry[:type]
      item = convert_inline(entry[:content], context: :html)

      if new_level > level
        (new_level - level).times do
          types << type
          rendered << "<#{html_list_tag(type)}>\n<li>"
        end
        rendered << item
      elsif new_level < level
        (level - new_level).times do
          rendered << "</li>\n</#{html_list_tag(types.pop)}>"
        end
        rendered << "</li>\n<li>#{item}"
      elsif type == types.last
        rendered << "</li>\n<li>#{item}"
      else
        rendered << "</li>\n</#{html_list_tag(types.pop)}>\n"
        rendered << "<#{html_list_tag(type)}>\n<li>#{item}"
        types << type
      end

      level = new_level
    end

    level.times do
      rendered << "</li>\n</#{html_list_tag(types.pop)}>"
    end
    rendered
  end

  def html_list_tag(type)
    type == :unordered ? 'ul' : 'ol'
  end

  def convert_blockquote(lines, index, recursion_depth)
    quoted_lines = []

    while index < lines.length
      line = lines[index]

      if %r{\A//} =~ line
        index += 1
      elsif /\A""[ \t]?/ =~ line
        quoted_lines << line
        index += 1
      else
        break
      end
    end

    depths = quoted_lines.map { |line| blockquote_depth(line) }
    if depths.uniq.length > MAX_BLOCKQUOTE_RECURSION
      raise ArgumentError, 'blockquote nesting structure is too deep'
    end

    common_depth = depths.min
    inner_lines = quoted_lines.map do |line|
      strip_blockquote_prefix(line, common_depth)
    end
    if recursion_depth >= MAX_BLOCKQUOTE_RECURSION &&
       inner_lines.any? { |line| /\A""[ \t]?/ =~ line }
      raise ArgumentError, 'blockquote nesting structure is too deep'
    end

    inner = convert_lines(
      inner_lines,
      blockquote_recursion: recursion_depth + 1
    )
    prefix = '> ' * common_depth
    quoted = inner.split("\n", -1).map do |quoted_line|
      quoted_line.empty? ? prefix.rstrip : "#{prefix}#{quoted_line}"
    end.join("\n")
    [quoted, index]
  end

  def blockquote_depth(line)
    depth = 0
    offset = 0
    while line[offset, 2] == '""'
      offset += 2
      offset += 1 if line[offset, 1] == ' ' || line[offset, 1] == "\t"
      depth += 1
    end
    depth
  end

  def strip_blockquote_prefix(line, depth)
    offset = 0
    depth.times do
      offset += 2
      offset += 1 if line[offset, 1] == ' ' || line[offset, 1] == "\t"
    end
    line[offset..-1].to_s
  end

  def convert_block_pre(lines, index, info)
    index += 1
    contents = []

    while index < lines.length && lines[index] !~ /\A>>>/
      contents << restore_plugins(lines[index])
      index += 1
    end
    index += 1 if index < lines.length

    [fenced_code(contents, info), index]
  end

  def convert_indented_pre(lines, index)
    contents = []

    while index < lines.length && /\A[ \t]/ =~ lines[index]
      content = lines[index].sub(/\A[ \t]/, '').sub(/[ \t]+\z/, '')
      contents << restore_plugins(content)
      index += 1
    end

    [fenced_code(contents), index]
  end

  def fenced_code(lines, info = nil)
    longest_run = lines.join("\n").scan(/`+/).map(&:length).max || 0
    fence = '`' * [3, longest_run + 1].max
    opening = info.to_s.empty? ? fence : "#{fence}#{info}"
    ([opening] + lines + [fence]).join("\n")
  end

  def convert_definition_list(lines, index)
    items = []

    while index < lines.length
      line = lines[index]

      if %r{\A//} =~ line
        index += 1
        next
      end
      break unless /\A:/ =~ line

      term, description = split_definition(line[1..-1])
      term = convert_inline(term, context: :html)
      description = convert_inline(description, context: :html)

      if description.empty?
        items << "<dt>#{term}</dt>"
      elsif term.empty?
        items << "<dd>#{description}</dd>"
      else
        items << "<dt>#{term}</dt><dd>#{description}</dd>"
      end
      index += 1
    end

    [(["<dl>"] + items + ["</dl>"]).join("\n"), index]
  end

  def split_definition(line)
    bracket_depth = 0
    index = 0

    while index < line.length
      if line[index, 2] == '[['
        bracket_depth += 1
        index += 2
      elsif line[index, 2] == ']]' && bracket_depth > 0
        bracket_depth -= 1
        index += 2
      elsif line[index] == ':' && bracket_depth.zero?
        return [line[0...index], line[(index + 1)..-1].to_s]
      else
        index += 1
      end
    end

    [line, '']
  end

  def collect_block(lines, index, pattern)
    collected = []

    while index < lines.length
      if %r{\A//} =~ lines[index]
        index += 1
      elsif pattern =~ lines[index]
        collected << lines[index]
        index += 1
      else
        break
      end
    end

    [collected, index]
  end

  def render_table(table_lines)
    rows = parse_table_rows(table_lines)
    render_html_table(rows)
  end

  def parse_table_rows(table_lines)
    table_lines.map do |line|
      body = line.sub(/\A\|\|/, '')
      columns = body.split('||', -1)
      columns.pop if columns.last == ''

      columns.map do |column|
        header = column.start_with?('!')
        column = column[1..-1].to_s if header
        span = column[/\A[\^>]*/].to_s
        column = column[span.length..-1].to_s
        rowspan_count = span.count('^')
        colspan_count = span.count('>')

        {
          content: column,
          header: header,
          rowspan: rowspan_count.zero? ? nil : rowspan_count + 1,
          colspan: colspan_count.zero? ? nil : colspan_count + 1
        }
      end
    end
  end

  def render_html_table(rows)
    rendered_rows = rows.map do |row|
      cells = row.map do |cell|
        tag = cell[:header] ? 'th' : 'td'
        attributes = []
        attributes << %(rowspan="#{cell[:rowspan]}") if cell[:rowspan]
        attributes << %(colspan="#{cell[:colspan]}") if cell[:colspan]
        attribute_text = attributes.empty? ? '' : " #{attributes.join(' ')}"
        content = convert_inline(cell[:content], context: :html)
        "<#{tag}#{attribute_text}>#{content}</#{tag}>"
      end.join
      "<tr>#{cells}</tr>"
    end

    (["<table>"] + rendered_rows + ["</table>"]).join("\n")
  end

  def convert_inline(text, context: :markdown)
    remaining = text.to_s
    result = remaining[0, 0]

    while (match = INLINE_RE.match(remaining))
      result << escape_text(match.pre_match, context)
      token = match[0]

      result << if plugin_token?(token)
                  convert_plugin_token(token, context)
                elsif token.start_with?('[[')
                  convert_bracket_link(token[2...-2], context)
                elsif /\A#{URI_RE}\z/ =~ token
                  convert_uri(token, context)
                elsif /\A#{MODIFIER_RE}\z/ =~ token
                  convert_modifier(token, context)
                else
                  convert_wiki_name(token, context)
                end
      remaining = match.post_match
    end

    result << escape_text(remaining, context)
    result
  end

  def convert_modifier(token, context)
    marker_length = token.start_with?("'''") ? 3 : 2
    marker = token[0, marker_length]
    content = token[marker_length...-marker_length]

    if marker == '``'
      literal = restore_or_remove_plugins(content)
      return literal if literal.empty?

      if INLINE_RE =~ content
        converted = convert_inline(content, context: :html)
        return converted if converted.empty?
        return "<code>#{converted}</code>"
      end

      return context == :html ? "<code>#{html_escape(literal)}</code>" : code_span(literal)
    end

    converted = convert_inline(content, context: context)
    return converted if converted.empty?

    tag = { "'''" => 'strong', "''" => 'em', '==' => 'del' }.fetch(marker)
    if context == :html
      "<#{tag}>#{converted}</#{tag}>"
    elsif converted =~ /\A\s|\s\z/
      html_content = convert_inline(content, context: :html)
      return html_content if html_content.empty?
      "<#{tag}>#{html_content}</#{tag}>"
    else
      markdown_marker = { "'''" => '**', "''" => '*', '==' => '~~' }.fetch(marker)
      "#{markdown_marker}#{converted}#{markdown_marker}"
    end
  end

  def code_span(content)
    longest_run = content.scan(/`+/).map(&:length).max || 0
    delimiter = '`' * [1, longest_run + 1].max
    padded_edge = content.start_with?('`', ' ') || content.end_with?('`', ' ')
    padding = padded_edge && content !~ /\A\s*\z/ ? ' ' : ''
    "#{delimiter}#{padding}#{content}#{padding}#{delimiter}"
  end

  def convert_bracket_link(content, context)
    separator = content.rindex('|')
    if separator
      label = content[0...separator]
      target = content[(separator + 1)..-1]
      labeled = true
    else
      label = content
      target = content
      labeled = false
    end

    target = restore_or_remove_plugins(target)

    if image?(target)
      destination = resolve_target(target, image: true)
      alt = labeled ? plain_label(label) : image_alt(target)
      return image_markup(alt, destination, context)
    end

    destination = resolve_target(target)
    rendered_label = convert_label(label, context)
    link_markup(rendered_label, destination, context)
  end

  def convert_uri(uri, context)
    destination = normalize_hiki_uri(uri)
    if image?(uri)
      image_markup(image_alt(destination), destination, context)
    elsif context == :html
      label = html_escape(uri)
      link_markup(label, destination, context)
    elsif external_uri?(destination)
      "<#{escape_destination(destination)}>"
    else
      label = escape_text(uri, context)
      link_markup(label, destination, context)
    end
  end

  def convert_label(label, context)
    remaining = label.to_s
    result = remaining[0, 0]
    label_re = Regexp.union(/\0\d+\0/, MODIFIER_RE)

    while (match = label_re.match(remaining))
      result << escape_text(match.pre_match, context)
      token = match[0]
      result << if plugin_token?(token)
                  convert_plugin_token(token, context)
                else
                  convert_modifier(token, context)
                end
      remaining = match.post_match
    end

    result << escape_text(remaining, context)
    result
  end

  def plain_label(label)
    restored = restore_or_remove_plugins(label)
    restored.gsub(/[\r\n]+/, ' ')
  end

  def convert_wiki_name(token, context)
    if token.start_with?('^')
      return escape_text(token[1..-1], context) if @use_wiki_name
      return escape_text(token, context)
    end
    return escape_text(token, context) unless @use_wiki_name

    destination = resolve_target(token)
    label = escape_text(token, context)
    link_markup(label, destination, context)
  end

  def link_markup(label, destination, context)
    destination = sanitize_destination(destination)
    if context == :html
      %(<a href="#{html_escape_attribute(destination)}">#{label}</a>)
    else
      "[#{label}](#{escape_destination(destination)})"
    end
  end

  def image_markup(alt, destination, context)
    destination = sanitize_destination(destination)
    if context == :html
      %(<img src="#{html_escape_attribute(destination)}" alt="#{html_escape_attribute(alt)}">)
    else
      "![#{escape_image_alt(alt)}](#{escape_destination(destination)})"
    end
  end

  def resolve_target(target, image: false)
    hiki_relative_uri = /\A(?:https?|ftp|file):(?!\/\/)/ =~ target
    normalized = normalize_hiki_uri(target)
    return normalized if normalized.empty?
    return normalized if hiki_relative_uri
    return normalized if external_uri?(normalized)
    return normalized if normalized.start_with?('/', './', '../', '#', '?')

    if /\A([^:]+):(.+)\z/ =~ normalized
      interwiki_name = Regexp.last_match(1)
      page_name = Regexp.last_match(2)
      template = interwiki_template(interwiki_name)
      if template
        encoded_page = CGI.escape(page_name).gsub('+', '%20')
        template = template.to_s
        return template.include?('$1') ? template.gsub('$1', encoded_page) : template + encoded_page
      end

      return normalized if safe_uri_scheme?(interwiki_name)
      suffix = image ? '' : '.md'
      return "./#{percent_encode(normalized)}#{suffix}"
    end

    return percent_encode(normalized) if image

    page_and_query, fragment = normalized.split('#', 2)
    page_name, query = page_and_query.split('?', 2)
    extension = page_name.end_with?('.md') ? '' : '.md'
    destination = "#{percent_encode(page_name)}#{extension}"
    destination << "?#{percent_encode(query)}" if query
    destination << "##{percent_encode(fragment)}" if fragment
    destination
  end

  def normalize_hiki_uri(uri)
    if /\A(?:https?|ftp|file):(?!\/\/)/ =~ uri
      uri.sub(/\A\w+:/, '')
    else
      uri
    end
  end

  def external_uri?(target)
    /\A(?:https?|ftp|file|mailto):/ =~ target
  end

  def image?(target)
    path = target.to_s.split(/[?#]/, 2).first.to_s
    extension = path[/\.[^.\/]+\z/].to_s.downcase
    IMAGE_EXTENSIONS.include?(extension)
  end

  def image_alt(target)
    path = normalize_hiki_uri(target.to_s).split(/[?#]/, 2).first
    path.split('/').last.to_s
  end

  def interwiki_template(name)
    return @interwiki_map[name] if @interwiki_map.key?(name)

    symbol = name.to_sym
    @interwiki_map[symbol] if @interwiki_map.key?(symbol)
  end

  def safe_uri_scheme?(scheme)
    uri_scheme?(scheme) && !UNSAFE_URI_SCHEMES.include?(scheme.downcase)
  end

  def uri_scheme?(scheme)
    /\A[A-Za-z][A-Za-z0-9+.-]*\z/ =~ scheme
  end

  def sanitize_destination(destination)
    value = destination.to_s
    candidate = CGI.unescapeHTML(value).
      gsub(/&colon;/i, ':').
      gsub(/&(?:Tab|NewLine);/i, '').
      gsub(/[\x00-\x20]/, '')
    encoded = value.gsub(/[\x00-\x20]/) do |character|
      format('%%%02X', character.ord)
    end
    if /\A([A-Za-z][A-Za-z0-9+.-]*):/ =~ candidate &&
       UNSAFE_URI_SCHEMES.include?(Regexp.last_match(1).downcase)
      "./#{encoded}"
    else
      encoded
    end
  end

  def percent_encode(value)
    value.to_s.gsub("\n", '%0A').gsub("\r", '%0D').gsub("\t", '%09').
      gsub(' ', '%20').gsub('(', '%28').gsub(')', '%29').
      gsub('<', '%3C').gsub('>', '%3E').gsub('"', '%22').
      gsub('{', '%7B').gsub('}', '%7D')
  end

  def escape_destination(destination)
    percent_encode(destination).gsub(']', '%5D')
  end

  def escape_image_alt(alt)
    escape_text(alt.to_s, :markdown)
  end

  def escape_text(text, context)
    return html_escape(text) if context == :html

    specials = "\\`*_[]~|"
    value = text.to_s
    value.each_char.each_with_object(value[0, 0]) do |character, escaped|
      case character
      when '&'
        escaped << '&amp;'
      when '<'
        escaped << '&lt;'
      when '>'
        escaped << '&gt;'
      else
        escaped << (specials.include?(character) ? "\\#{character}" : character)
      end
    end
  end

  def escape_markdown_block_start(converted)
    case converted
    when /\A( {0,3})([-+])(?:\s|\z)/
      converted.sub(/\A( {0,3})([-+])/) do
        "#{Regexp.last_match(1)}\\#{Regexp.last_match(2)}"
      end
    when /\A( {0,3})[#]{1,6}(?:\s|\z)/
      converted.sub(/\A( {0,3})#/) { "#{Regexp.last_match(1)}\\#" }
    when /\A( {0,3})>(?:\s|\z)/
      converted.sub(/\A( {0,3})>/) { "#{Regexp.last_match(1)}\\>" }
    when /\A( {0,3})\d+[.)](?:\s|\z)/
      converted.sub(/\A( {0,3})(\d+)([.)])/) do
        "#{Regexp.last_match(1)}#{Regexp.last_match(2)}\\#{Regexp.last_match(3)}"
      end
    when /\A( {0,3})(?:-+|=+)[ \t]*\z/
      converted.sub(/\A( {0,3})/) { "#{Regexp.last_match(1)}\\" }
    when /\A {4}/
      converted.sub(/\A /, '&#32;')
    when /\A\t/
      converted.sub(/\A\t/, '&#9;')
    else
      converted
    end
  end

  def escape_markdown_heading_closer(title)
    return title unless /(?:\A|[ \t])[#]+\z/ =~ title

    title.sub(/[#]+\z/) { |hashes| "\\#{hashes}" }
  end

  def html_escape(text)
    text.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
  end

  def html_escape_attribute(text)
    html_escape(text).gsub('"', '&quot;').gsub("'", '&#39;')
  end

  def strip_hiki_whitespace(text)
    text.to_s.sub(/\A[ \t\r\n\v\f]+/, '').sub(/[ \t\r\n\v\f]+\z/, '')
  end

  def extract_plugins(source)
    @plugins = []
    result = source[0, 0]
    offset = 0

    while (opening = source.index('{{', offset))
      result << source[offset...opening]
      closing = find_plugin_end(source, opening + 2)
      unless closing
        result << source[opening..-1]
        offset = source.length
        break
      end

      @plugins << source[(opening + 2)...closing]
      result << "\0#{@plugins.length - 1}\0"
      offset = closing + 2
    end

    result << source[offset..-1].to_s if offset < source.length
    result
  end

  def find_plugin_end(source, offset)
    quote = nil
    escaped = false
    index = offset

    while index < source.length - 1
      character = source[index]

      if quote
        if escaped
          escaped = false
        elsif character == '\\'
          escaped = true
        elsif character == quote
          quote = nil
        end
      elsif character == "'" || character == '"'
        quote = character
      elsif source[index, 2] == '}}'
        return index
      end

      index += 1
    end

    nil
  end

  def convert_plugin_token(token, context)
    return '' unless @preserve_plugins

    plugin = token.sub(PLUGIN_TOKEN_RE) { "{{#{@plugins[Regexp.last_match(1).to_i]}}}" }
    escape_text(plugin, context).gsub("\n", '&#10;').gsub("\r", '&#13;')
  end

  def plugin_token?(token)
    /\A\0\d+\0\z/ =~ token
  end

  def restore_plugins(text)
    text.to_s.gsub(PLUGIN_TOKEN_RE) do
      "{{#{@plugins[Regexp.last_match(1).to_i]}}}"
    end
  end

  def restore_or_remove_plugins(text)
    if @preserve_plugins
      restore_plugins(text)
    else
      text.to_s.gsub(PLUGIN_TOKEN_RE, '')
    end
  end

  def plugin_only_line?(line)
    /\A[ \t]*(?:\0\d+\0[ \t]*)+\z/ =~ line
  end
end
