require 'spec_helper'

describe Hiki2md do
  it 'plugin' do
    assert("{{hoge}}", "")
  end

  it 'comment' do
    assert("//", "")
  end

  it 'headline' do
    assert("! Headline1"    , "## Headline1")
    assert("!Headline1"     , "## Headline1")
    assert("!! Headline2"   , "### Headline2")
    assert("!!Headline2"    , "### Headline2")
    assert("!!! Headline3"  , "#### Headline3")
    assert("!!!Headline3"   , "#### Headline3")
    assert("!!!! Headline4" , "##### Headline4")
    assert("!!!!Headline4"  , "##### Headline4")
    assert("!!!!! Headline5", "###### Headline5")
    assert("!!!!!Headline5" , "###### Headline5")
    assert("! title #", "## title \\#")
    assert("! #", "## \\#")
  end

  it 'strong' do
    assert(
      %Q|this is ''strong'' text. this is '''very storng''' text.|,
      %Q|this is *strong* text. this is **very storng** text.|)
  end

  it 'list' do
    hiki =<<-EOS
* list1
** list2
* list1
** list2
*** list3
** list2
EOS

    md =<<-EOS
- list1
  - list2
- list1
  - list2
    - list3
  - list2
EOS

    assert(hiki, md.chomp)
  end

  it 'listnum' do
    hiki =<<-EOS
# list1
## list2
# list1
## list2
### list3
## list2
EOS

    md =<<-EOS
1. list1
   1. list2
1. list1
   1. list2
      1. list3
   1. list2
EOS

    assert(hiki, md.chomp)
  end

  it "delete" do
    assert("==deleted==", "~~deleted~~")
  end

  it "link" do
    assert("[[google|http://google.com]]", "[google](http://google.com)")
  end

  it "image" do
    assert("[[http://example.com/abc.gif]]", "![abc.gif](http://example.com/abc.gif)")
  end

  it "pretext" do
    hiki =<<-EOS
<<<
pre
text

pre
text
>>>
EOS

    md =<<-EOS
```
pre
text

pre
text
```
EOS

    assert(hiki, md.chomp)
  end

  it "code" do
    hiki = " pre\n text\n \n text\n"

    md =<<-EOS
```
pre
text

text
```
EOS

    assert(hiki, md.chomp)
  end

  it "quote" do
    hiki =<<-EOS
"" quote
"" quote
"" quote
EOS

    md =<<-EOS
> quote
> quote
> quote
EOS

    assert(hiki, md.chomp)
  end

  it "pre_formatted_with_code_name" do
    hiki =<<-EOS
<<<ruby
  p "hello world."
>>>
EOS
    md =<<-EOS
```ruby
  p "hello world."
```
EOS
    assert(hiki, md.chomp)
  end

  it "table" do
    hiki =<<-EOS
||test1||test2||test3
||^test4||>test5
||test6||test7
EOS
    md =<<-EOS
<table>
<tr><td>test1</td><td>test2</td><td>test3</td></tr>
<tr><td rowspan="2">test4</td><td colspan="2">test5</td></tr>
<tr><td>test6</td><td>test7</td></tr>
</table>
EOS
    assert(hiki, md.chomp)
  end

  it "description_list" do
    hiki =<<EOS
:list1-1:list1-2
:list2-1:list2-2
EOS

    md =<<EOS
<dl>
<dt>list1-1</dt><dd>list1-2</dd>
<dt>list2-1</dt><dd>list2-2</dd>
</dl>
EOS
    assert(hiki, md.chomp)
  end


  it "should correctly convert modified_table" do
    hiki =<<-EOS
||''test1''||==test2==||test3
||[[http://example.com/abc.gif]]||[[http://example.com/abcd.gif]]||
EOS
    md =<<-EOS
<table>
<tr><td><em>test1</em></td><td><del>test2</del></td><td>test3</td></tr>
<tr><td><img src="http://example.com/abc.gif" alt="abc.gif"></td><td><img src="http://example.com/abcd.gif" alt="abcd.gif"></td></tr>
</table>
EOS
    assert(hiki, md.chomp)
  end

  it "should correctly convert modified_headers" do
    hiki =<<-EOS
!''test1''
!==test1==
![[test1]]
EOS
    md =<<-EOS
## *test1*
## ~~test1~~
## [test1](test1.md)
EOS
    assert(hiki, md.chomp)
  end

  it "hr" do
    assert("----", "\n---\n")
  end

  it "wikiname link" do
    assert("[[PageName]]", "[PageName](PageName.md)")
  end

  it "interwiki link" do
    assert('[[Google:ruby wiki]]', '[Google:ruby wiki](https://www.google.com/search?q=ruby%20wiki)')
    assert('[[ruby-talk:12345]]', '[ruby-talk:12345](http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-talk/12345)')
  end

  it "autolink url" do
    assert("text https://example.com text", "text <https://example.com> text")
    assert("text http://example.com text", "text <http://example.com> text")
  end

  it "autolink wikiname" do
    assert("this is a WikiName.", "this is a [WikiName](WikiName.md).")
    assert("HogeRule1 is a WikiName.", "[HogeRule1](HogeRule1.md) is a [WikiName](WikiName.md).")
    assert("NOTWIKINAME", "NOTWIKINAME")
    assert("http://WikiName", "<http://WikiName>") # 既にリンクになっている場合は変換しない
  end

  it "distinguishes links from images" do
    assert(
      "[[https://example.com/]]",
      "[https://example.com/](https://example.com/)"
    )
    assert(
      "[[Logo|https://example.com/logo.png]]",
      "![Logo](https://example.com/logo.png)"
    )
    assert(
      "https://example.com/logo.png",
      "![logo.png](https://example.com/logo.png)"
    )
  end

  it "resolves labeled wiki and interwiki links" do
    assert("[[Guide|PageName]]", "[Guide](PageName.md)")
    assert("[[Page Name]]", "[Page Name](Page%20Name.md)")
    assert("[[a|a|PageName]]", "[a\\|a](PageName.md)")
    assert(
      "[[search|Google:ruby wiki]]",
      "[search](https://www.google.com/search?q=ruby%20wiki)"
    )
    assert("[[Hiki|http:hikiwiki.html]]", "[Hiki](hikiwiki.html)")
    assert(
      "[[Guide|Page Name?view=full#Examples]]",
      "[Guide](Page%20Name.md?view=full#Examples)"
    )
    assert(
      "[[Google:日本&x=y]]",
      "[Google:日本&amp;x=y](https://www.google.com/search?q=%E6%97%A5%E6%9C%AC%26x%3Dy)"
    )
  end

  it "supports an InterWiki placeholder" do
    converter = Hiki2md.new(
      interwiki_map: { "Issues" => "https://example.com/issues/$1/comments" }
    )
    expect(converter.convert("[[Issues:hello world]]")).to eq(
      "[Issues:hello world](https://example.com/issues/hello%20world/comments)"
    )
  end

  it "autolinks supported URI schemes" do
    assert("ftp://example.com/file", "<ftp://example.com/file>")
    assert("mailto:user@example.com", "<mailto:user@example.com>")
    assert(
      "https://example.com/?q=WikiName",
      "<https://example.com/?q=WikiName>"
    )
    assert("http:hikiwiki.html", "[http:hikiwiki.html](hikiwiki.html)")
  end

  it "converts repeated and nested modifiers" do
    assert(
      "''one'' and ''two''",
      "*one* and *two*"
    )
    assert(
      "'''one''' and '''two'''",
      "**one** and **two**"
    )
    assert(
      "==one== and ==two==",
      "~~one~~ and ~~two~~"
    )
    assert("''==nested==''", "*~~nested~~*")
    assert("==''nested''==", "~~*nested*~~")
    assert("``code``", "`code`")
  end

  it "converts modifiers around and inside links" do
    assert(
      "'''[[Hiki|https://hikiwiki.org/]]'''",
      "**[Hiki](https://hikiwiki.org/)**"
    )
    assert(
      "[['''Hiki'''|https://hikiwiki.org/]]",
      "[**Hiki**](https://hikiwiki.org/)"
    )
  end

  it "matches and suppresses WikiNames like HikiDoc" do
    assert("fooWikiName", "fooWikiName")
    assert("RSSPage", "RSSPage")
    assert("RSSPageName", "[RSSPageName](RSSPageName.md)")
    assert("^WikiName", "WikiName")

    converted = Hiki2md.new(use_wiki_name: false).convert("WikiName ^WikiName")
    expect(converted).to eq("WikiName ^WikiName")
  end

  it "supports incomplete definition-list entries" do
    hiki = ":term:\n::description"
    md = <<-EOS.chomp
<dl>
<dt>term</dt>
<dd>description</dd>
</dl>
EOS
    assert(hiki, md)
  end

  it "splits definitions at the first colon outside a link" do
    assert(
      ":site:https://example.com",
      <<-EOS.chomp
<dl>
<dt>site</dt><dd><a href="https://example.com">https://example.com</a></dd>
</dl>
EOS
    )
    assert(
      ":'''term''':==description:more==",
      <<-EOS.chomp
<dl>
<dt><strong>term</strong></dt><dd><del>description:more</del></dd>
</dl>
EOS
    )
  end

  it "preserves table headers and spans with HTML" do
    hiki = <<-EOS
||!Name||!Value
||A||1
||!Total||>2
EOS
    md = <<-EOS.chomp
<table>
<tr><th>Name</th><th>Value</th></tr>
<tr><td>A</td><td>1</td></tr>
<tr><th>Total</th><td colspan="2">2</td></tr>
</table>
EOS
    assert(hiki, md)
  end

  it "only recognizes table spans at the start of a cell" do
    hiki = "||a^b||c>d"
    md = <<-EOS.chomp
<table>
<tr><td>a^b</td><td>c&gt;d</td></tr>
</table>
EOS
    assert(hiki, md)
  end

  it "keeps empty, uneven, and pipe-containing table cells" do
    hiki = <<-EOS
||a|b||c||d
||||||||
||e||f
EOS
    md = <<-'EOS'.chomp
<table>
<tr><td>a|b</td><td>c</td><td>d</td></tr>
<tr><td></td><td></td><td></td></tr>
<tr><td>e</td><td>f</td></tr>
</table>
EOS
    assert(hiki, md.chomp)
  end

  it "preserves preformatted text literally" do
    assert(
      " one\n   nested",
      "```\none\n  nested\n```"
    )
    assert(
      "<<<\n{{literal}}\n[[PageName]]\nWikiName\n''text''\n// comment\n>>>",
      "```\n{{literal}}\n[[PageName]]\nWikiName\n''text''\n// comment\n```"
    )
  end

  it "closes unterminated and conflicting fenced code blocks" do
    assert("<<<ruby\nputs 1", "```ruby\nputs 1\n```")
    assert("<<<\n```\n>>>", "````\n```\n````")
  end

  it "handles multiline, inline, and preserved plugins" do
    assert("{{foo\n 1}}\nafter", "after")
    assert(%q!before {{foo("}}")}} after!, "before  after")
    assert("{{unterminated", "{{unterminated")

    converted = Hiki2md.new(preserve_plugins: true).convert("{{recent(3)}}")
    expect(converted).to eq("{{recent(3)}}")
  end

  it "handles plugins inside structural and link syntax" do
    assert(
      "* before {{foo}}\n! {{foo}}\n[[a {{foo}} b|PageName]]",
      "- before \n\n## \n[a  b](PageName.md)"
    )

    converter = Hiki2md.new(preserve_plugins: true)
    expect(converter.convert("* {{foo}}\n! {{foo}}")).to eq(
      "- {{foo}}\n\n## {{foo}}"
    )

    assert("[[alt {{secret}}|image.png]]", "![alt ](image.png)")
    expect(converter.convert("[[alt {{secret}}|image.png]]")).to eq(
      "![alt {{secret}}](image.png)"
    )
  end

  it "recursively converts blockquotes" do
    hiki = <<-EOS
""!Heading
""* item
""""nested
""
""after
EOS
    md = <<-'EOS'.chomp
> ## Heading
> - item
>
> > nested
>
> after
EOS
    assert(hiki, md)
  end

  it "normalizes CRLF input" do
    assert("! Heading\r\n----\r\n", "## Heading\n\n---\n")
  end

  it "protects non-Hiki Markdown and HTML syntax" do
    hiki = <<-EOS
<b>x</b>
_literal_
1. plain
- plain
---
> plain
[literal]
EOS
    md = <<-'EOS'.chomp
&lt;b&gt;x&lt;/b&gt;
\_literal\_
1\. plain
\- plain
\---
&gt; plain
\[literal\]
EOS
    assert(hiki, md)
    assert("-", "\\-")
    assert("+", "\\+")
    assert("1.", "1\\.")
    assert("1)", "1\\)")
    assert("title\n==", "title\n\\==")
    assert("title\n--", "title\n\\--")
  end

  it "caps Hiki headings at Markdown h6" do
    assert("!!!!!! Heading", "###### ! Heading")
  end

  it "keeps adjacent block ordering" do
    hiki = <<-EOS
||A||B
:term:definition
 code
after
EOS
    converted = Hiki2md.new.convert(hiki)
    expect(converted.index("<table>")).to be < converted.index("<dl>")
    expect(converted.index("<dl>")).to be < converted.index("```")
    expect(converted.index("```")).to be < converted.index("after")
  end

  it "preserves skipped and mixed list levels" do
    assert(
      "* parent\n*** child\n* sibling",
      "- parent\n  - <!-- -->\n    - child\n- sibling"
    )
    assert("** orphan", "- <!-- -->\n  - orphan")
    assert("* parent\n## child", "- parent\n  1. child")
    assert("# parent\n** child", "1. parent\n   - child")
    assert(
      "*** deep\n## shallower",
      "- <!-- -->\n  - <!-- -->\n    - deep\n  - shallower"
    )
    assert("* unordered\n# ordered", "- unordered\n1. ordered")
  end

  it "separates lists and blockquotes from following paragraphs" do
    assert("* item\nafter", "- item\n\nafter")
    assert(%Q|"" quote\nafter|, "> quote\n\nafter")
  end

  it "does not leave dangerous empty Markdown modifiers" do
    assert("'''{{plugin}}'''", "")
    assert("''{{plugin}}''", "")
    assert("=={{plugin}}==", "")
    assert("``{{plugin}}``", "")
  end

  it "recursively converts inline syntax inside code modifiers" do
    assert(
      "``[[Hiki|https://hikiwiki.org/]]``",
      %q|<code><a href="https://hikiwiki.org/">Hiki</a></code>|
    )
    assert("``WikiName``", %q|<code><a href="WikiName.md">WikiName</a></code>|)
    assert("``''text''``", "<code><em>text</em></code>")
    assert("`` ``", "` `")
  end

  it "uses HTML when modifier whitespace is not valid Markdown" do
    assert("'' text ''", "<em> text </em>")
    assert("''' text '''", "<strong> text </strong>")
    assert("== text ==", "<del> text </del>")
  end

  it "removes and preserves plugins safely inside link targets" do
    assert("[[label|Page{{plugin}}Name]]", "[label](PageName.md)")
    assert("[[label|{{plugin}}]]", "[label]()")

    converter = Hiki2md.new(preserve_plugins: true)
    expect(converter.convert("[[label|Page{{plugin}}Name]]")).to eq(
      "[label](Page%7B%7Bplugin%7D%7DName.md)"
    )
  end

  it "keeps literal image labels and supplies basename alt text" do
    assert("[[a==b|image.png]]", "![a==b](image.png)")
    assert(%q{[[O''Brien|image.png]]}, %q{![O''Brien](image.png)})
    assert("[[*a*|image.png]]", "![\\*a\\*](image.png)")
    assert("[[path/to/image.png]]", "![image.png](path/to/image.png)")
  end

  it "handles generic and unsafe URI schemes" do
    assert("[[scheme:keyword]]", "[scheme:keyword](scheme:keyword)")
    assert(
      "[[javascript:alert(1)]]",
      "[javascript:alert(1)](./javascript:alert%281%29.md)"
    )
    assert(
      "[[label|http:javascript:alert(1)]]",
      "[label](./javascript:alert%281%29)"
    )
    assert(
      "||[[label|http:javascript:alert(1)]]",
      <<-EOS.chomp
<table>
<tr><td><a href="./javascript:alert(1)">label</a></td></tr>
</table>
EOS
    )

    converter = Hiki2md.new(interwiki_map: { "Unsafe" => "javascript:" })
    expect(converter.convert("[[Unsafe:alert(1)]]")).to eq(
      "[Unsafe:alert(1)](./javascript:alert%281%29)"
    )
    assert(
      "[[label|jav&#x61;script:alert(1)]]",
      "[label](./jav&#x61;script:alert%281%29.md)"
    )
    assert(
      "[[label|javascript&colon;alert(1)]]",
      "[label](./javascript&colon;alert%281%29.md)"
    )
  end

  it "keeps InterWiki map mutation compatibility" do
    interwiki_map = {}
    converter = Hiki2md.new(interwiki_map: interwiki_map)
    interwiki_map["Docs"] = "https://example.com/docs/"
    expect(converter.convert("[[Docs:Page Name]]")).to eq(
      "[Docs:Page Name](https://example.com/docs/Page%20Name)"
    )
  end

  it "protects Markdown exposed by removed plugins" do
    assert("{{plugin}}- plain", "\\- plain")
    assert("{{plugin}}# heading", "\\# heading")
    assert("{{plugin}}1. plain", "1\\. plain")
    assert("{{plugin}}---", "\\---")
    assert("{{plugin}}    code", "&#32;   code")
    assert("{{plugin}} # heading", " \\# heading")
    assert("{{plugin}}## heading", "\\## heading")
    assert("{{plugin}}  - item", "  \\- item")
    assert("{{plugin}}   1. item", "   1\\. item")
    assert("{{plugin}}   ---", "   \\---")
  end


  it "keeps list item text from becoming nested Markdown blocks" do
    assert("* # heading", "- \\# heading")
    assert("* ## heading", "- \\## heading")
    assert("* - nested", "- \\- nested")
    assert("* 1. nested", "- 1\\. nested")
    assert("* ---", "- \\---")
  end

  it "prevents accidental hard breaks and GFM tables in plain text" do
    assert("first  \nsecond", "first\nsecond")
    assert("a | b\n--- | ---", "a \\| b\n--- \\| ---")
  end

  it "recognizes plugin endings after unquoted backslashes" do
    assert("{{foo\\}} after", " after")
    converted = Hiki2md.new(preserve_plugins: true).convert("{{foo\\}} after")
    expect(converted).to eq("{{foo\\\\}} after")
  end


  it "keeps multiline preserved plugins from breaking HTML blocks" do
    converted = Hiki2md.new(preserve_plugins: true).convert(
      "||{{foo\n\nbar}}||x"
    )
    expect(converted).to eq(<<-EOS.chomp)
<table>
<tr><td>{{foo&#10;&#10;bar}}</td><td>x</td></tr>
</table>
EOS
  end

  it "keeps plugin state isolated across concurrent conversions" do
    converter_class = Class.new(Hiki2md) do
      private

      def extract_plugins(source)
        extracted = super
        sleep(0.005)
        extracted
      end
    end
    converter = converter_class.new(preserve_plugins: true)
    results = []
    threads = 10.times.map do |index|
      Thread.new do
        results[index] = converter.convert("doc#{index} {{SECRET#{index}}}")
      end
    end
    threads.each(&:join)

    expect(results).to eq(
      10.times.map { |index| "doc#{index} {{SECRET#{index}}}" }
    )
  end

  it "handles natural NUL bytes without confusing plugin placeholders" do
    converted = Hiki2md.new.convert("[[label|a\0.png]]")
    expect(converted).to eq("![label](a�.png)")
    expect(converted).not_to include("\0")

    euc_jp = "日本\0語".encode(Encoding::EUC_JP)
    converted = Hiki2md.new.convert(euc_jp)
    expect(converted.encoding).to eq(Encoding::EUC_JP)
    expect(converted).to eq("日本?語".encode(Encoding::EUC_JP))
  end

  it "handles very deep blockquotes without exhausting the Ruby stack" do
    depth = 4_000
    source = ('""' * depth) + 'text'
    expect(Hiki2md.new.convert(source)).to eq(('> ' * depth) + 'text')
  end

  it "rejects pathologically varying quote depth with a normal exception" do
    source = (1..150).map { |depth| ('""' * depth) + 'text' }.join("\n")
    expect { Hiki2md.new.convert(source) }.to raise_error(
      ArgumentError,
      'blockquote nesting structure is too deep'
    )
  end

  it "falls back to linear-size HTML for extreme list depth" do
    depth = Hiki2md::MAX_MARKDOWN_LIST_DEPTH + 1
    converted = Hiki2md.new.convert(('*' * depth) + ' item')
    expect(converted).to start_with("<ul>\n<li>")
    expect(converted.scan('<ul>').length).to eq(depth)
    expect(converted.scan('<li>').length).to eq(depth)
    expect(converted.length).to be < 20_000
  end

  it "preserves the source string encoding" do
    source = "plain".encode(Encoding::UTF_8)
    expect(Hiki2md.new.convert(source).encoding).to eq(Encoding::UTF_8)
    expect(Hiki2md.new.convert("{{plugin}}".encode(Encoding::UTF_8)).encoding).
      to eq(Encoding::UTF_8)
  end

  it "retains the legacy public table helpers" do
    converter = Hiki2md.new
    rows = ["||a||b", "||^c||>d"]
    expect(converter.make_matrix(rows)).to eq([[['a', 'b'], ['c', 'd', ''], [' ']], 3])
    expect(converter.make_table(["||a||b"])).to eq(
      "\n|a|b|\n|:----|:----|\n"
    )
    expect(converter.make_table(["||"])).to eq("\n|\n|\n")
  end
end
