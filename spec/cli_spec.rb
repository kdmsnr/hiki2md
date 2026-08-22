require 'spec_helper'
require 'open3'
require 'rbconfig'
require 'tempfile'

describe 'hiki2md command' do
  def run_cli(*arguments)
    root = File.expand_path('..', __dir__)
    environment = {
      'RUBYLIB' => File.join(root, 'lib'),
      'RUBYOPT' => ''
    }
    stdout, stderr, status = Open3.capture3(
      environment,
      RbConfig.ruby,
      File.join(root, 'exe', 'hiki2md'),
      *arguments
    )
    [
      stdout.force_encoding(Encoding::UTF_8),
      stderr.force_encoding(Encoding::UTF_8),
      status
    ]
  end

  it 'wires the InterWiki, WikiName, and plugin options together' do
    source_file = Tempfile.new(['hiki2md-source', '.hiki'])
    map_file = Tempfile.new(['hiki2md-interwiki', '.yml'])

    begin
      source_file.write("WikiName {{plugin}} [[Docs:Page Name]]")
      source_file.close
      map_file.write("Docs: https://example.com/docs/\n")
      map_file.close

      stdout, _stderr, status = run_cli(
        '--no-wiki-name',
        '--preserve-plugins',
        '--interwiki-map', map_file.path,
        source_file.path
      )

      expect(status).to be_success
      expect(stdout).to eq(
        "WikiName {{plugin}} [Docs:Page Name](https://example.com/docs/Page%20Name)\n"
      )
    ensure
      source_file.close!
      map_file.close!
    end
  end

  it 'prints option help successfully' do
    stdout, _stderr, status = run_cli('--help')

    expect(status).to be_success
    expect(stdout).to include(
      '--[no-]wiki-name',
      '--preserve-plugins',
      '--interwiki-map',
      '--input-encoding'
    )
  end

  it 'falls back to option help when no file is specified' do
    stdout, stderr, status = run_cli
    help_stdout, help_stderr, help_status = run_cli('--help')

    expect(status).to be_success
    expect(help_status).to be_success
    expect(stdout).to eq(help_stdout)
    expect(stderr).to eq(help_stderr)
  end

  it 'reports multiple input files as a concise usage error' do
    stdout, stderr, status = run_cli('one.hiki', 'two.hiki')

    expect(status).not_to be_success
    expect(stdout).to be_empty
    expect(stderr).to include(
      'hiki2md: expected exactly one input file',
      'Usage: hiki2md [options] <file>'
    )
    expect(stderr).not_to include('ArgumentError', "\tfrom ")
  end

  it 'reports options without an input file as a usage error' do
    [
      ['--preserve-plugins'],
      ['--input-encoding', 'EUC-JP'],
      ['--']
    ].each do |arguments|
      stdout, stderr, status = run_cli(*arguments)

      expect(status).not_to be_success
      expect(stdout).to be_empty
      expect(stderr).to include(
        'hiki2md: expected exactly one input file',
        'Usage: hiki2md [options] <file>'
      )
    end
  end

  it 'automatically converts EUC-JP input to UTF-8 Markdown' do
    source_file = Tempfile.new(['hiki2md-euc-jp', '.hiki'])

    begin
      source_file.binmode
      source_file.write(
        "! 日本語\n本文\n日本WikiName語".encode(Encoding::EUC_JP)
      )
      source_file.close

      stdout, _stderr, status = run_cli(source_file.path)

      expect(status).to be_success
      expect(stdout.encoding).to eq(Encoding::UTF_8)
      expect(stdout).to eq("## 日本語\n本文\n日本WikiName語\n")
    ensure
      source_file.close!
    end
  end

  it 'automatically converts Windows-31J input to UTF-8 Markdown' do
    source_file = Tempfile.new(['hiki2md-windows-31j', '.hiki'])

    begin
      source_file.binmode
      source_file.write("! ①\n本文".encode(Encoding::Windows_31J))
      source_file.close

      stdout, _stderr, status = run_cli(source_file.path)

      expect(status).to be_success
      expect(stdout).to eq("## ①\n本文\n")
    ensure
      source_file.close!
    end
  end

  it 'recognizes ISO-2022-JP before its ASCII-compatible bytes as UTF-8' do
    source_file = Tempfile.new(['hiki2md-iso-2022-jp', '.hiki'])

    begin
      source_file.binmode
      source_file.write("! 日本語".encode(Encoding::ISO_2022_JP))
      source_file.close

      stdout, _stderr, status = run_cli(source_file.path)

      expect(status).to be_success
      expect(stdout).to eq("## 日本語\n")
    ensure
      source_file.close!
    end
  end

  it 'removes a UTF-8 BOM before converting the first line' do
    source_file = Tempfile.new(['hiki2md-utf8-bom', '.hiki'])

    begin
      source_file.binmode
      source_file.write("\xEF\xBB\xBF! 日本語".b)
      source_file.close

      stdout, _stderr, status = run_cli(source_file.path)

      expect(status).to be_success
      expect(stdout).to eq("## 日本語\n")
    ensure
      source_file.close!
    end
  end

  it 'accepts an explicit input encoding when auto detection is ambiguous' do
    source_file = Tempfile.new(['hiki2md-iso-8859-1', '.hiki'])

    begin
      source_file.binmode
      source_file.write("! caf\xE9".b)
      source_file.close

      stdout, _stderr, status = run_cli(
        '--input-encoding', 'ISO-8859-1', source_file.path
      )

      expect(status).to be_success
      expect(stdout).to eq("## café\n")
    ensure
      source_file.close!
    end
  end

  it 'reports bytes that do not form supported text without replacing them' do
    source_file = Tempfile.new(['hiki2md-invalid-encoding', '.hiki'])

    begin
      source_file.binmode
      source_file.write("! text\xFF".b)
      source_file.close

      _stdout, stderr, status = run_cli(source_file.path)

      expect(status).not_to be_success
      expect(stderr).to include(
        'unable to detect input encoding',
        '--input-encoding ENCODING'
      )
      expect(stderr).not_to include('invalid byte sequence in UTF-8')
    ensure
      source_file.close!
    end
  end
end
