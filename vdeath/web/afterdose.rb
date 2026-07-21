#!/usr/bin/ruby
# coding: utf-8
# ruby-indent-level: 4
#

require 'net/http'
require 'uri'
require 'json'
require 'cgi'
require 'date'
require 'optparse'
require 'pp'
mfacts = [
    File.expand_path('../../lib/mfacts.rb', __dir__),
    File.expand_path('lib/mfacts.rb', __dir__)
].find { |path| File.file?(path) }
abort 'lib/mfacts.rb not found' unless mfacts
require mfacts

mstats = [
    File.expand_path('../lib/mstats.rb', __dir__),
    File.expand_path('mstats.rb', __dir__)
].find { |path| File.file?(path) }
abort 'mstats.rb not found' unless mstats
require mstats

#
# Debug option
#
$opts = {
    debug: false,
    index: "vdeath2026"
}

op = OptionParser.new do |opts|
    opts.on('--debug yes|no', String, 'Debug on') do |value|
        if value =~ /true|yes|on/
            $opts[:debug] = true
            Log.level = Logger::DEBUG
        end
    end
    opts.on('--index <index>', String, 'Index for ElasticSearch') do |value|
        $opts[:index] = value
    end
end
begin
    op.parse!
rescue
    puts op
    exit
end

#
# Language
#
Lang = {
    'en' => { sel: nil, ja: 'English', en: 'English',
              menu: 'menu_e.js', title: 'COVID-19 Vaxx Doses and Deaths/Mortality in Japan, Weekly-after-dose<br>(All Causes, Person-year Analysis, For unvaxx Weekly from 2021-02-01)'},
    'ja' => { sel: nil, ja: '日本語', en: '日本語',
              menu: 'menu.js', title: '新型コロナワクチン接種回数と接種後週ごとの死亡数・死亡率<br>(全死因、人年法による解析、未接種者は2021-02-01からの週数)'},
}

#
# IFrame
#
IFrame = {
    'true'  => { sel: nil },
    'false' => { sel: nil },
}

#
#
# Locations (Countries and Areas)
#
#Object.send(:remove_const, :Cities)
Cities = {
    'all'      => {sel: nil, ja: '選択市町村合算',  en: 'All selected cities'},
    'jp132101' => {sel: nil, ja: '東京都小金井市',  en: 'Koganei/Tokyo'},
    'jp141500' => {sel: nil, ja: '神奈川県相模原市',en: 'Sagamihara/Kanagawa'},
    'jp221309' => {sel: nil, ja: '静岡県浜松市',    en: 'Hamamatsu/Shizuoka'},
    'jp222267' => {sel: nil, ja: '静岡県牧之原市',  en: 'Makinohara/Shizuoka'},
    'jp232076' => {sel: nil, ja: '愛知県豊川市',    en: 'Toyokawa/Aichi'},
    'jp232068' => {sel: nil, ja: '愛知県春日井市',  en: 'Kasugai/Aichi'},
    'jp442054' => {sel: nil, ja: '大分県佐伯市',    en: 'Saiki/Oita'},

#    'jp222038' => {sel: nil, ja: '静岡県沼津市',    en: 'Numazu/Shizuoka'},
#    'jp222097' => {sel: nil, ja: '静岡県島田市',    en: 'Shimada/Shizuoka'},
#    'jp282068' => {sel: nil, ja: '兵庫県芦屋市',    en: 'Ashiya/Hyogo'},
#    'jp434841' => {sel: nil, ja: '熊本県津奈木町',  en: 'Tsunagi/Kumamoto'},
#    'jp435015' => {sel: nil, ja: '熊本県錦町',      en: 'Nishiki/Kumamoto'},
#    'jp435112' => {sel: nil, ja: '熊本県五木村',    en: 'Itsuki/Kumamoto'},
#    'jp435139' => {sel: nil, ja: '熊本県球磨村',    en: 'Kuma/Kumamoto'},
#    'jp435317' => {sel: nil, ja: '熊本県苓北町',    en: 'Reihoku/Kumamoto'},
#    'jp433641' => {sel: nil, ja: '熊本県玉東町',    en: 'Gyokuto/Kumamoto'},
#    'jp444618' => {sel: nil, ja: '大分県九重町',    en: 'Kokonoe/Oita'},
#    'jp235636' => {sel: nil, ja: '愛知県豊根村',    en: 'Toyone/Aichi'},
}

#
# Ages
#
Ages = {
    'all'     => { sel: nil, ja: '全年齢',   en: 'All age' },
    '80+'  => { sel: nil, ja: '80歳以上', en: '80+' },
}

Sources = {
    'org' => { sel: nil, ja: '日単位の元データ', en: 'Daily source data' },
    'anon' => { sel: nil, ja: '週単位匿名化データ', en: 'Weekly-anonymized data' }
}

#
# Types weekly stacks
#
Stacks = {
    'deaths'     => { sel: nil, ja: '死亡数', en: 'Deaths' },
    'mortality'  => { sel: nil, ja: '死亡率', en: 'Mortality' },
    'persondays' => { sel: nil, ja: '人日',   en: 'Person-days' },
    'lives'      => { sel: nil, ja: '生者',   en: 'Lives' },
}

#
# Types weekly lines
#
Lines = {
    'deaths'     => { sel: nil, ja: '死亡数', en: 'Deaths' },
    'mortality'  => { sel: nil, ja: '死亡率', en: 'Mortality' },
    'persondays' => { sel: nil, ja: '人日',   en: 'Person-days' },
    'lives'      => { sel: nil, ja: '生者',   en: 'Lives' },
    'rr0'        => { sel: nil, ja: 'リスク比', en: 'Risk-ratio' },
    'rr0ci'      => { sel: nil, ja: '信頼区間', en: 'CI' },
    'rr0log'     => { sel: nil, ja: '対数表示', en: 'Logscale' },
}

#
# Types semiannually bars
#
Bars = {
    'deaths'     => { sel: nil, ja: '死亡数', en: 'Deaths' },
    'mortality'  => { sel: nil, ja: '死亡率', en: 'Mortality' },
    'persondays' => { sel: nil, ja: '人日',   en: 'Person-days' },
    'lives'      => { sel: nil, ja: '生者',   en: 'Lives' },
}

#
# Omits
#
Omits = {
    '1' => { sel: nil, ja: '1回接種を非表示', en: 'Omit 1st dose' },
}

#
# All and Vaxx
#
Doses = {
    '0'    => { sel: nil, ja: '未接種', en: 'Unvaxxed' },
    '1'    => { sel: nil, ja: '1', en: '1' },
    '2'    => { sel: nil, ja: '2', en: '2' },
    '3'    => { sel: nil, ja: '3', en: '3' },
    '4'    => { sel: nil, ja: '4', en: '4' },
    '5'    => { sel: nil, ja: '5', en: '5' },
    '6'    => { sel: nil, ja: '6', en: '6' },
    '7'    => { sel: nil, ja: '7', en: '7' },
    'all'  => { sel: nil, ja: '全体', en: 'All',  },
    'vaxx' => { sel: nil, ja: '接種者全体', en: 'All Vaxxed' },
}

#
# CGI.new
#
$cgi = CGI.new

Consts = {
    'l'       => { hash: Lang,    defaults: ['en'],        selected: 'checked'},
    'i'       => { hash: IFrame,  defaults: ['false'],     selected: 'checked'},
    'c'       => { hash: Cities,  defaults: Cities.keys,   selected: 'checked', keys: [] },
    'ages'    => { hash: Ages,    defaults:   ['all'],     selected: 'checked', keys: [] },
    'src'     => { hash: Sources, defaults: ['org'],       selected: 'checked', keys: [] },
    'stacks'  => { hash: Stacks,  defaults: ['deaths'],    selected: 'checked', keys: [] },
    'lines'   => { hash: Lines,   defaults: ['mortality', 'rr0', 'rr0log'], selected: 'checked', keys: [] },
    'bars'    => { hash: Bars,    defaults: ['mortality'], selected: 'checked', keys: [] },
    'omits'   => { hash: Omits,   defaults: [],            selected: 'checked', keys: [] },
    'doses' => { hash: Doses, defaults: ['0', '2', '3', '4', '5', '6', '7'], selected: 'checked', keys: [] },
}

Consts.each do |k, v|

    # 選択されたものだけチェック
    keys = $cgi[k].split(/,|~|、/)
    keys.each do |key|
        v[:hash][key][:sel] = v[:selected] if v[:hash][key]
    end

    if v[:keys]
        v[:keys] += keys
    end

    # $l を設定
    if k == 'l'
        if ! Lang['en'][:sel] && ENV['HTTP_ACCEPT_LANGUAGE'] =~ /^ja/
            Lang['ja'][:sel] = Consts['l'][:selected]
        end
    end

    # 選択されたものが無ければ default 設定
    if ! v[:hash].find{|k2, v2| v2[:sel] != nil}
        v[:defaults].each do |key|
            begin
                v[:hash][key][:sel] = v[:selected]
            rescue
                Log.error PP.pp(key, '')
                Log.error PP.pp(v, '')
                exit
            end
        end
    end

    # CGI と Consts が同じなら、CGI の並びは活かす。でなければ Consts の並び
    if v[:keys]
        keys2 = v[:hash].select{|k, v| v[:sel]}.keys
        v[:keys] = keys2 if v[:keys].sort != keys2.sort
    end
end

$l = Lang.find{|k, v| v[:sel]}[0].to_sym
$doses = Doses.map{|k, v| v[:sel] ? k : nil}.compact
$filter_1st = {expr: "test(/#{$doses.join('|')}/, datum.dose)",
               step: (97.5/$doses.count).round(2)}

$filter_vaxx = 'true'
$legend = <<EOS
EOS
if $l == :ja
    $legend = <<EOS
"legend": {"labelExpr": "datum.label == '0' ? '0 (未接種)' : (datum.label == 'all' ? '全体' : (datum.label == 'vaxx' ? '接種者全体' : datum.label))"},
EOS
else
    $legend = <<EOS
"legend": {"labelExpr": "datum.label == '0' ? '0 (Unvaxx)' : (datum.label == 'all' ? 'All' : (datum.label == 'vaxx' ? 'All Vaxx' : datum.label))"},
EOS
end

if Lines['rr0ci'][:sel] || Lines['rr0log'][:sel]
    Lines['rr0'][:sel] = 'checked'
end

$opacity = Lines['rr0ci'][:sel] ? '' :
               '"opacity": { "condition": {"param": "highlight", "value": 1}, "value": 0.1},'

#
# Height
#
$height = ($cgi['height'] != '' && $cgi['height'].to_i >= 50) ? $cgi['height'].to_i : 150

# 数値を3桁区切りで表示する。 / Format a number with thousands separators.
def add_commas(number)
  number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
end

print_header(:title => Lang[$l.to_s][:title], :menu => Lang[$l.to_s][:menu],
             :iframe => IFrame['true'][:sel])

$must_not = []
$must = []
$should = []

data0 = elastic_search(
    :index => $opts[:index],
    #:must_not => $must_not,
    #:filter => $must,
    #:should => [],
    :must_not => [],
    :filter => [
        { bool: { should: [{ terms: { 'age.keyword': Ages.keys } }, { terms: { age: Ages.keys } }], minimum_should_match: 1 } },
        { term: { step: Sources['org'][:sel] ? 'orgweek' : 'week' } }
    ],
    :should => [],
    :source => [ 'doc_id', 'areacode', 'area', 'step', 'period', 'age', 'dose', 'deaths', 'persondays', 'mortality', 'lives', 'rr0', 'lb0', 'ub0' ],
    #:source => [],
    #:debug => 'SHOWONLY_QUERY',
    #:debug => 'SHOWONLY',
).to_h { |datum| [datum.delete(:_id), datum] }

$data = Hash.new
data0.each do |k, datum|
    datum2 = datum.dup
    k = k.sub(/_orgweek_/, '_week_')
    datum2[:step] = 'week' if datum2[:step] == 'orgweek'
    # 旧indexの数値文字列を計算対象フィールドだけ数値化する。
    # Convert numeric strings only in calculation fields from the legacy index.
    %i[deaths persondays mortality lives rr0 lb0 ub0].each do |field|
        value = datum2[field]
        next unless value.is_a?(String) && value.match?(/\A-?\d+(?:\.\d+)?\z/)

        datum2[field] = value.include?('.') ? value.to_f : value.to_i
    end
    if $l == :en && Cities[datum2[:areacode]]
        datum2[:area] = Cities[datum2[:areacode]][:en]
    end
    datum2[:mortality] = 0 if datum2[:mortality] == '-'
    datum2[:rr0] = '-' if datum2[:rr0] == 0 || datum2[:rr0] == '0.0'
    $data[k] = datum2
end

# all を作る
hama = $data.select{|k, v| v[:areacode] == 'jp221309'}
data2 = Hash.new
Cities.each do |k1, city|
    next if ! city[:sel]
    data2.merge!($data.select{|k2, v| v[:areacode] == k1})
end

data_all = Hash.new
hama.each do |k, datum|
    datum2 = datum.dup
    datum2[:doc_id] = k.sub(/^jp221309/, 'all')
    datum2[:areacode] = 'all'
    datum2[:area] = Cities['all'][$l]
    set = data2.select{|k, v| v[:step] == datum[:step] &&
                              v[:period] == datum[:period] &&
                              v[:age] == datum[:age] &&
                              v[:dose] == datum[:dose]}
    #pp set
    deaths = datum2[:deaths] = set.map{|k, v| v[:deaths]}.sum
    days = datum2[:persondays] = set.map{|k, v| v[:persondays]}.sum
    datum2[:lives] = set.map{|k, v| v[:lives]}.sum
    #datum2[:mortality] = days != 0 ? (deaths * 100000 * 365 / days).round(2) : '-'
    data_all[datum2[:doc_id]] = datum2
    #pp datum2
    #exit
end

# 接種群と対照群のリスク比、信頼区間、p値を計算する。
# Calculate the risk ratio, confidence interval, and p-value for vaccinated and control groups.
def rr_with_ci(events_i, total_i, events_c, total_c)
    # pi は整数で計算してOK
    pi = total_i == 0 ? '-' : (events_i * 365 * 100_000) / total_i

    ei = events_i.to_f
    ni = total_i.to_f
    ec = events_c.to_f
    nc = total_c.to_f

    # nc=0 の場合は計算不能
    return ['-', '-', '-', pi] if ni.zero? || nc.zero?

    p1 = ei / ni
    p2 = ec / nc

    # 対照群発生率が0なら RR/CI 計算不能
    return ['-', '-', '-', pi] if p2.zero?

    rr = (p1 / p2).round(4)

    if ei.zero? || ec.zero?
        return [rr, '-', '-', pi]
    end

    se_log_rr = Math.sqrt((1/ei - 1/ni) + (1/ec - 1/nc))
    lower = Math.exp(Math.log(rr) - 1.96 * se_log_rr).round(4)
    upper = Math.exp(Math.log(rr) + 1.96 * se_log_rr).round(4)

    [rr, lower, upper, pi]
end

# Risk Ratio
data_all.each do |id, datum|
    id0 = id.sub(/_\d+$|_all$|_vaxx$/, '_0')
    datum0 = data_all[id0]
    (datum[:rr0], datum[:lb0], datum[:ub0], datum[:mortality]) =
        rr_with_ci(datum[:deaths], datum[:persondays], datum0[:deaths], datum0[:persondays])

    datum[:mortality] = 0 if datum[:mortality] == '-'
    datum[:rr0] = '-' if datum[:rr0] == 0 || datum[:rr0] == '0.0'
end

$data.merge!(data_all)

#Log.debug PP.pp($data.values, '')

print <<EOS
  <hr>
  <p class=l>
  <script>
  function submitForm() {
    var l = document.querySelector('input[name="l"]:checked').value;
    var c = Array.from(document.querySelectorAll('input[name="c"]:checked'),
                       checkbox => checkbox.value);
    var ages = Array.from(document.querySelectorAll('input[name="ages"]:checked'),
                       checkbox => checkbox.value);
    var src = document.querySelector('input[name="src"]:checked').value;
    var stacks = Array.from(document.querySelectorAll('input[name="stacks"]:checked'),
                       checkbox => checkbox.value);
    var lines = Array.from(document.querySelectorAll('input[name="lines"]:checked'),
                       checkbox => checkbox.value);
    var bars  = Array.from(document.querySelectorAll('input[name="bars"]:checked'),
                       checkbox => checkbox.value);
    var omits = Array.from(document.querySelectorAll('input[name="omits"]:checked'),
                       checkbox => checkbox.value);
    var doses = Array.from(document.querySelectorAll('input[name="doses"]:checked'),
                       checkbox => checkbox.value);

    var queryString = 'afterdose.rb?l=' + l
                    + '&c=' + c.join('~')
                    + '&ages=' + ages.join('~')
                    + '&src=' + src
                    + '&stacks=' + stacks.join('~')
                    + '&lines=' + lines.join('~')
                    + '&bars=' + bars.join('~')
                    + '&omits=' + omits.join('~')
                    + '&doses=' + doses.join('~')
    ;
    window.location.href = queryString;
  }
  </script>
  <form id="myForm" onsubmit="submitForm(); return false;" style="text-align: left;">
EOS
Cities.each do |k, v|
    print <<EOS
   <span><input type="checkbox" name="c" value="#{k}" #{v[:sel]}> #{v[$l]}</span>
EOS
end
print <<EOS
  <br>
EOS
Sources.each do |k, v|
    print <<EOS
   <span><input type="radio" name="src" value="#{k}" #{v[:sel]}> #{v[$l]}</span>
EOS
end
print <<EOS
  <br>
  #{{ja: '週ごとの線 (80歳以上限定)', en: 'Weekly Lines (age 80+ only)'}[$l]}
EOS
Lines.each do |k, v|
    print <<EOS
   <span><input type="checkbox" name="lines" value="#{k}" #{v[:sel]}> #{v[$l]}</span>
EOS
end
print <<EOS
<br>
#{{ja: '接種回数', en: 'Doses'}[$l]}
EOS
Doses.each do |k, v|
    print <<EOS
   <span><input type="checkbox" name="doses" value="#{k}" #{v[:sel]}> #{v[$l]}</span>
EOS
end
Lang.each do |k, v|
    print <<EOS
   <input type="radio" name="l" value="#{k}" #{v[:sel]}> #{v[$l]}</span>
EOS
end
print <<EOS
   <input type="submit" value="送信/Submit">
  </form>
  <p class=c>
  <div id="vis"></div>
  <script>
    // Assign the specification to a local variable vlSpec.
    var vlSpec = {
      "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
      "data": {
EOS
print '        "values": '
puts JSON.pretty_generate($data.sort_by{|k, v| k}.map{|v| v[1]}).gsub(/\n/, "\n        ")

print <<EOS
      }
      ,
      "config": {
        "title": {"fontSize": 16},
        "axis": {"titleFontSize": 15, "labelFontSize": 15},
        "legend": {"titleFontSize": 15, "labelFontSize": 15}
      },
      "width": "container",
      "resolve": { "scale": { "color": "independent" } },
EOS
if ! Lines['rr0ci'][:sel]
    print <<EOS
      "params": [
        {
          "name": "highlight",
          "select": {"type": "point", "fields": ["dose"]},
          "bind": {"legend": "mouseover"}
        }
      ],
EOS
end
print <<EOS
      "vconcat": [
EOS
$firstflag = true

Cities.each do |code, city|
    next if ! city[:sel]

    $lives_all = add_commas($data["#{code}_week_W01_all_0"][:lives])
    $lives_80o = add_commas($data["#{code}_week_W01_80+_0"][:lives])

    Lines.each do |type, v|
        $logscale = ''
        next if ! v[:sel] || type =~ /rr0ci|rr0log/
        title = {ja: " 80歳以上の#{v[$l]}", en: ", #{v[$l]}, 80+"}[$l]
        title += {ja: " (解析人数 #{$lives_80o}/#{$lives_all}",
                  en: " (N=#{$lives_80o} from #{$lives_all}"}[$l]
        if type == 'mortality' || type == 'rr0'
            title += {ja: "、全死因、週ごと、10万人年死亡数)",
                      en: ", all causes, weekly, per 100,000 person-years)"}[$l]
            if type == 'rr0' && Lines['rr0log'][:sel]
                $logscale = '"scale": {"type": "log", "domain": [0.2, 5]}, '
            elsif type == 'mortality'
                if Doses['all'][:sel] || Doses['vaxx'][:sel]
                    $logscale = '"scale": {"domain": [0, 11000]}, ' # XXX
                else
                    $logscale = '"scale": {"domain": [0, 25000]}, ' # XXX
                end
            end
        elsif type == 'deaths'
            title += {ja: "、全死因、週ごと)",
                      en: ", all causes, weekly)"}[$l]
            type = 'deaths'
        elsif type == 'persondays' || type == 'lives'
            title += {ja: "、週ごと)",
                      en: ", weekly)"}[$l]
        else
            next
        end
        if $firstflag
            $firstflag = false
        else
            puts '        ,'
        end
        print <<EOS
        {
          "title": {
            "text": ["", "#{city[$l]}#{title}"],
            "anchor": "start"
          },
          "width": {"step": 11},
          "height": #{$height},
          "transform": [
            {"filter": "#{$filter_1st[:expr]}"},
            {"filter": "datum.areacode == '#{code}'"},
            {"filter": "datum.step == 'week'"},
            {"filter": "datum.age == '80+'"},
EOS
        if type == 'rr0'
            print <<EOS
            {"filter": "datum.dose != '0'"},
EOS
        end
        print <<EOS
            {"filter": "#{$filter_vaxx}"}
          ],
          "encoding": {
            "x": {
              "title": null,
              "field": "period",
              "type": "nominal",
              "axis": { "labelOverlap": "greedy" }
            },
             "y": {
              "title": null,
              "field": "#{type}",
              #{$logscale}
              "type": "quantitative"
            },
            "tooltip": {
              "field": "#{type}",
              "type": "quantitative"
            },
            #{$opacity}
            "color": {
              "field": "dose",
              "scale": {"scheme": "magma", "reverse": true},
              #{$legend}
              "title": "#{{ja: '接種回数', en: 'Dose'}[$l]}"
            }
          },
          "layer": [
            {"mark": {"type": "line", "clip": true}}
EOS
        if type == 'rr0' && Lines['rr0ci'][:sel]
            print <<EOS
            ,
            {
              "mark": {"type": "rule", "clip": true},
              "encoding": {
                "y": { "field": "lb0", #{$logscale} "type": "quantitative" },
                "y2": { "field": "ub0", #{$logscale} "type": "quantitative" }
              }
            }
EOS
        end
        print <<EOS
          ]
        }
EOS
    end
end
print <<EOS
      ]
    };
  vegaEmbed('#vis', vlSpec);
  </script>
  <hr>
  <p class=l>
EOS
if $l == :ja
    print <<EOS
  <ul>
   <li> 注意
   <ul>
     <li> 各市町村での市民の皆様による情報開示請求により得られたデータを解析しグラフを作成
     <li> 死亡率は人年法により、接種回数別の接種後の週ごとに計算している
     <li> 全市民の年齢区分と回数ごとの接種日と死亡している場合は死亡日の情報を利用
     <li> 非接種の場合も非接種であるという情報と死亡している場合は死亡日の情報を利用
     <li> 年齢区分はデータ開示時点のものであり誕生日を迎えての区分変更処理はされていない
     <li> 死者の年齢もデータ開示時点の年齢となっているので死亡時の年齢より高くなっている
     <li> 2021年2月〜2024年6月までの期間を対象とした
     <li> 期間内に転出した市民や接種歴に抜けがある市民は解析の対象から除外した
     <li> 解析人数は除外した後の人数
     <li> グラフのメニュー(…)から、「View Source」や「Open in Vega Editor」を選ぶことでJSON形式の解析結果データを取得可能
   </ul>
   <li><a href="https://fujikawa.org/pub/kkcor/ja" target="_blank">データセット</a>(上の自治体の完全なデータから作られたサブセット及び解析後のもの)
    <ul>
      <li>PY：人年データセット。</li>
      <li>IND-WKA：プライバシー保護のために週単位で匿名化された「個人別」記録を表す。このサフィックスは、個人別の行を含むファイルに使われ、正確な日付はISO週の最終日(日曜日)に置き換えられている。</li>
      <li>CUMD-WK, DTH-WKA: <a href="https://medicalfacts.info/kcor.rb">KCOR解析</a>を参照</li>
    </ul>
  </ul>
EOS
else
    print <<EOS
  <ul>
  <li> Note:
  <ul>
    <li> Graphs were created by analyzing data obtained through information disclosure requests made by residents to each municipality
    <li> Mortality rates are calculated by the person-year method weekly-after-dose for each number of vaccine doses
    <li> Information on age group and vaccination date by dose for all residents was used, along with the date of death (for residents who had died)
    <li> For unvaccinated individuals, information indicating non-vaccination and the date of death (for residents who had died) was used
    <li> Age categories are based on the data as of the time of disclosure and do not reflect changes due to individuals aging into a new category
    <li> The deceased's age is based on the data disclosure date and is thus older than at the time of death
    <li> The analysis covers the period from February 2021 to June 2024
    <li> Residents who moved out during the period or had discontinuous vaccination records were excluded from the analysis
    <li> The number of analyzed individuals is after these exclusions
  </ul>
   <li><a href="https://fujikawa.org/pub/kkcor/" target="_blank">Datasets</a> derived from complete ones from the above cities</li>
   <ul>
     <li>PY: Person-year datasets.
     <li>IND-WKA: Represents "Individual" records with week anonymization for privacy. This suffix is used for files containing per-record (individual-level) data, where exact dates are replaced with the Sunday (last day of the ISO week).
     <li>CUMD-WK and DTH-WKA: See <a href="https://medicalfacts.info/kcor.rb">KCOR analysis</a>
   </ul>
  </ul>
EOS
end
print <<EOS
  </div>
  </div>
</body>
EOS
