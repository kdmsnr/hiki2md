require 'spec_helper'

describe Hiki2md do
  it 'plugin' do
    assert("{{hoge}}", "")
  end

  it 'comment' do
    assert("//", "")
  end

  it 'headline' do
    assert("! Headline1"    , "# Headline1")
    assert("!Headline1"     , "# Headline1")
    assert("!! Headline2"   , "## Headline2")
    assert("!!Headline2"    , "## Headline2")
    assert("!!! Headline3"  , "### Headline3")
    assert("!!!Headline3"   , "### Headline3")
    assert("!!!! Headline4" , "#### Headline4")
    assert("!!!!Headline4"  , "#### Headline4")
    assert("!!!!! Headline5", "##### Headline5")
    assert("!!!!!Headline5" , "##### Headline5")
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
    assert("[[http://example.com/abc.gif]]", "![](http://example.com/abc.gif)")
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
    hiki =<<-EOS
    pre
    text
    
    text
EOS

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

|test1|test2|test3|
|:----|:----|:----|
|test4|test5||
| |test6|test7|

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

end
