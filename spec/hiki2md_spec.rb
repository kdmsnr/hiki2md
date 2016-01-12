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

  it 'lsit' do
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
    pre
    text
    
    text
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
end
