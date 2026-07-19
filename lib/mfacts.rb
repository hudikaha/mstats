# coding: utf-8
#

require 'net/http'
require 'uri'
require 'json'
require 'pp'
require 'yaml'

# メニュー定義をYAMLから読み込み、プロセス内でキャッシュする。
# Load menu definitions from YAML and cache them for the process lifetime.
def site_menu_items
    @site_menu_items ||= YAML.load_file(File.join(__dir__, 'menu.yml'))
end

# 指定言語の共通サイトメニューをHTMLとして出力する。
# Render the shared site menu in the requested language.
def print_site_menu(lang)
    links = '<hr>' + site_menu_items.map{|item|
        label = item[lang.to_s] || item['ja']
        separator = item['href'].include?('?') ? '&amp;' : '?'
        href = "#{item['href']}#{separator}l=#{lang}"
        "<p><a class=\"site-menu-label\" data-ja=\"#{item['ja']}\" data-en=\"#{item['en']}\" data-path=\"#{item['href']}\" href=\"#{href}\">#{label}</a></p>"
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

# Web公開領域外の秘密ファイルまたは環境変数からElasticsearch認証を設定する。
# Configure Elasticsearch authentication from an environment variable or a secret outside the web root.
def elastic_basic_auth(request)
    password_file = File.expand_path('~magician/.config/mstats/espass.txt')
    password = ENV['ES_PASSWORD']
    password = File.read(password_file).strip if password.to_s.empty? && File.file?(password_file)
    raise 'ES_PASSWORD or ~/.config/mstats/espass.txt is required' if password.to_s.empty?
    request.basic_auth(ENV.fetch('ES_USER', 'elastic'), password)
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

# Elasticsearchを検索し、旧形式の集計結果を返す。
# Query Elasticsearch and return results in the legacy aggregation shape.
def elastic(**opts)
    uri = URI.parse("http://localhost:9200/#{opts[:index]}/_search")
    request = Net::HTTP::Get.new(uri)
    elastic_basic_auth(request)
    request.content_type = "application/json"

    year = opts[:year].is_a?(Numeric) ? opts[:year] : 2009
    request.body = <<EOF
{
  "query": {
    "bool": {
      "must": [
        { "range": {"date": {"gte": "#{year}-01-01", "lt": "now" } } }
      ]
    }
  },
EOF
if opts[:items]
    request.body += <<EOF
  "_source": [
EOF
    opts[:items].each do |i|
        request.body += <<EOF
    "#{i}",
EOF
    end
    request.body += <<EOF
    "date"
  ]
EOF
end
    request.body += <<EOF
  "size": 100000
}
EOF

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
        http.request(request)
    end

    data = JSON.parse(response.body)['hits']['hits']

    return data
end

# Elasticsearchを検索し、mstats系ページ向けに整形した結果を返す。
# Query Elasticsearch and return results shaped for mstats-based pages.
def elastic2(**opts)
    uri = URI.parse("http://localhost:9200/#{opts[:index]}/_search")
    request = Net::HTTP::Get.new(uri)
    elastic_basic_auth(request)
    request.content_type = "application/json"

    size = opts[:size] ? opts[:size] : 100000
    body = {
        "size" => size,
        "query" => {
            "bool" => {
                "must" => [
                    {
                        "bool" => {
                            "should" => opts[:should]
                        }
                    }
                ]
            }
        },
        "_source" => opts[:source]
    }

    body['query']['bool']['must'] += opts[:must]
    request.body = JSON.pretty_generate(body)

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
        http.request(request)
    end

    if opts[:debug] == 'SHOWONLY'
        puts
        puts request.body
        puts response.body
        return
    end

    data = JSON.parse(response.body)['hits']['hits']

    return data
end

# 統計CSV由来の文字列を欠測値に配慮して数値化する。
# Convert statistical CSV strings to numbers while preserving missing values.
class String
    def to_numeric
        begin
            Integer(self)
        rescue ArgumentError
            begin
                Float(self)
            rescue ArgumentError
                self
            end
        end
    end
end

# Elasticsearchの複合集計をキー順のHashへ正規化する。
# Normalize compound Elasticsearch aggregations into a key-sorted Hash.
def elastic3(**opts)
    uri = URI.parse("http://localhost:9200/#{opts[:index]}/_search")
    request = Net::HTTP::Get.new(uri)
    elastic_basic_auth(request)
    request.content_type = "application/json"

    size = opts[:size] ? opts[:size] : 100000
    body = {
        "size" => size,
        "query" => {
            "bool" => {
                "must_not" => opts[:must_not],
                "filter" => [
                    {
                        "bool" => {
                            "should" => opts[:should]
                        }
                    }
                ] + opts[:must]
            }
        },
        "_source" => opts[:source]
    }

    request.body = JSON.pretty_generate(body)

    if opts[:debug] =~ /^SHOWONLY/
        puts
        puts request.body
        return if opts[:debug] == 'SHOWONLY_QUERY'
    end

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
        http.request(request)
    end

    if opts[:debug] == 'SHOWONLY'
        puts JSON.parse(response.body)['hits']['hits'].map{|v| [v['_id'], v['_source']]}.to_h
        return
    end

    JSON.parse(response.body)['hits']['hits'].
        map{|v| [v['_id'],
                 v['_source'].
                     map{|k, v| [k.to_sym,
                                 v.is_a?(String) ? v.to_numeric : nil]}.to_h]}.
        sort{|a, b| a[0]<=>b[0]}.to_h
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
