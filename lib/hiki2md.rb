# -*- coding: utf-8 -*-
require 'hiki2md/version'

class Hiki2md
  def convert(lines)
    @outputs = []

    @in_plugin_block = false
    @in_preformatted_block = false
    @in_multiline_preformatted_block = false
    @in_table_block = false
    @in_dl_block = false
    @table_contents = []

    lines.split(/\n/).each do |line|
      # プラグイン
      if @in_plugin_block
        if line =~ /}}\z/
          @in_plugin_block = false
        end
        next
      end

      if line =~ /\A{{/
        next if line =~ /\A{{.+}}\z/
        @in_plugin_block = true
      end

      # 整形済みテキスト（複数行）
      if @in_multiline_preformatted_block
        if line =~ /\A>>>/
          @in_multiline_preformatted_block = false
          @outputs << '```'
          next
        end
        @outputs << line
        next
      end

      if line =~ /\A<<<\s*(.*)/
        @in_multiline_preformatted_block = true
        @outputs << "```#{$1}"
        next
      end

      # 整形済みテキスト
      if @in_preformatted_block
        if line =~ /\A[ \t]+/
          @outputs << line.strip
          next
        else
          @outputs << "```"
          @in_preformatted_block = false
        end
      end

      if line =~ /\A[ \t]+/
        @in_preformatted_block = true
        @outputs << "```\n#{line.strip}"
        next
      end

      # コメント削除
      next if line =~ %r|\A//.*\z|

      # 引用
      line.gsub! /\A""/, '>'

      # リンク
      line.gsub! /\[{2}([^\[\]\|]+?)\|([^\[\]\|]+?)\]{2}/, "[\\1](\\2)"

      # 強調
      line.gsub! /'''(.+)'''/, "**\\1**"
      line.gsub! /''(.+)''/, "*\\1*"

      # 取り消し
      line.gsub! /\=\=(.+)\=\=/, "~~\\1~~"

      # 箇条書き
      line.gsub! /\A[*]{3} ?/, '    - '
      line.gsub! /\A[*]{2} ?/, '  - '
      line.gsub! /\A[*] ?/   , '- '

      line.gsub! /\A[#]{3} ?/  , '      1. '
      line.gsub! /\A[#]{2} ?/  , '   1. '
      line.gsub! /\A[#] ?/     , '1. '

      # 定義リスト description_list
      if m0 = line.match(/\A\:(.+)\:(.*)/)
        m1=m0[1].gsub /\[(.*)\]\((.*)\)/, "<a href=\"\\2\">\\1</a>" #for link in dlist
        m2=m0[2].gsub /\[(.*)\]\((.*)\)/, "<a href=\"\\2\">\\1</a>"
        unless @in_dl_block
          @outputs << "<dl>"
        end
        @outputs << "<dt>#{m1}</dt><dd>#{m2}</dd>"
        @in_dl_block = true
        next
      end

      if @in_dl_block
        if line !=~ /\A\:.+\:.+/
          @outputs << "</dl>"
          @in_dl_block = false
        end
      end

      # 見出し
      line.gsub! /\A!{5} ?/ , '##### '
      line.gsub! /\A!{4} ?/ , '#### '
      line.gsub! /\A!{3} ?/ , '### '
      line.gsub! /\A!{2} ?/ , '## '
      line.gsub! /\A! ?/    , '# '

      # 画像
      line.gsub! /\[{2}([^\[\]\|]+?)\]{2}/, "![](\\1)"

      # テーブル
      if line =~ /\A\|\|/
        @in_table_block = true
        @table_contents << line
        next
      end

      if @in_table_block
        @outputs << make_table(@table_contents)
        @in_table_block = false
        @table_contents = []
      end

      @outputs << line
    end

    # ensure
    if @in_table_block
      @outputs << make_table(@table_contents)
      @in_table_block = false
      @table_contents = []
    end

    # ensure
    if @in_preformatted_block
      @outputs << "```"
    end

    # ensure
    if @in_dl_block
      @outputs << "</dl>"
      @in_dl_block = false
    end


    @outputs.join("\n")
  end

  # tableから連結作用素に対応したmatrixを作る
  # input:lineごとに分割されたcontents
  # output:matrixと最長列数
  def make_matrix(contents)
    t_matrix = []
    contents.each do |line|
      row = line.split('||')
      row.shift
      t_matrix << row
    end

    # vertical joint row
    t_matrix.each_with_index do |line, i|
      line.each_with_index do |e, j|
        if e =~ /\^+/
          t_matrix[i][j] = Regexp.last_match.post_match
          Regexp.last_match.size.times do |k|
            t_matrix[i + k + 1] ||= []
            t_matrix[i + k + 1].insert(j, " ")
          end
        end
      end
    end

    # horizontal joint column
    max_col = 0
    t_matrix.each_with_index do |line, i|
      n_col = line.size
      j_col = 0
      line.each do |e|
        if e =~ />+/
          t_matrix[i][j_col] = Regexp.last_match.post_match
          cs = Regexp.last_match.size
          cs.times do
            j_col += 1
            t_matrix[i][j_col] = ""
          end
          n_col += cs
        else
          t_matrix[i][j_col] = e
          j_col += 1
        end
      end
      max_col = n_col if n_col > max_col
    end

    [t_matrix, max_col]
  end

  # tableを整形する
  def make_table(table_contents)
    contents, max_col = make_matrix(table_contents)

    align_line = "|"
    max_col.times { align_line << ':----|' }
    align_line << "\n"

    table = "\n"
    contents.each_with_index do |line, idx|
      row = "|"
      line.each do |e|
        row << "#{e}|"
      end
      table << row + "\n"

      # insert table alignment after 1st line
      if idx == 0
        table << align_line
      end
    end

    table
  end
end
