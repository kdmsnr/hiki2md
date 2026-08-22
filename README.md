# Hiki2md

[![Build Status](https://travis-ci.org/kdmsnr/hiki2md.svg?branch=master)](https://travis-ci.org/kdmsnr/hiki2md)

Converter of Hiki to Markdown.

## Installation

Hiki2md requires Ruby 2.2 or newer.

Add this line to your application's Gemfile:

```ruby
gem 'hiki2md'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install hiki2md

## Usage

### Ruby

```ruby
require "hiki2md"

converter = Hiki2md.new(
  interwiki_map: {
    "Google" => "https://www.google.com/search?q=",
    "Issues" => "https://example.com/issues/$1"
  },
  use_wiki_name: true,
  preserve_plugins: false
)

markdown = converter.convert(hiki_source)
```

Internal page links receive a `.md` extension. InterWiki values either have
the encoded page name appended, or can contain `$1` where the page name should
be inserted.

### Command line

```console
$ hiki2md [options] input.hiki
```

Options:

- `--interwiki-map PATH`: load InterWiki prefixes from a YAML mapping.
- `--[no-]wiki-name`: enable or disable automatic WikiName links.
- `--preserve-plugins`: retain plugins as escaped Markdown text instead of
  removing them.
- `-E`, `--input-encoding ENCODING`: override the detected source encoding.

The command writes UTF-8 Markdown. It automatically recognizes BOM-marked
Unicode input and the common Hiki encodings UTF-8, EUC-JP, Windows-31J, and
ISO-2022-JP. Since legacy encodings can be ambiguous, use
`--input-encoding` to specify the source explicitly when needed:

```console
$ hiki2md --input-encoding EUC-JP TextFormattingRules.ja
```

### Supported Hiki syntax

The converter targets Hiki's default style and emits GitHub Flavored Markdown
(GFM).

| Hiki | Output |
| --- | --- |
| `!` through `!!!!!` | headings 2 through 6 |
| `*` / `#` | nested unordered / ordered lists |
| `''text''` / `'''text'''` | emphasis / strong emphasis |
| `==text==` / double-backtick text | strikethrough / inline code |
| `[[Page]]` / `[[label\|target]]` | page, URL, and InterWiki links |
| image URLs | Markdown images, including basename or labeled alt text |
| leading space or tab, `<<<` ... `>>>` | fenced code blocks |
| `""` | recursive blockquotes |
| `:term:description` | HTML definition lists |
| `\|\|cell` | raw HTML tables |
| `----` | horizontal rules |
| `// comment` | removed comments |

Hiki permits tables without a header row, while GFM pipe tables require one.
All Hiki tables are therefore emitted as raw HTML so ordinary `td` cells,
explicit `!` header cells, and `^` / `>` row and column spans retain their
meaning.

Hiki plugins are executable Ruby extensions and cannot be converted
generically. Plugin calls are removed by default. Use `preserve_plugins: true`
or `--preserve-plugins` to keep them as escaped Markdown text for manual
migration. Plugin-looking text inside preformatted blocks is always kept
literally.

### Version 0.3 output changes

Version 0.3 favors the rendered meaning of Hiki over preserving the exact
Markdown source produced by 0.2. In particular, all tables now use raw HTML,
ordered-list indentation follows CommonMark, and Markdown-looking source text
is escaped when Hiki treats it as plain text. The legacy public `make_matrix`
and `make_table` helpers retain their 0.2 behavior.

Lists deeper than 100 levels use raw HTML to keep output growth bounded.
Uniform blockquotes may be arbitrarily deep; blocks containing more than 100
distinct quote depths raise `ArgumentError` instead of risking stack or CPU
exhaustion.

See Hiki's
[TextFormattingRules](https://hikiwiki.org/en/TextFormattingRules.html) for
the source syntax.

## Development

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kdmsnr/hiki2md. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Inspired by

https://github.com/masasuzu/p5-App-hiki2md
