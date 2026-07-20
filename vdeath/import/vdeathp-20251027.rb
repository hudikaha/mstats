#!/usr/bin/ruby
# coding: utf-8

require 'optparse'
require 'csv'
require 'pp'
require 'date'
require './debug.rb'

$opts = {
    debug: false,
    start: Date.parse('2021-02-01'),
    until: Date.parse('2024-07-01'),
    step: 0,
    header: nil,
    d1dn: false,
    allow_dup_id: false,
    prohibit_reason_in: false,
    shift: nil,
    norm: nil,
    kcor: nil,
    steps: [],
    ages: [],
    pyear: nil,
    excess: nil,
}

$dose_last = 7

op = OptionParser.new do |opts|
    opts.banner = "Usage: vdeathp.rb [options] 都道府県市町村-年齢区分.csv"
    opts.on('--debug yes|no', String, 'Debug on') do |val|
        if val =~ /true|yes|on/
            $opts[:debug] = true
            Log.level = Logger::DEBUG
        end
    end
    opts.on('--start date', String, '開始日') do |val|
        $opts[:start] = Date.parse(val)
    end
    opts.on('--until date', String, '終了日(の次の日を指定)') do |val|
        $opts[:until] = Date.parse(val)
    end
    opts.on('--allow-dup-id yes|no', String, 'IDの重複を1回だけ許可(豊川用)') do |val|
        $opts[:allow_dup_id] = true if val =~ /true|yes|on/
    end
    opts.on('--prohibit-reason-in yes|no', String, '転入が理由になってる転出理由を除外(小金井)、転入届けなどは無関係') do |val|
        $opts[:prohibit_reason_in] = true if val =~ /true|yes|on/
    end
    opts.on('--header header_CSV1,header_CSV2,...', Array, 'ヘッダCSV') do |val|
        $opts[:header] = val
    end
    opts.on('--step day|week|1|2|3...', String, '期間。day/week 以外の数値は月数') do |val|
        $opts[:step] = val.to_i > 0 ? val.to_i : val
    end
    opts.on('--d1dn yes|no', String, '1回目とn回目までの比較') do |val|
        $opts[:d1dn] = true if val =~ /true|yes|on/
        #$dose_last = 2
    end
    opts.on('--norm <normalize CSV file>', String, '標準化') do |val|
        $opts[:norm] = val
    end
    opts.on('--shift <Nth dose>', String, 'この回数目の接種者の日付を初日とする') do |val|
        num = val.to_i
        $opts[:shift] = num if 1 <= num && num <= 7
        #$dose_last = 2
    end
    opts.on('--kcor <KCOR-style file>', String, 'KCOR形式で出力') do |val|
        $opts[:kcor] = val
    end
    opts.on('--steps step1,step2,...', Array, '何ヶ月ごとか。例) --steps 1,6,all') do |val|
        $opts[:steps] = val
    end
    opts.on('--ages age1,age2,...', Array, '年齢。例) --steps 80+,all') do |val|
        $opts[:ages] = val
    end
    opts.on('--pyear <Pyear-style file>', String, 'Person-year形式で出力') do |val|
        $opts[:pyear] = val
    end
    opts.on('--excess <Excess death file>', String, '超過死亡形式で出力') do |val|
        $opts[:excess] = val
    end
end
begin
    op.parse!
    if ARGV.empty?
        STDERR.puts "Error: ARG is required.\n\n#{op}"
        exit 1
    end
rescue OptionParser::ParseError => e
    STDERR.puts "Error: #{e.message}\n\n#{op}"
    exit 1
end

$indivs = Hash.new
$garbage = Hash.new
$latest = $opts[:start]
$removed = 0
$out_skip = 0
$date_dose_first = Date.parse('2026-01-01') # XXX
$date_dose_last = Date.parse('2021-01-01')
$date_death_last = Date.parse('2021-01-01')
$date_shift = 0


ARGV.each_with_index do |arg, i|

    buf = ''
    if $opts[:header]
        header = $opts[:header].count == 1 ? $opts[:header][0] : $opts[:header][i]
        buf += File.read(header).gsub(/\r\n?/, "\n")
    end
    Log.info "+++++++++++++++++++++++++++++++++++++++++++ #{header} + #{arg}"
    buf += File.read(arg).sub("\uFEFF", "").gsub(/\r\n?/, "\n").gsub('～', '〜')

    id = 0 # temporary
    CSV.parse(buf, headers: true, force_quotes: true, row_sep: :auto).each do |row|

        if row.key?('id')
            next if row['id'] !~ /^\d+$/
            id = row['id'].to_i
        else
            next if row['age'] !~ /^\d+/
            id += 1
        end

        indiv = {
            age: row['age'],
            agestr: row['age'],
            sex: row['sex'],
            final: nil,
            date_death: nil,
            age_death: nil,
            date_in: nil,
            date_out: nil,
            pdays: {},
            doses: {},
        }
        if $opts[:norm] || $opts[:kcor] || $opts[:ages]
            indiv[:age] = indiv[:age].to_i
        end

        row['death'] = nil if row['death'] =~ /^NA$/
        # 死亡日を調べる
        if row['death']
            indiv[:date_death] = Date.parse(row['death'])
        elsif row['out'] && row['reason_out'] =~ /死/
            begin
                indiv[:date_death] = Date.parse(row['out'])
            rescue
                Log.error PP.pp(row)
                next
            end
        end

        if row['reason_out'] =~ /転入/
            begin
                indiv[:date_in] = Date.parse(row['out'])
            rescue
                Log.error PP.pp(row)
                next
            end
        end

        if row['reason_out'] =~ /転出/
            begin
                indiv[:date_out] = Date.parse(row['out'])
            rescue
                Log.error PP.pp(row)
                next
            end
        end

        if indiv[:date_death]
            $date_death_last = ($date_death_last > indiv[:date_death]) ?
                                   $date_death_last : indiv[:date_death]
        end

        # 小金井市は理由が転入になってる場合あるので、日付を消しておく
        # 他の市にも適用した方がよい可能性があるので、後で調査
        if $opts[:prohibit_reason_in] &&
           row['out'] && row['reason_out'] =~ /^転入$/
            Log.debug "転入? 転出? in? out?"
            Log.debug PP.pp(row.to_h, '')
            row['out'] = nil
        end

        # 死亡してない場合だけ、転出を調べる
        date_out = nil
        if ! indiv[:date_death]
            ['out', 'out2', 'out3', 'out4', 'out5'].each do |out|
                if row[out]
                    date_out = Date.parse(row[out])
                    break if date_out < $opts[:until] # やめる理由になるから
                end
            end
        end

        # 観察期間開始前に死亡はスキップ
        if indiv[:date_death] && indiv[:date_death] < $opts[:start]
            $out_skip += 1
            Log.debug "+++++++++++ #{id} 死亡日 #{indiv[:date_death]} skip #{$out_skip}"
            $garbage[id] = indiv
            next
        end
        # 観察期間終了までに転出はスキップ
        if date_out && date_out < $opts[:until]
            $out_skip += 1
            Log.debug "+++++++++++ #{id} 転出 #{date_out} skip #{$out_skip}"
            $garbage[id] = indiv
            next
        end

        if $indivs[id] # 豊川は生者と死者で分れていたファイルを結合したのでIDが重複
            if ! $opts[:allow_dup_id]
                Log.error PP.pp($indivs[id], '')
                Log.error PP.pp(row.to_h, '')
                Log.error "!!!!!!!!!!!!!!!!!!!!!!! DUPLICATED ID #{id}"
                exit
            end
            if id <= 10000000
                id += 10000000
            else
                Log.error PP.pp($indivs[id], '')
                Log.error PP.pp(row.to_h, '')
                Log.error "!!!!!!!!!!!!!!!!!!!!!!! TRIPLICATED ID #{id}"
                exit
            end
        end
        (1..$dose_last).each do |i|
            if ! row["dose#{i}"] ||
               row["dose#{i}"] == '#N/A' ||
               row["dose#{i}"] == 'NA' ||
               row["dose#{i}"] == '0' # 小金井市
                next
            end
            doses = indiv[:doses]
            begin
                doses[i] = {
                    date: Date.parse(row["dose#{i}"]),
                    lot: row["lot#{i}"],
                    pharma: row["pharma#{i}"],
                }
            rescue
                str = "dose#{i}"
                Log.error PP.pp(row.to_h, '')
                Log.error "読めない #{row[str]}"
                exit
            end
            $date_dose_last =  doses[i][:date] if doses[i][:date] > $date_dose_last
            $date_dose_first = doses[i][:date] if doses[i][:date] < $date_dose_first
        end

        # NEW check
        if indiv[:doses].keys != []
            nextflag = false
            dose_prev = 0
            #date_prev = $opts[:start] - 1 XXX 間違い
            date_prev = Date.parse('2021-02-01') - 1
            indiv[:doses].each do |dose, v|
                if dose != dose_prev + 1
                    $removed += 1
                    Log.debug "+++++++++++ REMOVE #{id} #{$removed} #{dose} != #{dose_prev}+1"
                    $garbage[id] = indiv
                    nextflag = true
                    break
                end
                if v[:date] <= date_prev
                    $removed += 1
                    Log.debug "+++++++++++ REMOVE #{id} #{$removed} #{v[:date]}<=#{date_prev}"
                    $garbage[id] = indiv
                    nextflag = true
                    break
                end
                dose_prev = dose
                date_prev = v[:date]
            end
            next if nextflag
        end

        if false
        dosestr = ''
        (1..$dose_last).each do |i|
            dosestr += indiv[:doses][i] ? 'X' : '_'
        end
        #puts dosestr
        if dosestr =~ /_.*X/
            $removed += 1
            Log.debug "+++++++++++ REMOVE #{id} #{$removed} #{dosestr}"
            next
        end
        end

        indiv[:final] = indiv[:doses].count
        if indiv[:date_death]
            $latest = $latest > indiv[:date_death] ? $latest : indiv[:date_death]
        end

        indiv[:age_death] = row['age_death'] if row['age_death']

        $indivs[id] = indiv
    end
end
Log.info "++++++++++++++++++++ Total #{$indivs.count}, Garbage #{$garbage.count}"
Log.info "++++++++++++++++++++ Date dose first #{$date_dose_first} #{$date_shift_0}"
Log.info "++++++++++++++++++++ Date dose last  #{$date_dose_last}"
Log.info "++++++++++++++++++++ Date death last #{$date_death_last}"
if $opts[:shift]
    $date_shift_0 = ($date_dose_first - Date.parse('2021-02-01')).to_i
    $indivs.each do |id, indiv|
        date_shift = $date_shift_0
        if indiv[:doses][$opts[:shift]]
            date_shift = indiv[:doses][$opts[:shift]][:date] - Date.parse('2021-02-01')
            indiv[:doses].each do |k, v|
                v[:date] -= date_shift
            end
        end
        indiv[:date_death] -= date_shift if indiv[:date_death]
    end
end

if $opts[:debug]
    indivs2 = $indivs.select{|k, v| v[:age_death] && v[:age]}
    indivs3 = indivs2.select{|k, v| v[:age_death] != v[:age]}
    Log.debug "++++++++++++++++++++ Different ages: #{indivs3.count}/#{indivs2.count}"
    indivs3.each do |id, indiv|
        Log.debug "++++++++++++++++++++ Different ages: #{id} #{indiv[:age_death]} #{indiv[:age]}"
    end
end

($areacode, $areaname, $agestr) = [nil, nil, ""]

ARGV.each do |arg|
    (c, n, a) = arg.sub(/^.*\//, '').match(/(.+)_(.+)_(.+)\.csv/).captures
    $areacode = c if ! $areacode
    if $areacode != c
        Log.erro("Files include different areacoes #{areacode} #{c}")
        exit
    end
    $areaname = n if ! $areaname
    if $areaname != n
        Log.erro("Files include different areanames #{areaname} #{c}")
        exit
    end
    $area_j, $area_e = $areaname.split('-', 2)
    $area_e = $area_e.gsub('-', '/')
    if $agestr == ''
        $agestr += "#{a}"
    else
        $agestr += ":#{a}"
    end
    if $agestr =~ /(\d+)-(\d+):(\d+)\+/
        $agestr = "#{$1}+" if $2.to_i + 1 == $3.to_i
    elsif $agestr =~ /(\d+)-(\d+):(\d+)-(\d+)/ && $2.to_i + 1 == $3.to_i
        $agestr = "#{$1}-#{$4}"
    end
end

if $opts[:d1dn]
    $day_step = 1
    template = {
        indivs: nil,
    }
    (1..1).each do |base| # base dose
        template["d#{base}all".to_sym] = 0
        template["l#{base}all".to_sym] = 0
        (1..$dose_last).each do |dose|
            template["d#{base}to#{dose}".to_sym] = 0
            template["l#{base}to#{dose}".to_sym] = 0
        end
        $dist = Array.new
        $indivs.each do |id, indiv|
            next if ! indiv[:doses][1]
            if indiv[:date_death]
                days = (indiv[:date_death] - indiv[:doses][base][:date]).to_i
                $dist[days] = template.dup if ! $dist[days]
                $dist[days]["d#{base}all".to_sym] += 1
                $dist[days]["d#{base}to#{indiv[:final]}".to_sym] += 1
            end
            (0..400).each do |days2|
                if ! indiv[:date_death] || days2 < days
                    $dist[days2] = template.dup if ! $dist[days2]
                    $dist[days2]["l#{base}all".to_sym] += 1
                    if indiv[:doses][2]
                        days3 = (indiv[:doses][2][:date] - indiv[:doses][1][:date]).to_i
                        if days2 < days3
                            $dist[days2]["l#{base}to1".to_sym] += 1
                        else
                            $dist[days2]["l#{base}to2".to_sym] += 1
                            if days2 == 0
                                Log.error "Error"
                                Log.error PP.pp(id, '')
                                Log.error PP.pp(indiv, '')
                                exit
                            end
                        end
                    else
                        $dist[days2]["l#{base}to1".to_sym] += 1
                    end
                end
            end
            Log.debug "id:#{id} days:#{days} dose1:#{indiv[:doses][1][:date]} dose2:#{indiv[:doses][2] ? indiv[:doses][2][:date] : 'not_recv'} death:#{indiv[:date_death]}" if days
        end
    end

    #puts "日後,死亡数,1回接種死亡数,2回接種死亡数,生者,1回接種生者,2回接種生者"
    puts "doc_id,areacode,area,areaj,step,yearmonth,age,dose,deaths,persondays,mortality,lives"

    (0..400).each do |i|
        Log.debug "#{i}:"
        Log.debug PP.pp($dist[i], '')
        #puts "#{i},#{$dist[i][:d1all]},#{$dist[i][:d1to1]},#{$dist[i][:d1to2]},#{$dist[i][:l1all]},#{$dist[i][:l1to1]},#{$dist[i][:l1to2]}"

        doc_id = "#{$areacode}_#{$opts[:step]}_#{i}_#{$agestr}_1all"
        mort = $dist[i][:l1all] > 0 ?
                   ($dist[i][:d1all]*100000*365/$dist[i][:l1all]).round(2) : 0
        puts "#{doc_id},#{$areacode},#{$area_e},#{$area_j},#{$opts[:step]},#{i},#{$agestr},1all,#{$dist[i][:d1all]},#{$dist[i][:l1all]},#{mort},#{$dist[i][:l1all]}"

        doc_id = "#{$areacode}_#{$opts[:step]}_#{i}_#{$agestr}_1to1"
        mort = $dist[i][:l1to1] > 0 ?
                   ($dist[i][:d1to1]*100000*365/$dist[i][:l1to1]).round(2) : 0
        puts "#{doc_id},#{$areacode},#{$area_e},#{$area_j},#{$opts[:step]},#{i},#{$agestr},1to1,#{$dist[i][:d1to1]},#{$dist[i][:l1to1]},#{mort},#{$dist[i][:l1to1]}"

        doc_id = "#{$areacode}_#{$opts[:step]}_#{i}_#{$agestr}_1to2"
        mort = $dist[i][:l1to2] > 0 ?
                   ($dist[i][:d1to2]*100000*365/$dist[i][:l1to2]).round(2) : 0
        puts "#{doc_id},#{$areacode},#{$area_e},#{$area_j},#{$opts[:step]},#{i},#{$agestr},1to2,#{$dist[i][:d1to2]},#{$dist[i][:l1to2]},#{mort},#{$dist[i][:l1to2]}"
    end

    $avg = {
        death_00_20: ($dist[00..20].map{|a| a[:d1all]}.sum.to_f/$dist[00..20].count).round(2),
        death_21_41: ($dist[21..41].map{|a| a[:d1all]}.sum.to_f/$dist[21..41].count).round(2),
    }
    $avg[:ratio] = ($avg[:death_21_41]/$avg[:death_00_20]).round(2)
    Log.info "avg: #{$avg}"

    $py_t = {
        death_00_20: ($dist[00..20].map{|a| a[:d1all]}.sum.to_f * 365 * 100000/
                      $dist[00..20].map{|a| a[:l1all]}.sum).round(2),
        death_21_41: ($dist[21..41].map{|a| a[:d1all]}.sum.to_f * 365 * 100000/
                      $dist[21..41].map{|a| a[:l1all]}.sum).round(2),
    }
    $py_t[:ratio] = ($py_t[:death_21_41]/$py_t[:death_00_20]).round(2)
    Log.info "py_t: #{$py_t}"

    $py_1 = {
        death_00_20: ($dist[00..20].map{|a| a[:d1to1]}.sum.to_f * 365 * 100000/
                      $dist[00..20].map{|a| a[:l1to1]}.sum).round(2),
        death_21_41: ($dist[21..41].map{|a| a[:d1to1]}.sum.to_f * 365 * 100000/
                      $dist[21..41].map{|a| a[:l1to1]}.sum).round(2),
    }
    $py_1[:ratio] = ($py_1[:death_21_41]/$py_t[:death_00_20]).round(2)
    Log.info "py_1: #{$py_1}"

    $py_2 = {
        death_00_20: ($dist[00..20].map{|a| a[:d1to2]}.sum.to_f * 365 * 100000/
                      $dist[00..20].map{|a| a[:l1to2]}.sum).round(2),
        death_21_41: ($dist[21..41].map{|a| a[:d1to2]}.sum.to_f * 365 * 100000/
                      $dist[21..41].map{|a| a[:l1to2]}.sum).round(2),
    }
    $py_2[:ratio] = ($py_2[:death_21_41]/$py_t[:death_00_20]).round(2)
    Log.info "py_2: #{$py_2}"

	# 10万人年死亡数
	# 全体	1回接種	2回接種
	# 0〜20日後	410.78	410.96	0.00
	# 21〜41日後	780.43	4505.88	497.03
	# 倍率	1.90	10.96	#DIV/0!

    if false
    print <<EOS
#,,,,,,
#,,,,10万人年死亡数,,,
#,,,全体,1回接種,2回接種
#,,0〜20日後,=SUM($B$2:$B$22)*100000*365/SUM($E$2:$E$22),=SUM($C$2:$C$22)*100000*365/SUM($F$2:$F$22),
#,,21〜41日後,=SUM($B$23:$B$43)*100000*365/SUM($E$23:$E$43),=SUM($C$23:$C$43)*100000*365/SUM($F$23:$F$43),=SUM($D$23:$D$43)*365*100000/SUM($G$23:$G$43)
#,,倍率(0〜20日後の全体に対する),=D48/D47,=E48/D47,=F48/D47,
EOS
    end
    exit
end

#
# KCOR
#
$date_death_last_sun = $date_death_last.cwday == 7 ? $date_death_last :
                           Date.commercial($date_death_last.year, $date_death_last.cweek, 7)
AGE_START = 0
$opts[:kcor] && File.open($opts[:kcor], 'w') do |kcor|
    $indivs_death = $indivs.select{|k, v| v[:date_death]}
    kcor.puts "id,areacode,area,areaj,cutoff,cweek,date,age,dose,deaths"

    start_month = Date.new(2021, 6, 1)   # 開始（含む）
    end_month   = Date.new(2024, 5, 1)   # 終了（含む）
    d = start_month
    while d <= end_month
        first   = Date.new(d.year, d.month, 1)                  # その月の1日
        cutoff  = Date.commercial(first.cwyear, first.cweek, 7) # ← そのISO週の日曜がcutoff

        #kcor.puts cutoff.strftime('%Y-%m-%d')
        AGE_START.step(100, 10) do |age|
            agestr = (age == 100) ? '100+' : sprintf('%02d-%02d', age, age+9)
            age2 = (age == 100) ? 200 : age + 9
            indivs_age = $indivs_death.select{|k, v| age <= v[:age] && v[:age] <= age2}
            indivs_age != {} && (0..$dose_last).each do |i|
                cohort = Hash.new
                if i == 0
                    cohort = indivs_age.
                                 select{|k, v| ! v[:doses][1] || v[:doses][1][:date] > cutoff}
                else
                    cohort = indivs_age.
                                 select{|k, v|
                                        (v[:doses][i] && v[:doses][i][:date] <= cutoff) &&
                                        (!v[:doses][i+1] || v[:doses][i+1][:date] > cutoff)}
                end
                date = cutoff + 7
                #while date.year < 2024 || (date.year == 2024 && date.month <= 5)
                while date <= $date_death_last_sun
                    deaths = cohort.select{|k, v| v[:date_death] &&
                                           cutoff < v[:date_death] && v[:date_death] <= date}
                    if deaths != {}
                        cweek = "#{date.cwyear}-W#{'%02d'%date.cweek}"
                        doc_id = "#{$areacode}_#{cutoff}_#{cweek}_#{agestr}_#{i}"
                        kcor.puts "#{doc_id},#{$areacode},#{$area_e},#{$area_j},#{cutoff},#{cweek},#{date},#{agestr},#{i},#{deaths.count}"
                    end
                    date += 7
                end
            end
        end
        d = d.next_month
    end
end

#
# NORMALIZATION
#
$opts[:norm] && File.open($opts[:norm], 'w') do |norm|
    norm.puts "id,areacode,area,areaj,age,date_age,cweek_death,date_death,dose_final,cweek_dose1,date_dose1,pharma_dose1,cweek_dose2,date_dose2,pharma_dose2,cweek_dose3,date_dose3,pharma_dose3,cweek_dose4,date_dose4,pharma_dose4,cweek_dose5,date_dose5,pharma_dose5,cweek_dose6,date_dose6,pharma_dose6,cweek_dose7,date_dose7,pharma_dose7,cweek_dose8,date_dose8,pharma_dose8,cweek_dose9,date_dose9,pharma_dose9"
    AGE_START.step(100, 10) do |age|
        indivs2 = $indivs.select{|k,v| (age <= v[:age] && v[:age] <= age + 9) ||
                                 (age >= 100 && v[:age] >= 100) }
        indivs2.each do |id, indiv|
            agestr = (age >= 100) ? '100+' : '%02d-%02d'%[age, age+9]
            doc_id = "#{$areacode}_#{agestr}_#{'%08d'%id.to_i}"
            date_age = [$date_dose_last, $date_death_last].max
            date_death = indiv[:date_death]
            cweek_death = date_death ?
                              "#{date_death.cwyear}-W#{'%02d'%date_death.cweek}" : nil
            if cweek_death
                date_death = Date.commercial(date_death.cwyear, date_death.cweek, 7)
            end
            norm.print "#{doc_id},#{$areacode},#{$area_e},#{$area_j},#{agestr},#{date_age},#{cweek_death},#{date_death},#{indiv[:final]}"
            indiv[:doses] != {} && (1..$dose_last).each do |k|
                break if ! indiv[:doses][k]
                date_dose = indiv[:doses][k][:date]
                cweek_dose = "#{date_dose.cwyear}-W#{'%02d'%date_dose.cweek}"
                if cweek_dose
                    date_dose = Date.commercial(date_dose.cwyear, date_dose.cweek, 7)
                end
                pharma = indiv[:doses][k][:pharma]
                if ! pharma || pharma == ''
                    pharma = ''
                elsif pharma =~ /pfizer|ファイザー|コミナティ/
                    pharma = 'pfizer'
                elsif pharma =~ /moderna|モデルナ|スパイクバックス/
                    pharma = 'moderna'
                elsif pharma =~ /astrazeneca|アストラゼネカ/
                    pharma = 'astrazeneca'
                elsif pharma =~ /daiichisankyo|第一三共|ダイチロナ/
                    pharma = 'daiichisankyo'
                elsif pharma =~ /ノババックス/
                    pharma = 'takeda'
                elsif pharma =~ /meiji|明治/
                    pharma = 'meiji'
                else
                    Log.error "製薬会社不明 #{pharma}"
                    exit
                end
                norm.print ",#{cweek_dose},#{date_dose},#{pharma}"
            end
            norm.puts
            #if indiv[:doses] != {} && indiv[:date_death]
            #    pp id, indiv
            #    exit
            #end
        end
    end
end

START = Date.parse('2021-02-01')
#LAST = Date.parse('2024-07-01')
LAST = Date.parse('2026-01-01')

# リスク比と信頼区間を従来方式で計算する。
# Calculate a risk ratio and confidence interval using the legacy method.
def rr_with_ci_org(events_i, total_i, events_c, total_c)
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

# リスク比、信頼区間、p値を計算する。
# Calculate a risk ratio, confidence interval, and p-value.
def rr_with_ci(events_i, total_i, events_c, total_c)
  # mort: 10万人年あたり死亡率（整数のまま計算）
  if total_i == 0
    mort = lbm = ubm = '-'
  else
    py = total_i / 365.0  # 人年
    rate = events_i / py  # 人年あたり死亡率
    mort = rate * 100_000

    if events_i == 0
      lbm = 0
      ubm = -Math.log(0.05) / py * 100_000  # 上限のみ
    else
      se = Math.sqrt(events_i) / py
      lbm = (rate - 1.96 * se) * 100_000
      ubm = (rate + 1.96 * se) * 100_000
    end

    mort = mort.round(2)
    lbm = lbm.round(2)
    ubm = ubm.round(2)
  end

  ei = events_i.to_f
  ni = total_i.to_f
  ec = events_c.to_f
  nc = total_c.to_f

  return ['-', '-', '-', lbm, ubm, mort] if ni.zero? || nc.zero?

  p1 = ei / ni
  p2 = ec / nc
  return ['-', '-', '-', lbm, ubm, mort] if p2.zero?

  rr0 = (p1 / p2).round(4)
  if ei.zero? || ec.zero?
    return [rr0, '-', '-', lbm, ubm, mort]
  end

  se_log_rr = Math.sqrt((1/ei - 1/ni) + (1/ec - 1/nc))
  lb0 = Math.exp(Math.log(rr0) - 1.96 * se_log_rr).round(4)
  ub0 = Math.exp(Math.log(rr0) + 1.96 * se_log_rr).round(4)

  [rr0, lb0, ub0, lbm, ubm, mort]
end

UNVAX_REF_START = Date.new(2021, 2, 1)

# 改良点:
# 1) week-after-dose: 各 dose のリスク集合を厳密化
#    - dose0: [UNVAX_REF_START, first_dose or death or LAST)
#    - doseN: [doseN_date, next_dose or death or LAST)
# 2) 死亡の所属判定を「区間終端を含む」(<=) に変更
#    - 未接種:  death <= end0 かつ 週窓に入る
#    - 接種群:  death <= oend かつ 週窓に入る
# 3) week-after-dose: 未接種も週ごとに集計＆出力（RR の参照に使用）
# 4) 通常モード: end_limit の採否判定に 10% マージン（日）を適用（出力期間は変えない）
# 5) 外部 step 表記は 'week-after-dose'（ハイフン）。CSV の step は 'week' 出力で統一
# 個票から年齢・接種後期間別の人年と死亡を集計する。
# Aggregate person-years and deaths by age and time since vaccination.
def pyear(fd, agestr, indivs, step, start_date, end_limit)
  # --- step 正規化（外部は 'week-after-dose' を推奨） ---
  mode     = step.is_a?(Symbol) ? step.to_s.tr('_', '-') : step.to_s
  intstep  = step.is_a?(Integer) ? step : (Integer(step) rescue nil)
  csv_step = (mode == 'week-after-dose' ? 'week' : mode)

  # --- 共通ヘルパ ---
  emit_line = lambda do |fd_, tag, lives, days, deaths, base_days, base_deaths|
    rr0, lb0, ub0, lbm, ubm, mort = rr_with_ci(deaths, days, base_deaths, base_days)
    fd_.puts "#{tag},#{$areacode},#{$area_e},#{$area_j},#{csv_step},#{$periodstr},#{agestr},#{@dose_or_key},#{lives},#{days},#{deaths},#{lb0},#{ub0},#{rr0},#{lbm},#{ubm},#{mort}"
  end

  reset_status_for_debug = -> { indivs.each { |_, indiv| indiv[:status] = nil if indiv[:status] != 'Died' } }

  # dose n の観測可能範囲（接種日〜次接種/死亡/LAST）を返す
  obs_range_for = lambda do |indiv, dose|
    return nil unless indiv[:doses][dose]
    ddate   = indiv[:doses][dose][:date]
    nxtdose = indiv[:doses][dose + 1] && indiv[:doses][dose + 1][:date]
    deatht  = (indiv[:final] == dose) ? indiv[:date_death] : nil
    oend    = [nxtdose, deatht, LAST].compact.min
    (ddate < oend) ? [ddate, oend] : nil
  end

  overlap_days = ->(a_s, a_e, b_s, b_e) {
    s = [a_s, b_s].max
    e = [a_e, b_e].min
    d = (e - s).to_i
    d > 0 ? d : 0
  }

  # 未接種ベースライン（UNVAX_REF_START〜）
  compute_unvax_baseline = lambda do
    unless defined?(UNVAX_REF_START) && UNVAX_REF_START.is_a?(Date)
      Log.error "UNVAX_REF_START must be defined as Date"; exit
    end
    days0 = 0; deaths0 = 0
    indivs.each_value do |ind|
      first = ind[:doses][1] && ind[:doses][1][:date]
      end0  = [first, (ind[:final] == 0 ? ind[:date_death] : nil), LAST].compact.min
      next unless end0 && UNVAX_REF_START < end0
      days0 += (end0 - UNVAX_REF_START).to_i
      if ind[:final] == 0 && ind[:date_death] && UNVAX_REF_START <= ind[:date_death] && ind[:date_death] < end0
        deaths0 += 1
      end
    end
    [$days0 = days0, $deaths0 = deaths0]
  end

  # end_limit 判定用 10% マージン（日）※通常モードのみ使用
  margin_days_for = lambda do |mode_s, int_s|
    case mode_s
    when 'week' then 0
    when '0', 0 then 18                 # step0 は step6 相当
    else
      int_s && int_s > 0 ? (int_s * 3) : 0  # 30日/月 * int_s * 0.1 ≒ int_s*3
    end
  end

  # 通常期間イテレータ（週／単発／整数月）
  each_period = lambda do |mode_s, int_s, sdate, limit, &blk|
    cur = sdate
    first = true
    margin = margin_days_for.call(mode_s, int_s)
    loop do
      break if cur > $latest
      case mode_s
      when 'week'
        iso_s = cur - (cur.cwday - 1)
        nxt   = iso_s + 7
        break if nxt > (limit + margin)
        $pdaystr   = format('%04d-W%02d', iso_s.cwyear, iso_s.cweek)
        $periodstr = $pdaystr
        blk.call(iso_s, nxt)
        cur = nxt
      when '0', 0
        s = cur; e = limit
        break if s >= (limit + margin)
        $pdaystr   = "#{s.to_s.sub(/-\d\d$/, '')}〜#{(e - 1).to_s.sub(/-\d\d$/, '')}"
        $periodstr = "#{s}--#{e - 1}"
        blk.call(s, e)
        break
      else
        raise "invalid step" unless int_s && int_s > 0
        s = cur
        e =
          if first && ((s.month - 1) % int_s != 0)
            idx = ((s.month - 1) / int_s) + 1
            anchor_month = idx * int_s + 1
            y = s.year + (anchor_month > 12 ? 1 : 0)
            m = ((anchor_month - 1) % 12) + 1
            begin
              Date.new(y, m, s.day)
            rescue
              Date.new(y, m, 1).next_month(1) - 1
            end
          else
            begin
              s.next_month(int_s)
            rescue
              (Date.new(s.year, s.month, 1).next_month(int_s + 1) - 1)
            end
          end
        break if e > (limit + margin)
        $pdaystr   = (int_s == 1) ? s.to_s.sub(/-\d\d$/, '') :
                      "#{s.to_s.sub(/-\d\d$/, '')}〜#{(e - 1).to_s.sub(/-\d\d$/, '')}"
        $periodstr = format('%04dm%02d', s.year, s.month)
        blk.call(s, e)
        cur = e
        first = false
      end
      break if cur > (limit + margin)
    end
  end

  # week-after-dose 用：週番号イテレータ（1..K）
  each_week_after_dose = lambda do |k_start, k_last, &blk|
    (k_start..k_last).each do |wk|
      $periodstr = format('W%02d', wk)
      blk.call(wk)
    end
  end

  # =========================================================
  # A) week-after-dose モード（未接種も集計＆RR参照）
  # =========================================================
  if mode == 'week-after-dose'
    compute_unvax_baseline.call
    reset_status_for_debug.call

    each_week_after_dose.call(start_date, end_limit) do |wk|
      sum = Hash.new { |h, k| h[k] = { lives: 0, days: 0, deaths: 0 } }

      (0..$dose_last).each do |dose|
        indivs.each_value do |ind|
          if dose == 0
            # dose0 リスク区間: [UNVAX_REF_START, first_dose or death or LAST)
            ws = UNVAX_REF_START + 7 * (wk - 1)
            we = UNVAX_REF_START + 7 * wk

            u0_s = UNVAX_REF_START
            first = ind[:doses][1] && ind[:doses][1][:date]
            u0_e  = [first, ind[:date_death], LAST].compact.min

            pd = overlap_days.call(u0_s, u0_e, ws, we)
            next if pd <= 0

            sum[0][:days]  += pd
            sum[0][:lives] += 1

            # ★死亡は「区間終端を含む」かつ「週窓に入る」
            if ind[:date_death] && ind[:date_death] <= u0_e && ws <= ind[:date_death] && ind[:date_death] < we
              sum[0][:deaths] += 1
            end

          else
            # dose n リスク区間: [dose_n_date, next_dose or death or LAST)
            r = obs_range_for.call(ind, dose)
            next unless r
            ddate, oend = r

            ws = ddate + 7 * (wk - 1)
            we = ddate + 7 * wk
            next unless (ddate < we) && (ws < oend)

            pd = overlap_days.call(ddate, oend, ws, we)
            next if pd <= 0

            sum[dose][:days]  += pd
            sum[dose][:lives] += 1

            # ★死亡は「区間終端を含む」かつ「週窓に入る」
            if ind[:date_death] && ind[:date_death] <= oend && ws <= ind[:date_death] && ind[:date_death] < we
              sum[dose][:deaths] += 1
            end
          end
        end
      end

      # 参照群（dose0）で RR
      ref_days   = sum[0][:days]
      ref_deaths = sum[0][:deaths]

      # 各 dose 出力
      sum.keys.sort.each do |d|
        s = sum[d]; @dose_or_key = d
        tag = "#{$areacode}_#{csv_step}_#{$periodstr}_#{agestr}_#{d}"
        emit_line.call(fd, tag, s[:lives], s[:days], s[:deaths], ref_days, ref_deaths)
      end

      # vaxx/all まとめ
      vaxx = sum.select { |d,_| d > 0 }.values
      allv = sum.values
      { vaxx: vaxx, all: allv }.each do |key, arr|
        lives  = arr.sum { |h| h[:lives] }
        days   = arr.sum { |h| h[:days] }
        deaths = arr.sum { |h| h[:deaths] }
        @dose_or_key = key
        tag = "#{$areacode}_#{csv_step}_#{$periodstr}_#{agestr}_#{key}"
        emit_line.call(fd, tag, lives, days, deaths, ref_days, ref_deaths)
      end
    end
    return
  end

  # =========================================================
  # B) 通常モード（週／月／単発）
  # =========================================================
  each_period.call(mode, intstep, start_date, end_limit) do |ws, we|
    next if ws >= we
    reset_status_for_debug.call

    # 個体×dose の人日
    indivs.each do |_, ind|
      ind[:pdays] = {}
      (0..$dose_last).each do |dose|
        st = en = nil
        if dose == 0
          st = ws
          en = if ind[:final] == 0 && ind[:date_death]
                 ind[:date_death]
               elsif ind[:doses][1]
                 ind[:doses][1][:date]
               else
                 we
               end
        elsif ind[:doses][dose]
          st = ind[:doses][dose][:date]
          en = if ind[:final] == dose
                 ind[:date_death] || we
               elsif ind[:doses][dose + 1]
                 ind[:doses][dose + 1][:date]
               else
                 we
               end
        else
          next
        end
        next unless (st < en) && (ws < en) && (st < we)
        st = ws if st < ws
        en = we if we < en
        days = (en - st).to_i
        next if days <= 0
        ind[:pdays][dose] = days
      end
      ind[:doses] = ind[:doses].sort.to_h
    end

    # 集計
    sum = Hash.new { |h, k| h[k] = { lives: 0, days: 0, deaths: 0 } }
    (0..$dose_last).each do |dose|
      lives  = indivs.count { |_, v| v[:pdays].keys.min == dose || (v[:final] == dose && v[:date_death] == ws) }
      days   = indivs.values.sum { |v| v[:pdays][dose] || 0 }
      deaths = indivs.count { |_, v| v[:final] == dose && v[:date_death] && ws <= v[:date_death] && v[:date_death] < we }
      sum[dose] = { lives: lives, days: days, deaths: deaths }
    end

    # dose0 を当該ウィンドウ参照に
    ref_days   = sum[0][:days]
    ref_deaths = sum[0][:deaths]

    # dose 別
    (0..$dose_last).each do |dose|
      s = sum[dose]; @dose_or_key = dose
      tag = "#{$areacode}_#{csv_step}_#{$periodstr}_#{agestr}_#{dose}"
      emit_line.call(fd, tag, s[:lives], s[:days], s[:deaths], ref_days, ref_deaths)
    end

    # vaxx / all
    vaxx = sum.select { |d,_| d > 0 }.values
    allv = sum.values
    { vaxx: vaxx, all: allv }.each do |key, arr|
      lives  = arr.sum { |h| h[:lives] }
      days   = arr.sum { |h| h[:days] }
      deaths = arr.sum { |h| h[:deaths] }
      @dose_or_key = key
      tag = "#{$areacode}_#{csv_step}_#{$periodstr}_#{agestr}_#{key}"
      emit_line.call(fd, tag, lives, days, deaths, ref_days, ref_deaths)
    end
  end
end

$opts[:pyear] && File.open($opts[:pyear], 'w') do |fd|
    # header
    fd.puts "id,areacode,area,areaj,step,period,age,dose,lives,persondays,deaths,lb0,ub0,rr0,lbm,ubm,mortality"

    $opts[:ages].is_a?(Array) && $opts[:ages].each do |agestr|
        indivs0 = $indivs.select{|k,v| v[:age] && v[:age].is_a?(Integer)}
        if indivs0.count != $indivs.count
            Log.warn "REDUCED, indivs0: #{indivs0.count}, $indivs: #{$indivs.count}"
        end
        indivs =
            if agestr == 'all'
                indivs0
            else
                min, max = agestr.end_with?('+') ?
                               [agestr.to_i, 200] : agestr.split('-').map{|v| v.to_i}
                r = (min..max)
                indivs0.select { |_, v| r.cover?(v[:age]) }
            end
        $opts[:steps].is_a?(Array) && $opts[:steps].each do |step|
            step = step.to_i if step !~ /^week$|^week-after-dose$/
            Log.info "++++++++++++++++++++ processing #{$areaname} age:#{agestr} step:#{step} N:#{indivs.count}"
            if step =~ /^week-after-dose$/
                pyear(fd, agestr, indivs, step, 1, 99)
            else
                pyear(fd, agestr, indivs, step, $opts[:start],
                      [$date_dose_last, $date_death_last].max)
            end
        end
    end
end

$opts[:excess] && File.open($opts[:excess], 'w') do |fd|
    years = Hash.new
    puts "死亡数/人口 10万人あたり(粗)死亡数"
    (2010..2025).each do |year|
        deaths = $indivs.select{|k, v| v[:date_death] && v[:date_death].year == year}
        lives0 = $indivs.select{|k, v| v[:age] > 2025-year &&
                                (!v[:date_death] ||
                                 v[:date_death].year >= year)} # その年に死亡ならカウント
        #lives = lives0.select{|k, v| (! v[:date_in] || v[:date_in].year <= year) &&
        #                      (! v[:date_out] || v[:date_out].year >= year)}
        lives = lives0.select{|k, v| (! v[:date_out] || v[:date_out].year >= year)}
        print "#{year}: #{deaths.count}/#{lives.count} #{(deaths.count.to_f*100000/lives.count).round(2)}"
        (1..12).each do |month|
            deaths2 = deaths.select{|k, v| v[:date_death].month == month}
            print " #{month}:#{deaths2.count}"
        end
        years[year] = {
            deaths: deaths.count,
            lives: lives.count,
        }
        0.step(100,10).each do |age0|
            age = age0 + (2025-year)
            upper = (age0 == 100) ? 200 : age + 10
            deaths2 = deaths.select{|k, v| v[:age] && age <= v[:age] && v[:age] < upper}
            lives2 = lives.select{|k, v| v[:age] && age <= v[:age] && v[:age] < upper}
            #print " #{age}-#{age+9}:#{deaths2.count}/#{lives2.count}"
            years[year][age0] = {
                deaths: deaths2.count,
                lives: lives2.count,
            }
        end
        puts
    end
    #pp years
    puts "年齢調整死亡数 10万人あたり年齢調整死亡数"
    (2010..2025).each do |year|
        deaths = 0
        0.step(100,10).each do |age|
            dl = years[year][age]
            deaths += dl[:deaths].to_f * years[2025][age][:lives].to_f / dl[:lives].to_f
        end
        puts "#{year}: #{deaths.round(2)} #{(deaths*100000/years[2024][:lives]).round(2)}"
    end

    vaxxed = $indivs.select{|k, v| v[:doses] != {}}
    puts "\nindivs: #{$indivs.count}, vaxxed: #{vaxxed.count}"

    [[2021,9],[2021,10],[2021,11],[2021,12],[2022,1],[2022,2],[2022,3],[2022,4],[2022,5],[2022,6],[2022,7],[2022,8]].each do |ym|
        year = ym[0]
        month = ym[1]
        count = 0
        vaxxed.each do |k, v|
            v[:doses].each do |k, dose|
                begin
                    if dose[:date].year == year && dose[:date].month == month
                        count += 1
                    end
                rescue
                    pp dose
                    exit
                end
            end
        end
        puts "#{year}-#{sprintf('%02d',month)}: #{count}"
    end
end

#2024年は0歳除く。 -> 0歳より上  2024-year -> 0
#2023年は0〜1歳除く。-> 1歳より上 2024-year -> 1
#2022年は0〜2歳除く。-> 2歳より上 2024-year -> 2
