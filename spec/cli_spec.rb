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
    Open3.capture3(
      environment,
      RbConfig.ruby,
      File.join(root, 'exe', 'hiki2md'),
      *arguments
    )
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
    expect(stdout).to include('--[no-]wiki-name', '--preserve-plugins', '--interwiki-map')
  end
end
