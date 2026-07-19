# coding: utf-8

require_relative 'debug'

# 死亡・人口統計を期間、地域、年齢別に保持して変換するHash拡張。
# Hash extension for transforming mortality and population statistics by period, area, and age.
class Mstats < Hash
    @@init_flag = false
    @@today = nil
    @@today_y = nil
    @@Ages = {
        age_00_14:  [:age_00_04, :age_05_09, :age_10_14],
        age_15_64:  [:age_15_19, :age_20_24, :age_25_29, :age_30_34, :age_35_39,
                     :age_40_44, :age_45_49, :age_50_54, :age_55_59, :age_60_64, ],
        age_65_74:  [:age_65_69, :age_70_74],
        age_75_84:  [:age_75_79, :age_80_84],
        age_85over: [:age_85_89, :age_90_94, :age_95_99, :age_100over],
        # added
        age_05_14:  [:age_05_09, :age_10_14],
        age_15_29:  [:age_15_19, :age_20_24, :age_25_29],
        age_30_49:  [:age_30_34, :age_35_39, :age_40_44, :age_45_49],
        age_50_64:  [:age_50_54, :age_55_59, :age_60_64],
    }
    @@ages100 = {age_all: []}
    @@ages85 = {age_all: []}

    # 年齢階級定義と集計用の内部状態を初期化する。
    # Initialize age-band definitions and internal aggregation state.
    def initialize
        return if @@init_flag
        @@init_flag = true

        @@today = Date.today
        @@today_y = @@today.strftime('%Y').to_i

        (0..4).each do |age|
            age_sym = sprintf('age_%d', age).to_sym
            @@ages100[age_sym] = nil
            @@ages85[age_sym] = nil
        end
        (0..95).step(5) do |age|
            age_sym = sprintf('age_%02d_%02d', age, age+4).to_sym

            @@ages100[age_sym] = [age_sym]
            @@ages100[:age_all].push(age_sym)

            if age < 85
                @@ages85[age_sym] = [age_sym]
                @@ages85[:age_all].push(age_sym)
            else
                @@ages85[age_sym] = nil
            end
        end
        @@ages100[:age_all].push(:age_100over)
        @@ages100[:age_100over] = [:age_100over]
        @@ages100.merge!(@@Ages)

        @@ages85[:age_all].push(:age_85over)
        @@ages85[:age_100over] = nil
        @@ages85.merge!(@@Ages)
        @@ages85[:age_85over] = [:age_85over]

        Log.debug PP.pp(@@ages100, '')
        Log.debug PP.pp(@@ages85, '')
    end

    # 変換結果をMstatsとして返す互換ラッパー。
    # Compatibility wrapper that returns transformed results as Mstats.
    def new(&block)
        result = super(&block)
        Mstats[result]
    end

    # 選択結果の型をMstatsに保つ。
    # Preserve the Mstats type for filtered results.
    def select(&block)
        result = super(&block)
        Mstats[result]
    end

    # 並べ替え結果の型をMstatsに保つ。
    # Preserve the Mstats type for sorted results.
    def sort(&block)
        result = super(&block)
        Mstats[result]
    end

    # 結合結果の型をMstatsに保つ。
    # Preserve the Mstats type for merged results.
    def merge(&block)
        result = super(&block)
        Mstats[result]
    end

    # 保持する統計レコードをCSVとして標準出力へ書き出す。
    # Write the stored statistical records to standard output as CSV.
    def csvout
        CSV($stdout) do |csv|
            csv << self.values.first.keys

            self.each do |k, row|
                csv << row.values
            end
        end
    end

    # 基準期間との比較から超過死亡系列を計算する。
    # Calculate excess-mortality series relative to a reference period.
    def excess(**opts)
        #
        # X years (to YYYY) min, max, avg, diff, excess
        #
        morts = Mstats.new

        years = (opts[:years] && opts[:years].kind_of?(Integer) &&
                  1 <= opts[:years] && opts[:years] <= 5) ? opts[:years] : 5
        to_year = (opts[:to] && opts[:to].kind_of?(Integer) &&
                   1980 <= opts[:to] && opts[:to] <= @@today_y) ? opts[:to] : 2019
        apply = (opts[:apply] && opts[:apply].kind_of?(Integer) &&
                 1980 <= opts[:apply] && opts[:apply] <= @@today_y) ? opts[:apply] : @@today_y
        suffix = opts[:suffix] ? "#{opts[:suffix]}" : "#{years}to#{to_year}"

        Log.debug "#{to_year} #{apply}"

        #pp self
        #exit
        ages = Hash.new
        (1..53).each do |week|
            week_str = sprintf('%02d', week)
            if week != 53
                #puts
                #puts "week: #{week}"
                ages = Hash.new
                year_list = []
                ((to_year - 4)..to_year).each do |year|
                    year_list.push((year >= to_year - years+1) ? year : 0)
                end
                mortsX = self.select{|k, v| v[:week] == week && year_list.include?(v[:year])}
                #pp self
                #pp week.to_s, self.count, mortsX.count, year_list
                if mortsX.count != years
                    if mortsX.count == 0
                        #pp mortsX
                        break
                    end
                    #Log.debug "  #{week}: count=#{mortsX.count}\n"
                end
                #STMF_Ages.each do |age, _|
                mortsX.first[1].each do |age, _|
                    next if age.to_s !~ /^age/
                    (min, max) = mortsX.minmax{|(k1, v1), (k2, v2)| v1[age] <=> v2[age]}.
                                     map{|v| v[1][age]}
                    avg = (mortsX.sum{|k, v| v[age].to_f} / mortsX.count).round(2)
                    #puts "+++++++++++++++"
                    #pp type, age, min, max, avg
                    ages[age] = { min: min, max: max, avg: avg }
                end
                #pp ages
                #exit
            end

            # いつまで適用?
            loc_code_first = self.first[1][:loc_code]
            id_first = self.first[1][:doc_id]
            sex_first = self.first[1][:sex]
            ((to_year+1)..apply).each do |year|
                id = id_first.sub(/^#{loc_code_first}_\d+w\d+/,
                                  "#{loc_code_first}_#{year}w#{week_str}")
                next if ! self[id]
                [:min, :max, :avg,
                 :diff, :excess].each do |algo|
                    id2 = id.sub(/_#{sex_first}/,
                                 "#{algo.to_s}#{suffix}_#{sex_first}")
                    #next if year != to_year+1 && algo != :diff && algo != :excess
                    morts[id2] = self[id].dup
                    morts[id2][:doc_id] = id2
                    morts[id2][:algo] = "#{algo.to_s}#{suffix}"
                    ages.each do |age, vals|
                        next if ! self[id][age]
                        if algo.to_s =~ /min|max|avg/
                            morts[id2][age] = vals[algo]
                        elsif algo == :diff
                            morts[id2][age] =
                                (self[id][age] - vals[:avg]).round(2)
                        elsif algo == :excess
                            if vals[:avg] != 0
                                morts[id2][age] =
                                    (self[id][age].to_f/vals[:avg] - 1).round(2)
                            else
                                morts[id2][age] = 0
                            end
                        end
                    end
                end
            end
        end

        return morts
    end

    # 期間ごとの差を累積値へ変換する。
    # Convert period-by-period differences into cumulative values.
    def cumuldiff
        morts = Mstats.new
        cumuls = Hash.new

        self.sort{|(k1,v1),(k2,v2)| k1<=>k2}.to_h.each do |id0, mort0|
            next if mort0[:algo] !~ /^diff/
            mort0.each do |k, v|
                next if k !~ /^age/
                id = id0.sub(/_diff.*_#{mort0[:sex]}/, "_cumuldiff_#{mort0[:sex]}")
                if ! morts[id]
                    morts[id] = mort0.dup
                    morts[id][:doc_id] = id
                    morts[id][:algo] = 'cumuldiff'
                end
                cumuls[k] = 0 if ! cumuls[k]
                years = Date.leap?(mort0[:year]) ? 366 : 365
                morts[id][k] = (cumuls[k] += mort0[k] * 7 / years).round(2)
                Log.debug "#{id0}: #{k}: #{morts[id][k]} #{mort0[:algo]}:#{mort0[k].round(2)}"
            end
        end
        Log.debug PP.pp(morts, '')

        return morts
    end

    # 月次・日次系列を週次の統計系列へ集約する。
    # Aggregate monthly or daily observations into weekly statistical series.
    def to_week(**opts)

        range = 7
        causes2 = Mstats.new
        sorted = self.sort{|(k1,v1),(k2,v2)| k1<=>k2}.to_h
        (id_first, first) = sorted.first
        #start_week = (Date.commercial(first[:year], 1, 1).year == first[:year]) ? 1 : 2

        year = first[:year]
        week = 1
        loop do
            break if year > @@today_y
            week_str = sprintf('%02d', week)
            #Log.debug "#{year}w#{week_str}"
            begin
                date = Date.commercial(year, week, 7)
            rescue
                if week >= 53
                    year += 1
                    week = 1
                    next
                end
                STDERR.put "Error unknown"
                exit
            end
            year2 = date.year
            month = date.month
            month_str = sprintf('%02d', month)
            id2  = id_first.sub(/^.+_\d+m\d+/,
                                    "#{first[:loc_code]}_#{year}w#{week_str}")
            id   = id_first.sub(/^.+_\d+m\d+/,
                                     "#{first[:loc_code]}_#{year2}m#{month_str}")
            cause = self[id]
            if ! cause
                #Log.debug "++++++++++++++++++++++++++++++++++++++++++++++++"
                #Log.debug "NOT CREATED #{id2} (not found #{id})"
                week += 1
                next
            end

            days = date.day
            days = 7 if days > 7
            range = 7
            range = Date.new(year, month, -1).day if first[:rate] !~ /amr/

            Log.debug "++++++++++++++++++++++++++++++++++++++++++++++++"
            Log.debug "#{cause[:year]}w#{week_str}" +
                      " #{Date.commercial(year, week, 1).to_s}" +
                      " #{Date.commercial(year, week, 7).to_s}"
            Log.debug "#{id2} <= #{id} * #{days} / #{range}"
            cause2 = Hash.new
            cause.each do |k, v|
                if k == :doc_id
                    cause2[:doc_id] = id2
                elsif k == :yearmonth
                    cause2[:yearweek] = "#{year}w#{week_str}"
                elsif k == :year
                    cause2[:year] = year
                elsif k == :month
                    cause2[:week] = week
                elsif k == :date
                    cause2[:date] = Date.commercial(year, week, 7).to_s
                elsif k =~ /^age/
                    #STDERR.print "#{k}=>#{v}: cause2[k]=#{cause2[k]}, d=#{days}, r=#{range}"
                    if ! v
                        cause2[k] = v
                        #Log.debug " -> not modified"
                        next
                    end
                    if ! cause2[k]
                        cause2[k] = (v.to_f * days / range).round(2)
                    else
                        cause2[k] = (cause2[k] + v.to_f * days / range).round(2)
                    end
                else
                    cause2[k] = v
                end
            end

            if days < 7
                #Log.debug "++++++++++++++++++++++++++++++++++++++++++++++++ add another"
                month2 = month - 1
                if month2 == 0
                    month2 = 12
                    year2 -= 1
                end
                month2_str = sprintf('%02d', month2)
                id = id_first.sub(/^.+_\d+m\d+/,
                                  "#{first[:loc_code]}_#{year2}m#{month2_str}")
                cause = self[id]
                if ! cause
                    Log.debug "DELETE #{id2} (not found #{id})"
                    # cast this cause
                    week += 1
                    next
                end
                days = 7 - days
                range = Date.new(year2, month2, -1).day if first[:rate] !~ /amr/
                Log.debug "#{id2} <= #{id} * #{days} / #{range}"

                cause.each do |k, v|
                    next if k !~ /^age/
                    #STDERR.print "#{k}=>#{v}: cause2[k]=#{cause2[k]}, d=#{days}, r=#{range}"
                    next if ! v
                    if ! cause2[k]
                        cause2[k] = (v.to_f * days / range).round(2)
                    else
                        cause2[k] = (cause2[k] + v.to_f * days / range).round(2)
                    end
                    #pp uncompleted
                    #Log.debug " -> #{cause2[k]} (#{(v.to_f * days / range).round(2)})"
                end
            end
            causes2[id2] = cause2
            week += 1
        end
        return causes2
    end

    # 短期変動を抑えるため系列を平滑化する。
    # Smooth a series to reduce short-term variation.
    def smooth
        prevs = []
        self.sort{|(k1, v1), (k2, v2)| k1<=>k2}.each do |id, cause|
            if ! cause[:month1]
                begin
                    cause[:month1] = Date.commercial(cause[:year], cause[:week], 1).month
                    cause[:month7] = Date.commercial(cause[:year], cause[:week], 7).month
                rescue
                    Log.error PP.pp(cause, '')
                    exit
                end
            end
            if prevs[1] && prevs[0] && (prevs[1][:month1] != prevs[0][:month1]) &&
               #(prevs[1][:month7] == prevs[0][:month7]) && XXX 53週の処理のため省く
               (prevs[0][:month7] == cause[:month7])
                cause.each do |k, _|
                    next if k !~ /^age_/
                    next if ! (prevs[1][k] && prevs[1][k].is_a?(Numeric) &&
                               prevs[0][k] && prevs[0][k].is_a?(Numeric) &&
                               cause[k] && cause[k].is_a?(Numeric))
                    next if prevs[0][k] != cause[k]
                    diff1 = prevs[1][k] - prevs[0][k]
                    next if diff1 == 0
                    day1 = prevs[0][k] / 7
                    diff2 = (diff1.abs*0.33 < day1) ? diff1*0.33 :
                                ((diff1 > 0) ? day1 : -day1)
                    Log.debug
                    Log.debug "#{id} #{k} (#{cause[:date]}) 1: #{prevs[1][k]}, #{prevs[0][k]}, #{cause[k]}, #{diff1.round(2)}, #{day1.round(2)}, #{diff2.round(2)}"
                    prevs[1][k] = (prevs[1][k] - diff2).round(2)
                    prevs[0][k] = (prevs[0][k] + diff2).round(2)
                    Log.debug "#{id} #{k} (#{cause[:date]}) 1: #{prevs[1][k]}, #{prevs[0][k]}, #{cause[k]}, #{diff1.round(2)}, #{day1.round(2)}, #{diff2.round(2)}"
                end
            end

            if prevs[1] && prevs[0] && (cause[:month7] != prevs[0][:month7]) &&
               #(cause[:month7] == prevs[0][:month7]) && XXX 53週の処理のため省く
               (prevs[0][:month1] == prevs[1][:month1])
                prevs[1].each do |k, _|
                    next if k !~ /^age_/
                    next if ! (cause[k] && cause[k].is_a?(Numeric) &&
                               prevs[0][k] && prevs[0][k].is_a?(Numeric) &&
                               prevs[1][k] && prevs[1][k].is_a?(Numeric))
                    next if prevs[0][k] != prevs[1][k]
                    diff1 = cause[k] - prevs[0][k]
                    next if diff1 == 0
                    day1 = prevs[0][k] / 7
                    diff2 = (diff1.abs*0.33 < day1) ? diff1*0.33 :
                                ((diff1 > 0) ? day1 : -day1)
                    Log.debug
                    Log.debug "#{id} #{k} (#{cause[:date]}) 2: #{prevs[1][k]}, #{prevs[0][k]}, #{cause[k]}, #{diff1.round(2)}, #{day1.round(2)}, #{diff2.round(2)}"
                    cause[k] = (cause[k] - diff2).round(2)
                    prevs[0][k] = (prevs[0][k] + diff2).round(2)
                    Log.debug "#{id} #{k} (#{cause[:date]}) 2: #{prevs[1][k]}, #{prevs[0][k]}, #{cause[k]}, #{diff1.round(2)}, #{day1.round(2)}, #{diff2.round(2)}"
                end
            end

            prevs.unshift(cause)
            next
        end
        return self
    end

    # 統計入力の文字列を欠測値対応の数値へ変換する。
    # Convert statistical input strings into numbers with missing-value handling.
    class ::String
        def to_num
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

    # 85歳以上の年齢階級を既存の高齢階級から合算する。
    # Build the age-85-and-over band from the available older age groups.
    def add_age85over
        self.each do |doc_id, cause|
            @@Ages.each do |age, ages2|
                begin
                    cause[age] = ages2.map{|age3| cause[age3].to_i}.sum
                rescue
                    Log.error PP.pp(ages2.map{|age3| cause[age3].to_i},'')
                    exit
                end
            end
        end
    end

    # 年齢階級別人口を用いて年齢調整系列を計算する。
    # Calculate age-adjusted series from age-specific populations.
    def adjust
        causes2 = Mstats.new

        Log.info("  reading popjp.csv...")
        $pops = CSV.read('popjp.csv', headers: true).
                    map{|pop| [pop['doc_id'],
                               pop.to_h.
                                   map{|k, v| [ k.to_sym,
                                                v.is_a?(String) ? v.to_num : nil]}.to_h]}.to_h

        pop_lasts = Hash.new
        ['both', 'male', 'female'].each do |sex|
            pop_lasts[sex] = $pops.select{|k, v| v[:sex] == sex}.to_a.last[1]
        end
        Log.debug "Last pop:"
        Log.debug PP.pp(pop_lasts.map{|k, v| v[:doc_id]}, '')

        prev_pref = ''
        self.each do |id0, cause0|
            #next if cause0[:death_code] != 'all' || cause0[:sex] != 'both' # XXX for debug
            pref = id0.sub(/(^\w+_\d+m\d+)_.*$/, '\1')
            if pref != prev_pref
                Log.info "  #{pref}"
                prev_pref = pref
            end

            sex = cause0[:sex]
            days_y = Date.leap?(cause0[:year]) ? 366 : 365
            days_m = Date.new(cause0[:year], cause0[:month], -1).day

            id_pop = id0.sub(/death__.*__/, 'pop__conf__')
            id_pop = id0.sub(/death__.*__/, 'pop__est__') if ! $pops[id_pop]
            pop = $pops[id_pop]
            Log.debug ""

            if ! pop[:age_85_89]
                ages = @@ages85
            else
                #Log.error PP.pp(cause0, '')
                #Log.error "++++++++++++++++++ #{cause0[:age_85_89]}"
                #exit
                ages = @@ages100
            end

            causes3 = Hash.new
            rates = ['', 'adj', 'per100k', 'amr']
            rates.each do |rate|
                if rate == ''
                    id = id0
                    causes3[rate] = cause0
                    Log.debug "TARGET: #{id} #{id0} #{id_pop}"
                else
                    id = id0.sub(/death_/, "death_#{rate}")
                    causes2[id] = self[id0].dup
                    causes2[id][:doc_id] = id
                    causes2[id][:rate] = rate

                    causes3[rate] = causes2[id] # 利便性のため
                    Log.debug PP.pp(causes3[rate], '        ')
                end
            end

            ages.each do |age, ages2|
                if ! ages2
                    causes3.each do |rate, cause|
                        cause[age] = nil if rate != ''
                    end
                    next
                end
                sum = sum_adj = sum_pop = sum_pop_last = 0
                ages2.each do |age2|
                    if ! cause0[age2]
                        Log.error "#{id}, #{age2}\n"
                        exit
                    end
                    next if cause0[age2] == ''

                    Log.debug "  #{age} <- #{age2}"
                    sum += cause0[age2]
                    Log.debug "    sum:          <- #{cause0[age2]}"

                    sum_adj += cause0[age2].to_f * pop_lasts[sex][age2] / pop[age2]
                    Log.debug "    sum_adj:      <- #{cause0[age2]} * #{pop_lasts[sex][age2]} / #{pop[age2]}"
                    sum_pop += pop[age2]
                    Log.debug "    sum_pop:      <- #{pop[age2]}"

                    sum_pop_last += pop_lasts[sex][age2]
                    Log.debug "    sum_pop_last: <- #{pop_lasts[sex][age2]}"

                end
                causes3.each do |rate, cause|
                    append = ''
                    if rate == ''
                        cause[age] = sum # XXX for age_all
                    elsif rate == 'adj'
                        cause[age] = sum_adj
                    elsif rate == 'per100k'
                        cause[age] = sum_adj * 100000 / sum_pop_last
                        append = " * 100000 / #{sum_pop_last} (<- #{sum_pop})"
                    elsif rate == 'amr'
                        cause[age] = (sum_adj * 100000 * days_y) /
                                     (sum_pop_last * days_m)
                        append = " * #{days_y} / #{days_m}"
                    end
                    cause[age] = cause[age].round(2) if rate != ''
                    Log.debug "  #{age}: #{cause[age]} (#{rate})" + append
                end
            end
        end
        return causes2
    end

    #
    # 一次回帰線も表示
    #
    # 配列化した時系列へ回帰計算を追加する。
    # Add regression calculations to array-based time series.
    class ::Array
        # 指定年までの観測値から一次回帰線を求める。
        # Fit a linear regression line using observations through the specified year.
        def reg_line(y)
            # 以下の場合は例外スロー
            # - 引数の配列が Array クラスでない
            # - 自身配列が空
            # - 配列サイズが異なれば例外
            raise "Argument is not a Array class!"  unless y.class == Array
            raise "Self array is nil!"              if self.size == 0
            raise "Argument array size is invalid!" unless self.size == y.size

            # x の総和
            sum_x = self.inject(0) { |s, a| s += a }
            # y の総和
            sum_y = y.inject(0) { |s, a| s += a }
            # x^2 の総和
            sum_xx = self.inject(0) { |s, a| s += a * a }
            # x * y の総和
            sum_xy = self.zip(y).inject(0) { |s, a| s += a[0] * a[1] }
            # 切片 a
            a  = sum_xx * sum_y - sum_xy * sum_x
            a /= (self.size * sum_xx - sum_x * sum_x).to_f
            # 傾き b
            b  = self.size * sum_xy - sum_x * sum_y
            b /= (self.size * sum_xx - sum_x * sum_x).to_f
            {intercept: a, slope: b}
        end
    end

    # 指定した基準期間で各系列の回帰値を生成する。
    # Generate regression values for each series over the requested reference period.
    def regression(**opts)
        morts = Mstats.new

        years = (opts[:years] && opts[:years].kind_of?(Integer) &&
                  1 <= opts[:years] && opts[:years] <= 5) ? opts[:years] : 5
        to_year = (opts[:to] && opts[:to].kind_of?(Integer) &&
                   1980 <= opts[:to] && opts[:to] <= @@today_y) ? opts[:to] : 2019
        suffix = opts[:suffix] ? "#{opts[:suffix]}" : "#{years}to#{to_year}"

        (id_first, mort_first) = self.first

        regs = Hash.new
        (1..53).each do |week|
            morts0 = self.select{|k, v| week == v[:week] &&
                                 (to_year - years + 1) <= v[:year] && v[:year] <= to_year}
            #Log.debug "#{week}: 1" + PP.pp(morts0, '')
            #Log.debug PP.pp(mort_first, '')
            if week != 53
                mort_first.each do |k, v|
                    next if k !~ /^age/ || k =~ /min|max|avg/

                    ary_x = Array.new
                    ary_y = Array.new
                    morts0.each do |id0, mort0|
                        next if ! mort0[k] && mort0[k].to_f < 0
                        ary_x.push(mort0[:year] - to_year)
                        ary_y.push(mort0[k].to_f)
                    end
                    Log.debug "#{week} #{k}"
                    Log.debug ary_x
                    Log.debug ary_y

                    regs[week] = Hash.new if ! regs[week]
                    regs[week][k] = ary_x.reg_line(ary_y)
                end
            end
        end

        #補正
        Log.debug PP.pp(regs, '')
        slope_avgs = Hash.new
        regs[1].each do |age, v|
            slopes = regs.map{|k, v| v[age][:slope]}.compact
            begin
                slope_avgs[age] = slopes.sum / slopes.count if slopes.count > 0
            rescue
                slope_avgs[age] = nil
            end
        end
        Log.debug slope_avgs

        regs[53] = regs[52]
        Log.debug PP.pp(regs, '')

        (1..53).each do |week|
            self.select{|k, v| week == v[:week] &&
                        v[:year] >= to_year - years + 1}.each do |id0, mort0|
                regs[week].each do |age, reg|

                    # regression line (AVG)
                    id_reg = id0.sub(/_#{mort_first[:sex]}/,
                                     "avg#{suffix}_#{mort_first[:sex]}")
                    if ! morts[id_reg]
                        morts[id_reg] = mort0.dup
                        morts[id_reg][:doc_id] = id_reg
                        morts[id_reg][:algo] = "avg#{suffix}"
                    end
                    begin
                        #morts[id_reg][age] = (reg[:slope] * (mort0[:year] - to_year) +
                        morts[id_reg][age] = (slope_avgs[age] * (mort0[:year] - to_year) +
                                            reg[:intercept]).round(2)
                    rescue
                        morts[id_reg][age] = nil
                    end
                    next if morts[id_reg][:year] <= to_year

                    # diff
                    id_diff = id0.sub(/_#{mort_first[:sex]}/,
                                 "diff#{suffix}_#{mort_first[:sex]}")
                    if ! morts[id_diff]
                        morts[id_diff] = mort0.dup
                        morts[id_diff][:doc_id] = id_diff
                        morts[id_diff][:algo] = "diff#{suffix}"
                    end
                    begin
                        morts[id_diff][age] = mort0[age] - morts[id_reg][age]
                    rescue
                        morts[id_diff][age] = nil
                    end
                    if morts[id_diff][age].is_a?(Float) &&
                       (morts[id_diff][age].nan? ||  morts[id_diff][age].infinite?)
                        morts[id_diff][age] = nil
                    end

                    # excess
                    id_excess = id0.sub(/_#{mort_first[:sex]}/,
                                 "excess#{suffix}_#{mort_first[:sex]}")
                    if ! morts[id_excess]
                        morts[id_excess] = mort0.dup
                        morts[id_excess][:doc_id] = id_excess
                        morts[id_excess][:algo] = "excess#{suffix}"
                    end
                    begin
                        morts[id_excess][age] = (mort0[age] / morts[id_reg][age] - 1).round(2)
                    rescue
                        morts[id_excess][age] = nil
                    end
                    if morts[id_excess][age].is_a?(Float) &&
                       (morts[id_excess][age].nan? || morts[id_excess][age].infinite?)
                        morts[id_excess][age] = nil
                    end
                end
            end
        end

        return morts
    end

    # 複数の回帰条件を各統計系列へまとめて適用する。
    # Apply multiple regression specifications across all statistical series.
    def everyreg(**opts)
        morts = Mstats.new

        years = (opts[:years] && opts[:years].kind_of?(Integer) &&
                  1 <= opts[:years] && opts[:years] <= 5) ? opts[:years] : 5
        to_year = (opts[:to] && opts[:to].kind_of?(Integer) &&
                   1980 <= opts[:to] && opts[:to] <= @@today_y) ? opts[:to] : 2019
        suffix = opts[:suffix] ? "#{opts[:suffix]}" : "#{years}to#{to_year}"

        (id_first, mort_first) = self.first

        regs = Hash.new
        start_year = (to_year - years + 1)
        (start_year..Date.today.year).each do |start_year2|
            to_year2 = start_year2 + years -1
            break if ! self.find{|k, v| v[:year] == to_year2 + 1}
            (1..53).each do |week|
                morts0 = self.select{|k, v| week == v[:week] &&
                                     start_year2 <= v[:year] && v[:year] <= to_year2}
                #Log.debug "#{week}: 1" + PP.pp(morts0, '')
                #Log.debug PP.pp(mort_first, '')
                if week != 53
                    mort_first.each do |k, v|
                        next if k !~ /^age/ || k =~ /min|max|avg/

                        ary_x = Array.new
                        ary_y = Array.new
                        morts0.each do |id0, mort0|
                            next if ! mort0[k] && mort0[k].to_f < 0
                            ary_x.push(mort0[:year] - to_year2)
                            ary_y.push(mort0[k].to_f)
                        end
                        Log.debug "#{week} #{k}"
                        Log.debug ary_x
                        Log.debug ary_y

                        regs[week] = Hash.new if ! regs[week]
                        regs[week][k] = ary_x.reg_line(ary_y)
                    end
                end
            end

            #補正
            Log.debug PP.pp(regs, '')
            slope_avgs = Hash.new
            regs[1].each do |age, v|
                slopes = regs.map{|k, v| v[age][:slope]}.compact
                begin
                    slope_avgs[age] = slopes.sum / slopes.count if slopes.count > 0
                rescue
                    slope_avgs[age] = nil
                end
            end
            Log.debug slope_avgs

            regs[53] = regs[52]
            Log.debug PP.pp(regs, '')

            (1..53).each do |week|
                self.select{|k, v| week == v[:week] &&
                            ((start_year2 == start_year &&
                              start_year2 <= v[:year] && v[:year] <= to_year2 + 1) ||
                             (start_year2 != start_year && v[:year] == to_year2 + 1))}
                    .each do |id0, mort0|
                    regs[week].each do |age, reg|

                        # regression line (AVG)
                        id_reg = id0.sub(/_#{mort_first[:sex]}/,
                                         "avg#{suffix}_#{mort_first[:sex]}")
                        if ! morts[id_reg]
                            morts[id_reg] = mort0.dup
                            morts[id_reg][:doc_id] = id_reg
                            morts[id_reg][:algo] = "avg#{suffix}"
                        end
                        begin
                            #morts[id_reg][age] = (reg[:slope] * (mort0[:year] - to_year2) +
                            morts[id_reg][age] = (slope_avgs[age] * (mort0[:year] - to_year2)+
                                                  reg[:intercept]).round(2)
                        rescue
                            morts[id_reg][age] = nil
                        end
                        next if morts[id_reg][:year] <= to_year2

                        # diff
                        id_diff = id0.sub(/_#{mort_first[:sex]}/,
                                          "diff#{suffix}_#{mort_first[:sex]}")
                        if ! morts[id_diff]
                            morts[id_diff] = mort0.dup
                            morts[id_diff][:doc_id] = id_diff
                            morts[id_diff][:algo] = "diff#{suffix}"
                        end
                        begin
                            morts[id_diff][age] = mort0[age] - morts[id_reg][age]
                        rescue
                            morts[id_diff][age] = nil
                        end
                        if morts[id_diff][age].is_a?(Float) &&
                           (morts[id_diff][age].nan? ||  morts[id_diff][age].infinite?)
                            morts[id_diff][age] = nil
                        end

                        # excess
                        id_excess = id0.sub(/_#{mort_first[:sex]}/,
                                            "excess#{suffix}_#{mort_first[:sex]}")
                        if ! morts[id_excess]
                            morts[id_excess] = mort0.dup
                            morts[id_excess][:doc_id] = id_excess
                            morts[id_excess][:algo] = "excess#{suffix}"
                        end
                        begin
                            morts[id_excess][age] = (mort0[age] / morts[id_reg][age] - 1).round(2)
                        rescue
                            morts[id_excess][age] = nil
                        end
                        if morts[id_excess][age].is_a?(Float) &&
                           (morts[id_excess][age].nan? || morts[id_excess][age].infinite?)
                            morts[id_excess][age] = nil
                        end
                    end
                end
            end
        end
        return morts
    end
end

Locs = {
    'AFG' => {en: 'Afghanistan', ja: 'アフガニスタン'},
    'ALB' => {en: 'Albania', ja: 'アルバニア'},
    'DZA' => {en: 'Algeria', ja: 'アルジェリア'},
    'AND' => {en: 'Andorra', ja: 'アンドラ'},
    'AGO' => {en: 'Angola', ja: 'アンゴラ'},
    'AIA' => {en: 'Anguilla', ja: 'アンギラ'},
    'ATG' => {en: 'Antigua and Barbuda', ja: 'アンティグア・バーブーダ'},
    'ARG' => {en: 'Argentina', ja: 'アルゼンチン'},
    'ARM' => {en: 'Armenia', ja: 'アルメニア'},
    'ABW' => {en: 'Aruba', ja: 'アルバ'},
    'AUS' => {en: 'Australia', ja: 'オーストラリア'},
    'AUT' => {en: 'Austria', ja: 'オーストリア'},
    'AZE' => {en: 'Azerbaijan', ja: 'アゼルバイジャン'},
    'BHS' => {en: 'Bahamas', ja: 'バハマ'},
    'BHR' => {en: 'Bahrain', ja: 'バーレーン'},
    'BGD' => {en: 'Bangladesh', ja: 'バングラデシュ'},
    'BRB' => {en: 'Barbados', ja: 'バルバドス'},
    'BLR' => {en: 'Belarus', ja: 'ベラルーシ'},
    'BEL' => {en: 'Belgium', ja: 'ベルギー'},
    'BLZ' => {en: 'Belize', ja: 'ベリーズ'},
    'BEN' => {en: 'Benin', ja: 'ベナン'},
    'BMU' => {en: 'Bermuda', ja: 'バミューダ'},
    'BTN' => {en: 'Bhutan', ja: 'ブータン'},
    'BOL' => {en: 'Bolivia', ja: 'ボリビア'},
    'BES' => {en: 'Bonaire Sint Eustatius and Saba', ja: 'ボネール、シント・ユースタティウスおよびサバ'},
    'BIH' => {en: 'Bosnia and Herzegovina', ja: 'ボスニア・ヘルツェゴビナ'},
    'BWA' => {en: 'Botswana', ja: 'ボツワナ'},
    'BRA' => {en: 'Brazil', ja: 'ブラジル'},
    'VGB' => {en: 'British Virgin Islands', ja: 'イギリス領ヴァージン諸島'},
    'BRN' => {en: 'Brunei', ja: 'ブルネイ'},
    'BGR' => {en: 'Bulgaria', ja: 'ブルガリア'},
    'BFA' => {en: 'Burkina Faso', ja: 'ブルキナファソ'},
    'BDI' => {en: 'Burundi', ja: 'ブルンジ'},
    'KHM' => {en: 'Cambodia', ja: 'カンボジア'},
    'CMR' => {en: 'Cameroon', ja: 'カメルーン'},
    'CAN' => {en: 'Canada', ja: 'カナダ'},
    'CPV' => {en: 'Cape Verde', ja: 'カーボベルデ'},
    'CYM' => {en: 'Cayman Islands', ja: 'ケイマン諸島'},
    'CAF' => {en: 'Central African Republic', ja: '中央アフリカ'},
    'TCD' => {en: 'Chad', ja: 'チャド'},
    'CHL' => {en: 'Chile', ja: 'チリ'},
    'CHN' => {en: 'China', ja: '中国'},
    'COL' => {en: 'Colombia', ja: 'コロンビア'},
    'COM' => {en: 'Comoros', ja: 'コモロ'},
    'COG' => {en: 'Congo', ja: 'コンゴ共和国'},
    'COK' => {en: 'Cook Islands', ja: 'クック諸島'},
    'CRI' => {en: 'Costa Rica', ja: 'コスタリカ'},
    'CIV' => {en: "Cote d'Ivoire", ja: 'コートジボワール'},
    'HRV' => {en: 'Croatia', ja: 'クロアチア'},
    'CUB' => {en: 'Cuba', ja: 'キューバ'},
    'CUW' => {en: 'Curacao', ja: 'キュラソー'},
    'CYP' => {en: 'Cyprus', ja: 'キプロス'},
    'CZE' => {en: 'Czechia', ja: 'チェコ'},
    'COD' => {en: 'Democratic Republic of Congo', ja: 'コンゴ民主共和国'},
    'DNK' => {en: 'Denmark', ja: 'デンマーク'},
    'DJI' => {en: 'Djibouti', ja: 'ジブチ'},
    'DMA' => {en: 'Dominica', ja: 'ドミニカ国'},
    'DOM' => {en: 'Dominican Republic', ja: 'ドミニカ共和国'},
    'ECU' => {en: 'Ecuador', ja: 'エクアドル'},
    'EGY' => {en: 'Egypt', ja: 'エジプト'},
    'SLV' => {en: 'El Salvador', ja: 'エルサルバドル'},
    'GNQ' => {en: 'Equatorial Guinea', ja: '赤道ギニア'},
    'ERI' => {en: 'Eritrea', ja: 'エリトリア'},
    'EST' => {en: 'Estonia', ja: 'エストニア'},
    'SWZ' => {en: 'Eswatini', ja: 'エスワティニ'},
    'ETH' => {en: 'Ethiopia', ja: 'エチオピア'},
    'FRO' => {en: 'Faeroe Islands', ja: 'フェロー諸島'},
    'FLK' => {en: 'Falkland Islands', ja: 'フォークランド（マルビナス）諸島'},
    'FJI' => {en: 'Fiji', ja: 'フィジー'},
    'FIN' => {en: 'Finland', ja: 'フィンランド'},
    'FRA' => {en: 'France', ja: 'フランス'},
    'PYF' => {en: 'French Polynesia', ja: 'フランス領ポリネシア'},
    'GAB' => {en: 'Gabon', ja: 'ガボン'},
    'GMB' => {en: 'Gambia', ja: 'ガンビア'},
    'GEO' => {en: 'Georgia', ja: 'ジョージア'},
    'DEU' => {en: 'Germany', ja: 'ドイツ'},
    'GHA' => {en: 'Ghana', ja: 'ガーナ'},
    'GIB' => {en: 'Gibraltar', ja: 'ジブラルタル'},
    'GRC' => {en: 'Greece', ja: 'ギリシャ'},
    'GRL' => {en: 'Greenland', ja: 'グリーンランド'},
    'GRD' => {en: 'Grenada', ja: 'グレナダ'},
    'GTM' => {en: 'Guatemala', ja: 'グアテマラ'},
    'GGY' => {en: 'Guernsey', ja: 'ガーンジー'},
    'GIN' => {en: 'Guinea', ja: 'ギニア'},
    'GNB' => {en: 'Guinea-Bissau', ja: 'ギニアビサウ'},
    'GUY' => {en: 'Guyana', ja: 'ガイアナ'},
    'HTI' => {en: 'Haiti', ja: 'ハイチ'},
    'HND' => {en: 'Honduras', ja: 'ホンジュラス'},
    'HKG' => {en: 'Hong Kong', ja: '香港'},
    'HUN' => {en: 'Hungary', ja: 'ハンガリー'},
    'ISL' => {en: 'Iceland', ja: 'アイスランド'},
    'IND' => {en: 'India', ja: 'インド'},
    'IDN' => {en: 'Indonesia', ja: 'インドネシア'},
    'IRN' => {en: 'Iran', ja: 'イラン'},
    'IRQ' => {en: 'Iraq', ja: 'イラク'},
    'IRL' => {en: 'Ireland', ja: 'アイルランド'},
    'IMN' => {en: 'Isle of Man', ja: 'マン島'},
    'ISR' => {en: 'Israel', ja: 'イスラエル'},
    'ITA' => {en: 'Italy', ja: 'イタリア'},
    'JAM' => {en: 'Jamaica', ja: 'ジャマイカ'},
    'JPN' => {en: 'Japan', ja: '日本'},
    'JEY' => {en: 'Jersey', ja: 'ジャージー'},
    'JOR' => {en: 'Jordan', ja: 'ヨルダン'},
    'KAZ' => {en: 'Kazakhstan', ja: 'カザフスタン'},
    'KEN' => {en: 'Kenya', ja: 'ケニア'},
    'KIR' => {en: 'Kiribati', ja: 'キリバス'},
    'KWT' => {en: 'Kuwait', ja: 'クウェート'},
    'KGZ' => {en: 'Kyrgyzstan', ja: 'キルギス'},
    'LAO' => {en: 'Laos', ja: 'ラオス'},
    'LVA' => {en: 'Latvia', ja: 'ラトビア'},
    'LBN' => {en: 'Lebanon', ja: 'レバノン'},
    'LSO' => {en: 'Lesotho', ja: 'レソト'},
    'LBR' => {en: 'Liberia', ja: 'リベリア'},
    'LBY' => {en: 'Libya', ja: 'リビア'},
    'LIE' => {en: 'Liechtenstein', ja: 'リヒテンシュタイン'},
    'LTU' => {en: 'Lithuania', ja: 'リトアニア'},
    'LUX' => {en: 'Luxembourg', ja: 'ルクセンブルク'},
    'MAC' => {en: 'Macao', ja: 'マカオ'},
    'MDG' => {en: 'Madagascar', ja: 'マダガスカル'},
    'MWI' => {en: 'Malawi', ja: 'マラウイ'},
    'MYS' => {en: 'Malaysia', ja: 'マレーシア'},
    'MDV' => {en: 'Maldives', ja: 'モルディブ'},
    'MLI' => {en: 'Mali', ja: 'マリ'},
    'MLT' => {en: 'Malta', ja: 'マルタ'},
    'MHL' => {en: 'Marshall Islands', ja: 'マーシャル諸島'},
    'MRT' => {en: 'Mauritania', ja: 'モーリタニア'},
    'MUS' => {en: 'Mauritius', ja: 'モーリシャス'},
    'MEX' => {en: 'Mexico', ja: 'メキシコ'},
    'FSM' => {en: 'Micronesia (country)', ja: 'ミクロネシア連邦'},
    'MDA' => {en: 'Moldova', ja: 'モルドバ'},
    'MCO' => {en: 'Monaco', ja: 'モナコ'},
    'MNG' => {en: 'Mongolia', ja: 'モンゴル'},
    'MNE' => {en: 'Montenegro', ja: 'モンテネグロ'},
    'MSR' => {en: 'Montserrat', ja: 'モントセラト'},
    'MAR' => {en: 'Morocco', ja: 'モロッコ'},
    'MOZ' => {en: 'Mozambique', ja: 'モザンビーク'},
    'MMR' => {en: 'Myanmar', ja: 'ミャンマー'},
    'NAM' => {en: 'Namibia', ja: 'ナミビア'},
    'NRU' => {en: 'Nauru', ja: 'ナウル'},
    'NPL' => {en: 'Nepal', ja: 'ネパール'},
    'NLD' => {en: 'Netherlands', ja: 'オランダ'},
    'NCL' => {en: 'New Caledonia', ja: 'ニューカレドニア'},
    'NZL' => {en: 'New Zealand', ja: 'ニュージーランド'},
    'NIC' => {en: 'Nicaragua', ja: 'ニカラグア'},
    'NER' => {en: 'Niger', ja: 'ニジェール'},
    'NGA' => {en: 'Nigeria', ja: 'ナイジェリア'},
    'NIU' => {en: 'Niue', ja: 'ニウエ'},
    'MKD' => {en: 'North Macedonia', ja: '北マケドニア'},
    'NOR' => {en: 'Norway', ja: 'ノルウェー'},
    'OMN' => {en: 'Oman', ja: 'オマーン'},
    'PAK' => {en: 'Pakistan', ja: 'パキスタン'},
    'PLW' => {en: 'Palau', ja: 'パラオ'},
    'PSE' => {en: 'Palestine', ja: 'パレスチナ'},
    'PAN' => {en: 'Panama', ja: 'パナマ'},
    'PNG' => {en: 'Papua New Guinea', ja: 'パプアニューギニア'},
    'PRY' => {en: 'Paraguay', ja: 'パラグアイ'},
    'PER' => {en: 'Peru', ja: 'ペルー'},
    'PHL' => {en: 'Philippines', ja: 'フィリピン'},
    'PCN' => {en: 'Pitcairn', ja: 'ピトケアン'},
    'POL' => {en: 'Poland', ja: 'ポーランド'},
    'PRT' => {en: 'Portugal', ja: 'ポルトガル'},
    'QAT' => {en: 'Qatar', ja: 'カタール'},
    'ROU' => {en: 'Romania', ja: 'ルーマニア'},
    'RUS' => {en: 'Russia', ja: 'ロシア'},
    'RWA' => {en: 'Rwanda', ja: 'ルワンダ'},
    'SHN' => {en: 'Saint Helena', ja: 'セントヘレナ・アセンションおよびトリスタンダクーニャ'},
    'KNA' => {en: 'Saint Kitts and Nevis', ja: 'セントクリストファー・ネイビス'},
    'LCA' => {en: 'Saint Lucia', ja: 'セントルシア'},
    'SPM' => {en: 'Saint Pierre and Miquelon', ja: 'サンピエール島・ミクロン島'},
    'VCT' => {en: 'Saint Vincent and the Grenadines', ja: 'セントビンセント・グレナディーン'},
    'WSM' => {en: 'Samoa', ja: 'サモア'},
    'SMR' => {en: 'San Marino', ja: 'サンマリノ'},
    'STP' => {en: 'Sao Tome and Principe', ja: 'サントメ・プリンシペ'},
    'SAU' => {en: 'Saudi Arabia', ja: 'サウジアラビア'},
    'SEN' => {en: 'Senegal', ja: 'セネガル'},
    'SRB' => {en: 'Serbia', ja: 'セルビア'},
    'SYC' => {en: 'Seychelles', ja: 'セーシェル'},
    'SLE' => {en: 'Sierra Leone', ja: 'シエラレオネ'},
    'SGP' => {en: 'Singapore', ja: 'シンガポール'},
    'SXM' => {en: 'Sint Maarten (Dutch part)', ja: 'シント・マールテン'},
    'SVK' => {en: 'Slovakia', ja: 'スロバキア'},
    'SVN' => {en: 'Slovenia', ja: 'スロベニア'},
    'SLB' => {en: 'Solomon Islands', ja: 'ソロモン諸島'},
    'SOM' => {en: 'Somalia', ja: 'ソマリア'},
    'ZAF' => {en: 'South Africa', ja: '南アフリカ'},
    'KOR' => {en: 'Republic of Korea', ja: '韓国'},
    'SSD' => {en: 'South Sudan', ja: '南スーダン'},
    'ESP' => {en: 'Spain', ja: 'スペイン'},
    'LKA' => {en: 'Sri Lanka', ja: 'スリランカ'},
    'SDN' => {en: 'Sudan', ja: 'スーダン'},
    'SUR' => {en: 'Suriname', ja: 'スリナム'},
    'SWE' => {en: 'Sweden', ja: 'スウェーデン'},
    'CHE' => {en: 'Switzerland', ja: 'スイス'},
    'SYR' => {en: 'Syria', ja: 'シリア'},
    'TWN' => {en: 'Taiwan', ja: '台湾'},
    'TJK' => {en: 'Tajikistan', ja: 'タジキスタン'},
    'TZA' => {en: 'Tanzania', ja: 'タンザニア'},
    'THA' => {en: 'Thailand', ja: 'タイ'},
    'TLS' => {en: 'Timor', ja: '東ティモール'},
    'TGO' => {en: 'Togo', ja: 'トーゴ'},
    'TKL' => {en: 'Tokelau', ja: 'トケラウ'},
    'TON' => {en: 'Tonga', ja: 'トンガ'},
    'TTO' => {en: 'Trinidad and Tobago', ja: 'トリニダード・トバゴ'},
    'TUN' => {en: 'Tunisia', ja: 'チュニジア'},
    'TUR' => {en: 'Turkey', ja: 'トルコ'},
    'TKM' => {en: 'Turkmenistan', ja: 'トルクメニスタン'},
    'TCA' => {en: 'Turks and Caicos Islands', ja: 'タークス・カイコス諸島'},
    'TUV' => {en: 'Tuvalu', ja: 'ツバル'},
    'UGA' => {en: 'Uganda', ja: 'ウガンダ'},
    'UKR' => {en: 'Ukraine', ja: 'ウクライナ'},
    'ARE' => {en: 'United Arab Emirates', ja: 'アラブ首長国連邦'},
    'GBR' => {en: 'United Kingdom', ja: '英国'},
    'USA' => {en: 'United States of America', ja: '米国'},
    'URY' => {en: 'Uruguay', ja: 'ウルグアイ'},
    'UZB' => {en: 'Uzbekistan', ja: 'ウズベキスタン'},
    'VUT' => {en: 'Vanuatu', ja: 'バヌアツ'},
    'VAT' => {en: 'Vatican', ja: 'バチカン市国'},
    'VEN' => {en: 'Venezuela', ja: 'ベネズエラ'},
    'VNM' => {en: 'Vietnam', ja: 'ベトナム'},
    'WLF' => {en: 'Wallis and Futuna', ja: 'ウォリス・フツナ'},
    'YEM' => {en: 'Yemen', ja: 'イエメン'},
    'ZMB' => {en: 'Zambia', ja: 'ザンビア'},
    'ZWE' => {en: 'Zimbabwe', ja: 'ジンバブエ'},
    'OWID_WRL' => {en: 'World', ja: '世界平均'},
    'OWID_SAM' => {en: 'South America', ja: '南アメリカ'},
    'OWID_OCE' => {en: 'Oceania', ja: 'オセアニア'},
    'OWID_CYN' => {en: 'Northern Cyprus', ja: ''},
    'OWID_NAM' => {en: 'North America', ja: '北アメリカ'},
    'OWID_KOS' => {en: 'Kosovo', ja: 'コソボ'},
    'OWID_INT' => {en: 'International', ja: ''},
    'OWID_EUR' => {en: 'Europe', ja: '欧州'},
    'OWID_EUN' => {en: 'European Union', ja: '欧州連合'},
    'OWID_ASI' => {en: 'Asia', ja: 'アジア'},
    'OWID_AFR' => {en: 'Africa', ja: 'アフリカ'},
    'OWID_HIC' => {en: 'High income', ja: '１高収入の国'},
    'OWID_UMC' => {en: 'Upper middle income', ja: '２中の上の収入国'},
    'OWID_LMC' => {en: 'Lower middle income', ja: '３中の下の収入国'},
    'OWID_LIC' => {en: 'Low income', ja: '４低収入の国'},


    'JP01' => {en: 'Hokkaido', ja: '北海道'},
    'JP02' => {en: 'Aomori', ja: '青森県'},
    'JP03' => {en: 'Iwate', ja: '岩手県'},
    'JP04' => {en: 'Miyagi', ja: '宮城県'},
    'JP05' => {en: 'Akita', ja: '秋田県'},
    'JP06' => {en: 'Yamagata', ja: '山形県'},
    'JP07' => {en: 'Fukushima', ja: '福島県'},
    'JP08' => {en: 'Ibaraki', ja: '茨城県'},
    'JP09' => {en: 'Tochigi', ja: '栃木県'},
    'JP10' => {en: 'Gunma', ja: '群馬県'},
    'JP11' => {en: 'Saitama', ja: '埼玉県'},
    'JP12' => {en: 'Chiba', ja: '千葉県'},
    'JP13' => {en: 'Tokyo', ja: '東京都'},
    'JP14' => {en: 'Kanagawa', ja: '神奈川県'},
    'JP15' => {en: 'Niigata', ja: '新潟県'},
    'JP16' => {en: 'Toyama', ja: '富山県'},
    'JP17' => {en: 'Ishikawa', ja: '石川県'},
    'JP18' => {en: 'Fukui', ja: '福井県'},
    'JP19' => {en: 'Yamanashi', ja: '山梨県'},
    'JP20' => {en: 'Nagano', ja: '長野県'},
    'JP21' => {en: 'Gifu', ja: '岐阜県'},
    'JP22' => {en: 'Shizuoka', ja: '静岡県'},
    'JP23' => {en: 'Aichi', ja: '愛知県'},
    'JP24' => {en: 'Mie', ja: '三重県'},
    'JP25' => {en: 'Shiga', ja: '滋賀県'},
    'JP26' => {en: 'Kyoto', ja: '京都府'},
    'JP27' => {en: 'Osaka', ja: '大阪府'},
    'JP28' => {en: 'Hyogo', ja: '兵庫県'},
    'JP29' => {en: 'Nara', ja: '奈良県'},
    'JP30' => {en: 'Wakayama', ja: '和歌山県'},
    'JP31' => {en: 'Tottori', ja: '鳥取県'},
    'JP32' => {en: 'Shimane', ja: '島根県'},
    'JP33' => {en: 'Okayama', ja: '岡山県'},
    'JP34' => {en: 'Hiroshima', ja: '広島県'},
    'JP35' => {en: 'Yamaguchi', ja: '山口県'},
    'JP36' => {en: 'Tokushima', ja: '徳島県'},
    'JP37' => {en: 'Kagawa', ja: '香川県'},
    'JP38' => {en: 'Ehime', ja: '愛媛県'},
    'JP39' => {en: 'Kochi', ja: '高知県'},
    'JP40' => {en: 'Fukuoka', ja: '福岡県'},
    'JP41' => {en: 'Saga', ja: '佐賀県'},
    'JP42' => {en: 'Nagasaki', ja: '長崎県'},
    'JP43' => {en: 'Kumamoto', ja: '熊本県'},
    'JP44' => {en: 'Oita', ja: '大分県'},
    'JP45' => {en: 'Miyazaki', ja: '宮崎県'},
    'JP46' => {en: 'Kagoshima', ja: '鹿児島県'},
    'JP47' => {en: 'Okinawa', ja: '沖縄県'},

    'US01' => {en: 'Alabama', ja: 'アラバマ州'},
    'US02' => {en: 'Alaska', ja: 'アラスカ州'},
    'US04' => {en: 'Arizona', ja: 'アリゾナ州'},
    'US05' => {en: 'Arkansas', ja: 'アーカンソー州'},
    'US06' => {en: 'California', ja: 'カリフォルニア州'},
    'US08' => {en: 'Colorado', ja: 'コロラド州'},
    'US09' => {en: 'Connecticut', ja: 'コネチカット州'},
    'US10' => {en: 'Delaware', ja: 'デラウェア州'},
    'US11' => {en: 'District of Columbia', ja: 'ワシントン DC'},
    'US12' => {en: 'Florida', ja: 'フロリダ州'},
    'US13' => {en: 'Georgia State', ja: 'ジョージア州'},
    'US15' => {en: 'Hawaii', ja: 'ハワイ州'},
    'US16' => {en: 'Idaho', ja: 'アイダホ州'},
    'US17' => {en: 'Illinois', ja: 'イリノイ州'},
    'US18' => {en: 'Indiana', ja: 'インディアナ州'},
    'US19' => {en: 'Iowa', ja: 'アイオワ州'},
    'US20' => {en: 'Kansas', ja: 'カンザス州'},
    'US21' => {en: 'Kentucky', ja: 'ケンタッキー州'},
    'US22' => {en: 'Louisiana', ja: 'ルイジアナ州'},
    'US23' => {en: 'Maine', ja: 'メイン州'},
    'US24' => {en: 'Maryland', ja: 'メリーランド州'},
    'US25' => {en: 'Massachusetts', ja: 'マサチューセッツ州'},
    'US26' => {en: 'Michigan', ja: 'ミシガン州'},
    'US27' => {en: 'Minnesota', ja: 'ミネソタ州'},
    'US28' => {en: 'Mississippi', ja: 'ミシシッピ州'},
    'US29' => {en: 'Missouri', ja: 'ミズーリ州'},
    'US30' => {en: 'Montana', ja: 'モンタナ州'},
    'US31' => {en: 'Nebraska', ja: 'ネブラスカ州'},
    'US32' => {en: 'Nevada', ja: 'ネバダ州'},
    'US33' => {en: 'New Hampshire', ja: 'ニューハンプシャー州'},
    'US34' => {en: 'New Jersey', ja: 'ニュージャージー州'},
    'US35' => {en: 'New Mexico', ja: 'ニューメキシコ州'},
    'US36' => {en: 'New York', ja: 'ニューヨーク州'},
    'US37' => {en: 'North Carolina', ja: 'ノースカロライナ州'},
    'US38' => {en: 'North Dakota', ja: 'ノースダコタ州'},
    'US39' => {en: 'Ohio', ja: 'オハイオ州'},
    'US40' => {en: 'Oklahoma', ja: 'オクラホマ州'},
    'US41' => {en: 'Oregon', ja: 'オレゴン州'},
    'US42' => {en: 'Pennsylvania', ja: 'ペンシルベニア州'},
    'US44' => {en: 'Rhode Island', ja: 'ロードアイランド州'},
    'US45' => {en: 'South Carolina', ja: 'サウスカロライナ州'},
    'US46' => {en: 'South Dakota', ja: 'サウスダコタ州'},
    'US47' => {en: 'Tennessee', ja: 'テネシー州'},
    'US48' => {en: 'Texas', ja: 'テキサス州'},
    'US49' => {en: 'Utah', ja: 'ユタ州'},
    'US50' => {en: 'Vermont', ja: 'バーモント州'},
    'US51' => {en: 'Virginia', ja: 'バージニア州'},
    'US53' => {en: 'Washington', ja: 'ワシントン州'},
    'US54' => {en: 'West Virginia', ja: 'ウェストバージニア州'},
    'US55' => {en: 'Wisconsin', ja: 'ウィスコンシン州'},
    'US56' => {en: 'Wyoming', ja: 'ワイオミング州'},
    'US60' => {en: 'American Samoa', ja: 'アメリカンサモア'},
    'US66' => {en: 'Guam', ja: 'グアム'},
    'US69' => {en: 'Northern Mariana Islands', ja: '北マリアナ諸島'},
    'US72' => {en: 'Puerto Rico', ja: 'プエルトリコ'},
    'US78' => {en: 'Virgin Islands', ja: 'ヴァージン諸島'},
}

Locs_r = Hash.new
Locs.each do |k, v|
    Locs_r[v[:en]] = k
    Locs_r[v[:ja]] = k
end
