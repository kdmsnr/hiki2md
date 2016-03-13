# -*- coding: utf-8 -*-
require 'hiki2md/version'

class Hiki2md
  def convert(lines)
    @outputs = []

    @in_plugin_block = false
    @in_preformated_block = false

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

      # 整形済みテキスト
      if @in_preformated_block
        if line =~ /\A>>>/
          @in_preformated_block = false
          @outputs << '```'
          next
        end
        @outputs << line
        next
      end

      if line =~ /\A<<<\z/
        @in_preformated_block = true
        @outputs << '```'
        next
      end

      if line =~ /\A<<<\s*(.+)/
        @in_preformated_block = true
        form = $1
        @outputs << "```#{form}\n"
        next
      end

      # コメント削除
      next if line =~ %r|\A//.*\z|

      # 整形済みテキスト
      line.gsub! /\A[ \t]+/, '    '

      # 引用
      line.gsub! /\A""/, '>'

      # リンク
      line.gsub! /\[{2}([^\[\]\|]+?)\|([^\[\]\|]+?)\]{2}/, "[\\1](\\2)"

      # 箇条書き
      line.gsub! /\A[*]{3} ?/, '    - '
      line.gsub! /\A[*]{2} ?/, '  - '
      line.gsub! /\A[*] ?/   , '- '

      line.gsub! /\A[#]{3} ?/  , '    1. '
      line.gsub! /\A[#]{2} ?/  , '  1. '
      line.gsub! /\A[#] ?/     , '1. '

      # 見出し
      line.gsub! /\A!{5} ?/ , '##### '
      line.gsub! /\A!{4} ?/ , '#### '
      line.gsub! /\A!{3} ?/ , '### '
      line.gsub! /\A!{2} ?/ , '## '
      line.gsub! /\A! ?/    , '# '

      # 強調
      line.gsub! /'''(.+)'''/, "**\\1**"
      line.gsub! /''(.+)''/, "*\\1*"

      # 取り消し
      line.gsub! /\=\=(.+)\=\=/, "~~\\1~~"

      # 画像
      line.gsub! /\[{2}([^\[\]\|]+?)\]{2}/, "![](\\1)"

      @outputs << line
    end
    @outputs.join("\n")
  end
end
