# -*- coding: utf-8 -*-
require 'hiki2md/version'

class Hiki2md
  def convert(lines)
    @outputs = []

    @in_plugin_block = false
    @in_preformated_block = false
    @in_table_block = false
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

      # form付きの整形済みテキスト(by daddygon 16/3/13)
      if line =~ /\A<<<\s*(.+)/
        @in_preformated_block = true
        form = $1
        @outputs << "```#{form}"
        next
      end

      # コメント削除
      next if line =~ %r|\A//.*\z|

      # 整形済みテキスト
      # hikiにて改行を省略した場合(by daddygon 16/3/14)
#      line.gsub! /\A[ \t]+/, '    '
      line.gsub! /\A[ \t]+/, "\n\t"
#      line.gsub! /\A[ \t]+/, "> "


      # 引用
      line.gsub! /\A""/, '>'

      # リンク
      line.gsub! /\[{2}([^\[\]\|]+?)\|([^\[\]\|]+?)\]{2}/, "[\\1](\\2)"

      # 強調
      line.gsub! /'''(.+)'''/, "**\\1**"
      line.gsub! /''(.+)''/, "*\\1*"

      # 取り消し
      line.gsub! /\=\=(.+)\=\=/, "~~\\1~~"

      # 画像
      line.gsub! /\[{2}([^\[\]\|]+?)\]{2}/, "![](\\1)"


      # 箇条書き
      line.gsub! /\A[*]{3} ?/, '    - '
      line.gsub! /\A[*]{2} ?/, '  - '
      line.gsub! /\A[*] ?/   , '- '

      line.gsub! /\A[#]{3} ?/  , '    1. '
      line.gsub! /\A[#]{2} ?/  , '  1. '
      line.gsub! /\A[#] ?/     , '1. '

      # descriptions by daddygon 16/3/14
      if line=~/\A\:(.+)\:(.+)/ then
        line = "<dl><dt> #{$1} </dt> <dd> #{$2} </dd></dl>"
      end

      # 見出し
      line.gsub! /\A!{5} ?/ , '##### '
      line.gsub! /\A!{4} ?/ , '#### '
      line.gsub! /\A!{3} ?/ , '### '
      line.gsub! /\A!{2} ?/ , '## '
      line.gsub! /\A! ?/    , '# '

      if line =~ /\A\|\|/ then
        @in_table_block = true
        @table_contents << line
      end

      if @in_table_block then
        if !(line =~ /\A\|\|/) then
          @outputs << make_table(@table_contents)
          @outputs << line
          @in_table_block = false
          @table_contents = []
        end
      else
        @outputs << line
      end
    end
    @outputs.join("\n")
  end

  # tables by daddygon 16/3/14
  # tableから連結作用素に対応したmatrixを作る
  # input:lineごとに分割されたcont
  # output:matrixと最長列数
  def make_matrix(cont)
    t_matrix=[]
    cont.each{|line|
      row=line.split('||')
      row.slice!(0)
#      row.slice!(-1) if row.slice(-1)=="\n"
      t_matrix << row
    }
    # vertical joint row
    t_matrix.each_with_index{|line,i|
      line.each_with_index{|ele,j|
        if ele=~/\^+/ then
          t_matrix[i][j]="#{$'}"
          rs=$&.size
          c_rs=rs/2
          rs.times{|k| t_matrix[i+k+1].insert(j,"")}
        end
      }
    }
    # horizontal joint column
    max_col=0
    t_matrix.each_with_index{|line,i|
      n_col=line.size
      j_col=0
      line.each_with_index{|ele,j|
        if ele=~/>+/ then
          cs=$&.size
          t_matrix[i][j_col]="#{$'}"
          cs.times{
            j_col+=1
            t_matrix[i][j_col]=""
          }
          n_col+=cs
        else
          t_matrix[i][j_col]=ele
          j_col+=1
        end
      }
      max_col = n_col if n_col>max_col
    }
    return t_matrix,max_col
  end

  DT_ALIGN=':----|'
  # tableを整形する
  def make_table(table_cont)
    cont,max_col = make_matrix(table_cont)

    align_line = "|"
    max_col.times{ align_line << DT_ALIGN}
    align_line << "|\n"

    buf = "\n"
    cont.each_with_index{|line,i|
      buf0 = "|"
      line.each{|ele|
        buf0 << "#{ele} |"
      }
      buf << buf0+"\n"
      buf << align_line if i==0 #insert table alignment after 1st line
    }
    return buf
  end

end
