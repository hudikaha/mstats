# coding: utf-8
#

require 'net/http'
require 'uri'
require 'json'
require 'pp'
require 'yaml'

# メニュー定義をYAMLから読み込み、プロセス内でキャッシュする。
# Load menu definitions from YAML and cache them for the process lifetime.
def site_menu_entries
    @site_menu_entries ||= YAML.load_file(File.join(__dir__, 'menu.yml'))
end

# page検索用として、区切りなどを除いたlink定義だけを返す。
# Return link definitions only, excluding separators and other controls.
def site_menu_items
    site_menu_entries.select { |entry| entry['href'] }
end

# enabled未指定は両言語、配列指定は列挙した言語だけを表示する。
# With no enabled setting, show both languages; an array limits visibility.
def site_menu_item_enabled?(item, lang)
    enabled = item.fetch('enabled', true)
    return enabled if enabled == true || enabled == false

    Array(enabled).map(&:to_s).include?(lang.to_s)
end

# 指定言語の共通サイトメニューをHTMLとして出力する。
# Render the shared site menu in the requested language.
def print_site_menu(lang)
    visible_entries = site_menu_entries.take_while { |item| item['type'] != 'stop' }
    links = '<hr>' + visible_entries.filter_map{|item|
        if item['type'] == 'separator'
            next '<hr>' if site_menu_item_enabled?(item, lang)
            next
        end
        next unless item['href']
        next if item['enabled'] == false

        label = item[lang.to_s] || item['ja']
        separator = item['href'].include?('?') ? '&amp;' : '?'
        href = "#{item['href']}#{separator}l=#{lang}"
        enabled_ja = site_menu_item_enabled?(item, :ja)
        enabled_en = site_menu_item_enabled?(item, :en)
        hidden = site_menu_item_enabled?(item, lang) ? '' : ' hidden'
        "<p#{hidden}><a class=\"site-menu-label\" data-ja=\"#{item['ja']}\" data-en=\"#{item['en']}\" data-enabled-ja=\"#{enabled_ja}\" data-enabled-en=\"#{enabled_en}\" data-path=\"#{item['href']}\" href=\"#{href}\">#{label}</a></p>"
    }.join
    print <<~HTML
      <style>
        .left-column.site-menu { flex: 0 0 200px; width: 200px; margin-right: 12px; box-sizing: content-box; }
        #wrapper { flex-wrap: nowrap; }
        .right-column { flex: 1 1 auto; width: auto; min-width: 0; box-sizing: border-box; }
        .site-menu-toggle { display: none; }
        .site-menu-head { display: flex; align-items: center; justify-content: space-between; }
        .site-title { display: grid; grid-template-columns: minmax(0, 1fr) 72px; align-items: center; width: 100%; }
        .site-title h1 { grid-column: 1; margin-left: 0; margin-right: 0; }
        .site-title-qr { grid-column: 2; display: inline-flex; justify-self: end; }
        .site-title-qr img { display: block; width: 72px; height: 72px; }
        @media (max-width: 750px) {
          #wrapper { flex-wrap: wrap; }
          .left-column.site-menu { width: 100%; flex: 0 0 100%; float: none; margin-right: 0; box-sizing: border-box; }
          .right-column { width: 100%; float: none; box-sizing: border-box; }
          .site-menu-toggle { display: block; border: 0; background: transparent; padding: .2em .5em; font-size: 1.8em; line-height: 1; cursor: pointer; }
          .site-menu-links { display: none; width: 100%; box-sizing: border-box; padding: .4em .8em; background: white; }
          .site-menu-links.is-open { display: block; }
          .site-title { grid-template-columns: minmax(0, 1fr) 56px; }
          .site-title-qr img { width: 56px; height: 56px; }
        }
      </style>
      <div class="left-column site-menu">
        <div class="site-menu-head">
          <div class="site-menu-twitter"><img src="twitter.svg" width="25"><a href="https://twitter.com/hudikaha">@hudikaha</a></div>
          <button class="site-menu-toggle" type="button" aria-expanded="false" aria-label="#{lang == :en ? 'Open menu' : 'メニューを開く'}" title="#{lang == :en ? 'Open menu' : 'メニューを開く'}">☰</button>
        </div>
        <nav class="site-menu-links">#{links}</nav>
        <script>
          (function () {
            const root = document.currentScript.parentElement;
            const button = root.querySelector('.site-menu-toggle');
            const links = root.querySelector('.site-menu-links');
            button.addEventListener('click', function () {
              const open = links.classList.toggle('is-open');
              button.textContent = open ? '×' : '☰';
              button.setAttribute('aria-expanded', open ? 'true' : 'false');
              button.setAttribute('aria-label', open ? '#{lang == :en ? 'Close menu' : 'メニューを閉じる'}' : '#{lang == :en ? 'Open menu' : 'メニューを開く'}');
            });
          }());
          window.updateSiteMenu = function (language) {
            document.querySelectorAll('.site-menu-label').forEach(function (link) {
              link.textContent = link.getAttribute('data-' + language) || link.getAttribute('data-ja');
              link.parentElement.hidden = link.getAttribute('data-enabled-' + language) === 'false';
              const path = link.getAttribute('data-path');
              link.href = path + (path.includes('?') ? '&' : '?') + 'l=' + language;
            });
          };
        </script>
      </div>
    HTML
end

# ページタイトルと現在URLのQRコードを共通レイアウトで出力する。
# Render the page title and a QR code for the current URL in the shared layout.
def print_site_title(title, lang)
    script = ENV['SCRIPT_NAME'].to_s
    script = $PROGRAM_NAME if script.empty?
    page = File.basename(script)
    item = site_menu_items.find{|entry| File.basename(entry['href'].split('?', 2).first) == page}
    print '<div class="site-title">'
    print "<h1>#{title}</h1>"
    if item
        href = item['href'].split('?', 2).first
        qr = "qr/#{href.tr('/', '_')}.svg"
        url = "https://medicalfacts.info/#{href.sub(%r{\A/+}, '')}"
        alt = lang == :en ? 'QR code for this page' : 'このページのQRコード'
        print "<a class=\"site-title-qr\" href=\"#{url}\"><img src=\"#{qr}\" alt=\"#{alt}\" title=\"#{alt}\"></a>"
    end
    print "</div>\n"
end

# Web公開領域外の秘密ファイルからElasticsearch認証を設定する。
# Configure Elasticsearch authentication from a secret file outside the web root.
def elastic_basic_auth(request)
    credentials_file = File.expand_path('~/.config/mstats/espass.txt')
    unless File.file?(credentials_file) && File.readable?(credentials_file)
        raise '~/.config/mstats/espass.txt is required'
    end

    user, password = File.read(credentials_file).strip.split(':', 2)
    if user.to_s.empty? || password.to_s.empty?
        raise '~/.config/mstats/espass.txt must use account:password format'
    end
    request.basic_auth(user, password)
end

# 言語、CSS、メニュー、タイトルを含む共通HTMLヘッダーを出力する。
# Render the shared HTML header, including language, CSS, menu, and title.
def print_header(**opts)
    print <<EOF
Content-type: text/html; chaset=utf-8

<!DOCTYPE html>
<html>
<head>
  <meta http-equiv="content-type" content="text/html; charset=utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <script src="https://cdn.jsdelivr.net/npm/vega@5.21.0"></script>
  <script src="https://cdn.jsdelivr.net/npm/vega-lite@5.2.0"></script>
  <script src="https://cdn.jsdelivr.net/npm/vega-embed@6.20.0"></script>
  <title>#{opts[:title]}</title>
</head>
<body>
  <link rel="stylesheet" href="mfacts.css">
EOF
    if ! opts[:iframe]
        print <<EOF
  <div id="wrapper">
EOF
        print_site_menu(defined?($l) && $l ? $l : :ja)
        print <<EOF
  <div class="right-column">
EOF
        print_site_title(opts[:title], defined?($l) && $l ? $l : :ja)
    end
    if opts[:barner]
        print <<EOF
  <div style="text-align: center;">
   <a href="https://songenshi-kyokai.or.jp/" target="_blank"><img src="https://songenshi-kyokai.or.jp/honbu/wp-content/uploads/2020/03/logo_w300.gif" border=1></a>
  </div>
EOF
    end
end

# Elasticsearchを検索し、Symbolキーの統一レコード配列を返す。
# Query Elasticsearch and return a canonical array of symbol-keyed records.
def elastic_search(**opts)
    uri = URI.parse("http://localhost:9200/#{opts[:index]}/_search")
    request = Net::HTTP::Post.new(uri)
    elastic_basic_auth(request)
    request.content_type = "application/json"

    filters = opts[:filter] || []
    should = opts[:should] || []
    body = {
        "size" => opts[:size] || 100000,
        "query" => {
            "bool" => {
                "filter" => filters,
                "must_not" => opts[:must_not] || []
            }
        },
        "_source" => opts[:source] || []
    }
    unless should.empty?
        body['query']['bool']['should'] = should
        body['query']['bool']['minimum_should_match'] = 1
    end

    request.body = JSON.pretty_generate(body)
    if opts[:debug] =~ /^SHOWONLY/
        puts
        puts request.body
        return [] if opts[:debug] == 'SHOWONLY_QUERY'
    end

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
        http.request(request)
    end
    unless response.is_a?(Net::HTTPSuccess)
        raise "Elasticsearch search failed: HTTP #{response.code}: #{response.body}"
    end

    if opts[:debug] == 'SHOWONLY'
        puts response.body
    end

    parsed = JSON.parse(response.body)
    if parsed['error']
        raise "Elasticsearch search failed: #{parsed['error']}"
    end

    parsed.fetch('hits').fetch('hits').map do |hit|
        hit.fetch('_source', {}).transform_keys(&:to_sym).merge(_id: hit['_id'])
    end
end

# 標準出力を画面とキャッシュファイルへ同時に書き出す補助機能。
# Helpers for writing standard output to both the console and a cache file.
module Output
    def self.console_and_cache(cache)
        if File.exist?(cache)
            File.open(cache) do |fd|
                print fd.read
            end
            exit
        end
        defout = File.new(cache, 'w')
        class << defout
            alias_method :write_org, :write
            def write(str)
                STDOUT.write(str)
                self.write_org(str)
            end
        end
        $stdout = defout
    end
end

# Hashを区切り文字付き文字列へ変換する互換用拡張。
# Compatibility extension for joining Hash entries with separators.
class Hash
    def join(str1, str2)
        to_a.collect{|array|
            array.join(str1)
        }.join(str2)
    end
end
