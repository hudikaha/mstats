#!/usr/bin/ruby
# coding: utf-8

require 'csv'
require 'date'
require 'digest'
require 'json'
require 'optparse'
require_relative '../lib/debug'

COMMANDS = %w[personyear afterdose kcor anonymize excess].freeze
DEFAULT_AGES = %w[00-09 10-19 20-29 30-39 40-49 50-59 60-69 70-79 80-89 90-99 100+ 80+ all].freeze
OUTPUT_HEADER = %w[id areacode area areaj step period age dose lives persondays deaths lb0 ub0 rr0 lbm ubm mortality].freeze

def parse_date(value, iso_week: false)
  return nil if value.nil? || value.to_s.strip.empty? || value.to_s.match?(/^(NA|#N\/A|NULL|0)$/i)
  text = value.to_s.strip
  match = text.match(/\A(\d{4})-(\d{1,2})\z/) if iso_week
  return Date.commercial(match[1].to_i, match[2].to_i, 7) if match
  Date.parse(text)
rescue ArgumentError
  nil
end

# 週次日付を人物とISO週に固有の曜日へ決定的に分散する。
# Deterministically spread a weekly date to a person-and-ISO-week-specific weekday.
def spread_weekly_date(date, seed, areacode, identity)
  return date unless date && seed
  cweek = format('%04d-W%02d', date.cwyear, date.cweek)
  key = [seed, areacode, identity, cweek].join(':')
  Date.commercial(date.cwyear, date.cweek, 1) + Digest::SHA256.hexdigest(key)[0, 16].to_i(16) % 7
end

# 出生年区分をvirtual birthday生成用の年範囲へ変換する。
# Convert a birth-year band into the year range used for virtual birthdays.
def birth_year_range(value)
  match = value.to_s.strip.match(/\A(\d{4})-(\d{4})\z/)
  return nil unless match
  first = match[1].to_i
  last = match[2].to_i
  first <= last ? [first, last] : nil
end

def safe_ago(date, years)
  date.prev_year(years)
rescue ArgumentError
  Date.new(date.year - years, date.month, -1)
end

def age_range(value, open_age_max)
  text = value.to_s.strip.tr('～', '〜').delete('歳 ')
  return [text.to_i, text.to_i] if text.match?(/^-?\d+$/)
  match = text.match(/^(-?\d+)[〜~-](-?\d+)$/)
  return [match[1].to_i, match[2].to_i] if match
  match = text.match(/^(\d+)(?:〜|\+)$/)
  return [match[1].to_i, open_age_max] if match
  nil
end

def birthday_for(reference, min_age, max_age, key)
  earliest = safe_ago(reference, max_age + 1) + 1
  latest = safe_ago(reference, min_age)
  span = (latest - earliest).to_i + 1
  earliest + Digest::SHA256.hexdigest(key)[0, 16].to_i(16) % span
end

def age_on(birthday, date)
  age = date.year - birthday.year
  age -= 1 if ([date.month, date.day] <=> [birthday.month, birthday.day]).negative?
  age
end

def age_labels(age, requested)
  requested.select do |label|
    next true if label == 'all'
    if label.end_with?('+')
      age >= label.to_i
    else
      min, max = label.split('-').map(&:to_i)
      min <= age && age <= max
    end
  end
end

def normalize_pharma(value)
  text = value.to_s.downcase
  return '' if text.empty?
  return 'pfizer' if %w[co01 co08 co09 co16 co20 co21 co23 co24].include?(text)
  return 'moderna' if %w[co02 co15 co19].include?(text)
  return 'astrazeneca' if text == 'co03'
  return 'janssen' if text == 'co04'
  return 'novavax' if %w[co07 co22].include?(text)
  return 'pfizer' if text.match?(/pfizer|ファイザー|コミナティ/)
  return 'moderna' if text.match?(/moderna|モデルナ|スパイクバックス/)
  return 'astrazeneca' if text.match?(/astrazeneca|アストラゼネカ/)
  return 'daiichisankyo' if text.match?(/daiichisankyo|第一三共|ダイチロナ/)
  return 'takeda' if text.match?(/novavax|ノババックス|武田/)
  return 'meiji' if text.match?(/meiji|明治/)
  text
end

class Dataset
  attr_reader :areacode, :area, :areaj, :age_reference, :stats, :max_dose, :max_death

  def initialize(files, headers, opts)
    @stats = Hash.new(0)
    @opts = opts
    @files = files
    @headers = headers
    parse_area(files.first)
    @max_death = nil
    @max_dose = 0
    @metadata_scan = !(opts[:age_reference] && opts[:command] != 'afterdose')
    if @metadata_scan
      progress_start('phase 1/2 metadata')
      scan_metadata
      progress_finish
    end
    if !@max_death && !@source_age_reference && !opts[:age_reference]
      raise '死亡日がないため年齢基準日を決定できません。--age-referenceを指定してください'
    end
    @age_reference = opts[:age_reference] || @source_age_reference || @max_death + 1
  end

  def each_person
    return enum_for(__method__) unless block_given?
    progress_start(@metadata_scan ? "phase 2/2 #{@opts[:command]}" : "phase 1/1 #{@opts[:command]}")
    seen = Hash.new(0)
    @stats.clear
    each_raw_row do |row, file_index, row_number, file|
      progress_tick(row_number) if @files.length == 1
      if @opts[:first_infection_only] && row['infection'].to_s.to_i > 1
        @stats[:repeat_infections] += 1
        next
      end
      years = birth_year_range(row['birth_year'])
      range = if years
                [age_on(Date.new(years[1], 12, 31), @age_reference),
                 age_on(Date.new(years[0], 1, 1), @age_reference)]
              else
                age_range(row['age'], @opts[:open_age_max])
              end
      unless range
        @stats[:missing_age] += 1
        next
      end
      raw_id = row['id'].to_s.strip
      if row.headers.include?('id')
        if raw_id.empty? || (!row.headers.include?('vbirthday') && !raw_id.match?(/^\d+$/))
          @stats[:invalid_id] += 1
          next
        end
      end
      identity = raw_id.empty? ? "#{file_index}:#{row_number}" : raw_id
      seen[identity] += 1
      if seen[identity] > 1 && !@opts[:allow_dup_id]
        raise "重複ID: #{identity} (#{file})"
      end
      @stats[:duplicate_ids] += 1 if seen[identity] > 1
      key = seen[identity] == 1 ? identity : "#{identity}:#{seen[identity]}"
      person = build_person(row, key, identity, range, years)
      if person[:birthday] > @age_reference
        @stats[:future_birthday] += 1
        next
      end
      @max_death = person[:death] if person[:death] && (!@max_death || @max_death < person[:death])
      person[:doses].each_key { |dose| @max_dose = dose if @max_dose < dose }
      @stats[:rows] += 1
      @stats[:deaths] += 1 if person[:death]
      person[:doses].each_key { |dose| @stats["dose#{dose}".to_sym] += 1 }
      @stats[:invalid_dose_sequence] += 1 unless person[:valid_doses]
      @stats[:same_week_doses] += 1 if person[:same_week_doses]
      yield person
    end
    progress_finish
  end

  private

  def parse_area(file)
    if @opts.values_at(:areacode, :area, :areaj).all? { |value| !value.to_s.empty? }
      @areacode = @opts[:areacode]
      @area = @opts[:area]
      @areaj = @opts[:areaj]
      return
    end
    match = File.basename(file).match(/^(jp\d+)_([^_]+)_(?:all|lives)/)
    if match
      @areacode = match[1]
      names = match[2].split('-', 2)
      @areaj = names[0]
      @area = (names[1] || names[0]).tr('-', '/')
      return
    end
    first = first_raw_row(file)
    @areacode = first&.[]('areacode').to_s
    @area = first&.[]('area').to_s
    @areaj = first&.[]('areaj').to_s
    raise "入力file名またはCSVから自治体を判定できません: #{file}" if @areacode.empty?
  end

  def each_raw_row
    if !@headers.empty? && @files.length != @headers.length
      raise '入力CSVとheaderの数が一致しません'
    end
    @files.each_with_index do |file, file_index|
      header = @headers[file_index]
      names = header ? CSV.parse_line(File.open(header, &:readline).sub("\uFEFF", '')) : true
      row_number = 0
      CSV.foreach(file, headers: names, row_sep: :auto) do |row|
        row_number += 1
        next if @opts[:skip_source_header] && row_number == 1
        yield row, file_index, row_number, file
      end
    end
  end

  def first_raw_row(file)
    header = @headers[@files.index(file)] unless @headers.empty?
    names = header ? CSV.parse_line(File.open(header, &:readline).sub("\uFEFF", '')) : true
    CSV.foreach(file, headers: names, row_sep: :auto).first
  end

  def scan_metadata
    @max_death = nil
    @max_dose = 0
    each_raw_row do |row, _file_index, row_number, _file|
      death = parse_input_date(row['death']) || parse_input_date(row['date_death'])
      death ||= parse_input_date(row['out']) if row['reason_out'].to_s.include?('死')
      @max_death = death if death && (!@max_death || @max_death < death)
      date_age = parse_input_date(row['date_age'])
      if date_age
        if @source_age_reference && @source_age_reference != date_age
          raise "date_ageが一致しません: #{@source_age_reference} / #{date_age}"
        end
        @source_age_reference = date_age
      end
      (1..9).each do |dose|
        date = parse_input_date(row["dose#{dose}"]) || parse_input_date(row["date_dose#{dose}"])
        @max_dose = dose if date && @max_dose < dose
      end
      progress_tick(row_number) if @files.length == 1
    end
  end

  # 長時間処理のphaseと人口10%ごとの進捗をstderrへ出す。
  # Report long-running phases and each 10% of the configured population to stderr.
  def progress_start(label)
    @progress_label = label
    @progress_next = 10
    @progress_count = 0
    @progress_started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    warn "#{label} start" if @opts[:progress_total]
  end

  def progress_tick(count)
    total = @opts[:progress_total]
    return unless total && total.positive?
    @progress_count = count
    while @progress_next <= 100 && count * 100 >= total * @progress_next
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @progress_started
      warn format('%s %d%% population=%d/%d elapsed=%.1fs',
                  @progress_label, @progress_next, [count, total].min, total, elapsed)
      @progress_next += 10
    end
  end

  def progress_finish
    return unless @opts[:progress_total]
    progress_tick(@opts[:progress_total])
  end

  # 週単位原dataだけYYYY-WWをISO週の日曜日として読む。
  # Read YYYY-WW as the ISO-week Sunday only for weekly source data.
  def parse_input_date(value)
    parse_date(value, iso_week: @opts[:iso_week_dates])
  end

  def build_person(row, key, identity, range, birth_years = nil)
    death = parse_input_date(row['death']) || parse_input_date(row['date_death'])
    reason_out = row['reason_out'].to_s
    out = parse_input_date(row['out']) || parse_input_date(row['date_out'])
    death ||= out if reason_out.include?('死')
    in_dates = (['in', 'date_in'] + (2..5).map { |index| "in#{index}" }).map { |field| parse_input_date(row[field]) }.compact
    out_dates = (['out', 'date_out'] + (2..5).map { |index| "out#{index}" }).map { |field| parse_input_date(row[field]) }.compact
    in_dates << out if reason_out.include?('転入') && out
    date_in = in_dates.min
    date_out = if reason_out.include?('死') || reason_out.include?('転入')
                 nil
               else
                 out_dates.reject { |date| date == death }.min
               end
    date_out = nil if @opts[:prohibit_reason_in] && reason_out == '転入'
    doses = {}
    (1..9).each do |dose|
      date = parse_input_date(row["dose#{dose}"]) || parse_input_date(row["date_dose#{dose}"])
      next unless date
      pharma = row["pharma#{dose}"] || row["pharma_dose#{dose}"]
      doses[dose] = { date: date, pharma: normalize_pharma(pharma), lot: row["lot#{dose}"].to_s }
    end
    spread_seed = @opts[:spread_weekly_dates]
    death = spread_weekly_date(death, spread_seed, @areacode, identity)
    date_in = spread_weekly_date(date_in, spread_seed, @areacode, identity)
    date_out = spread_weekly_date(date_out, spread_seed, @areacode, identity)
    doses.each_value do |value|
      value[:date] = spread_weekly_date(value[:date], spread_seed, @areacode, identity)
    end
    dose_weeks = doses.values.map { |value| [value[:date].cwyear, value[:date].cweek] }
    same_week_doses = dose_weeks.uniq.length != dose_weeks.length
    person = {
      key: key, source_id: identity, sex: row['sex'].to_s, age_source: row['age'].to_s,
      age_min: range[0], age_max: range[1], death: death,
      age_death: age_range(row['age_death'], @opts[:open_age_max]),
      date_in: date_in, date_out: date_out, doses: doses,
      valid_doses: doses.keys == (1..doses.length).to_a && !same_week_doses,
      same_week_doses: same_week_doses
    }
    virtual_birthday = parse_date(row['vbirthday'])
    if virtual_birthday
      person[:birthday] = virtual_birthday
      return person
    end
    min_age, max_age = range
    if birth_years
      earliest = Date.new(birth_years[0], 1, 1)
      latest = Date.new(birth_years[1], 12, 31)
    else
      earliest = safe_ago(@age_reference, max_age + 1) + 1
      latest = safe_ago(@age_reference, min_age)
    end
    if death && person[:age_death]
      dmin, dmax = person[:age_death]
      earliest = [earliest, safe_ago(death, dmax + 1) + 1].max
      latest = [latest, safe_ago(death, dmin)].min
      @stats[:age_constraint_conflicts] += 1 if earliest > latest
    end
    age_source = birth_years ? row['birth_year'].to_s : person[:age_source]
    seed = [@opts[:age_seed_version], @areacode, key, age_source].join(':')
    person[:birthday] = earliest <= latest ?
      earliest + Digest::SHA256.hexdigest(seed)[0, 16].to_i(16) % ((latest - earliest).to_i + 1) :
      birthday_for(@age_reference, min_age, max_age, seed)
    person
  end
end

def rr_with_ci(events, days, ref_events, ref_days)
  if days.zero?
    mortality = lbm = ubm = '-'
  else
    years = days / 365.0
    rate = events / years
    mortality = (rate * 100_000).round(2)
    if events.zero?
      lbm = 0
      ubm = (-Math.log(0.05) / years * 100_000).round(2)
    else
      se = Math.sqrt(events) / years
      lbm = ((rate - 1.96 * se) * 100_000).round(2)
      ubm = ((rate + 1.96 * se) * 100_000).round(2)
    end
  end
  return ['-', '-', '-', lbm, ubm, mortality] if days.zero? || ref_days.zero? || ref_events.zero?
  rr = (events.to_f / days / (ref_events.to_f / ref_days)).round(4)
  return [rr, '-', '-', lbm, ubm, mortality] if events.zero?
  se = Math.sqrt((1.0 / events - 1.0 / days) + (1.0 / ref_events - 1.0 / ref_days))
  [rr, Math.exp(Math.log(rr) - 1.96 * se).round(4), Math.exp(Math.log(rr) + 1.96 * se).round(4), lbm, ubm, mortality]
end

def periods(start_date, end_date, step)
  return [[start_date, end_date, "#{start_date}--#{end_date - 1}"]] if step == 'all'
  months = Integer(step)
  result = []
  cursor = start_date
  while cursor < end_date
    finish = [cursor.next_month(months), end_date].min
    result << [cursor, finish, format('%04dm%02d', cursor.year, cursor.month)]
    cursor = finish
  end
  result
end

def dose_at(person, date)
  person[:doses].count { |_, value| value[:date] <= date }
end

def observation_end(person, limit)
  [person[:death], person[:date_out], limit].compact.min
end

def each_age_segment(person, start_date, end_date)
  cursor = start_date
  while cursor < end_date
    age = age_on(person[:birthday], cursor)
    next_birthday = begin
      Date.new(cursor.year, person[:birthday].month, person[:birthday].day)
    rescue ArgumentError
      Date.new(cursor.year, 3, 1)
    end
    next_birthday = begin
      Date.new(cursor.year + 1, person[:birthday].month, person[:birthday].day)
    rescue ArgumentError
      Date.new(cursor.year + 1, 3, 1)
    end if next_birthday <= cursor
    finish = [end_date, next_birthday].min
    yield age, cursor, finish
    cursor = finish
  end
end

def emit_aggregate(csv, dataset, step, period, ages, sums)
  ages.each do |age|
    ref = sums[[age, 0]] || { lives: 0, days: 0, deaths: 0 }
    keys = ((0..dataset.max_dose).to_a + sums.keys.select { |candidate| candidate[0] == age }.map(&:last)).uniq
    keys += %w[vaxx all]
    keys.uniq.each do |dose|
      sum = if dose == 'vaxx'
              values = sums.select { |(a, d), _| a == age && d.is_a?(Integer) && d > 0 }.values
              { lives: values.sum { |v| v[:lives] }, days: values.sum { |v| v[:days] }, deaths: values.sum { |v| v[:deaths] } }
            elsif dose == 'all'
              values = sums.select { |(a, d), _| a == age && d.is_a?(Integer) }.values
              { lives: values.sum { |v| v[:lives] }, days: values.sum { |v| v[:days] }, deaths: values.sum { |v| v[:deaths] } }
            else
              sums[[age, dose]] || { lives: 0, days: 0, deaths: 0 }
            end
      rr, lb0, ub0, lbm, ubm, mortality = rr_with_ci(sum[:deaths], sum[:days], ref[:deaths], ref[:days])
      id = [dataset.areacode, step, period, age, dose].join('_')
      csv << [id, dataset.areacode, dataset.area, dataset.areaj, step, period, age, dose,
              sum[:lives], sum[:days], sum[:deaths], lb0, ub0, rr, lbm, ubm, mortality]
    end
  end
end

def run_personyear_legacy(dataset, opts)
  finish = opts[:until] || dataset.age_reference
  definitions = opts[:steps].flat_map do |step|
    periods(opts[:start], finish, step).map do |period_start, period_end, label|
      [step, period_start, period_end, label]
    end
  end
  sums_by_period = definitions.map { Hash.new { |hash, key| hash[key] = { lives: 0, days: 0, deaths: 0 } } }
  age_label_cache = Hash.new { |hash, age| hash[age] = age_labels(age, opts[:ages]) }
  dataset.each_person do |person|
    next unless person[:valid_doses]
    definitions.each_with_index do |(_step, period_start, period_end, _label), index|
      sums = sums_by_period[index]
      death = person[:death]
      resident_at_death = death && (!person[:date_in] || person[:date_in] <= death) &&
                          (!person[:date_out] || death <= person[:date_out])
      if resident_at_death && period_start <= death && death < period_end
        dose = dose_at(person, death)
        age_label_cache[age_on(person[:birthday], death)].each { |age| sums[[age, dose]][:deaths] += 1 }
      end
      obs_start = [period_start, person[:birthday], person[:date_in] || period_start].max
      obs_end = observation_end(person, period_end)
      next unless obs_start < obs_end
      seen = {}
      boundaries = [obs_start, obs_end] + person[:doses].values.map { |dose| dose[:date] }.select { |date| obs_start < date && date < obs_end }
      boundaries.sort.each_cons(2) do |left, right|
        dose = dose_at(person, left)
        each_age_segment(person, left, right) do |age, from, to|
          age_label_cache[age].each do |age_label|
            sums[[age_label, dose]][:days] += (to - from).to_i
            seen[[age_label, dose]] = true
          end
        end
      end
      seen.each_key { |key| sums[key][:lives] += 1 }
    end
  end
  CSV.open(opts[:output], 'w') do |csv|
    csv << OUTPUT_HEADER
    definitions.each_with_index do |(step, _start, _finish, label), index|
      emit_aggregate(csv, dataset, "#{opts[:step_prefix]}#{step}", label, opts[:ages], sums_by_period[index])
    end
  end
end

# 重なりを持たない期間列から、日付を含む期間の添字を返す。
# Return the index of the non-overlapping period containing the date.
def period_index(periods_for_step, date)
  index = periods_for_step.bsearch_index { |(_start, finish, _label)| date < finish }
  return nil unless index && periods_for_step[index][0] <= date
  index
end

# 固定した年齢区分・接種状態の区間を期間別差分配列へ加える。
# Add a fixed age-label and dose-state interval to period difference arrays.
def add_interval_to_periods(metric, periods_for_step, from, to)
  first = periods_for_step.bsearch_index { |(_start, finish, _label)| from < finish }
  return unless first
  last = periods_for_step.bsearch_index { |(start, _finish, _label)| to <= start } || periods_for_step.length
  return if first >= last

  metric[:live_diff][first] += 1
  metric[:live_diff][last] -= 1
  if first == last - 1
    start, finish, = periods_for_step[first]
    metric[:partial_days][first] += ([to, finish].min - [from, start].max).to_i
    return
  end

  first_start, first_finish, = periods_for_step[first]
  metric[:partial_days][first] += (first_finish - [from, first_start].max).to_i
  last_start, last_finish, = periods_for_step[last - 1]
  metric[:partial_days][last - 1] += ([to, last_finish].min - last_start).to_i
  return unless first + 1 < last - 1
  metric[:active_diff][first + 1] += 1
  metric[:active_diff][last - 1] -= 1
end

# 人物の全観察期間を一度だけ接種日と誕生日で分割する。
# Split a person's complete observation interval by dose dates and birthdays only once.
def person_intervals(person, start_date, finish, age_label_cache)
  obs_start = [start_date, person[:birthday], person[:date_in] || start_date].max
  obs_end = observation_end(person, finish)
  return {} unless obs_start < obs_end

  by_key = Hash.new { |hash, key| hash[key] = [] }
  boundaries = [obs_start, obs_end]
  boundaries.concat(person[:doses].values.map { |value| value[:date] }.select { |date| obs_start < date && date < obs_end })
  boundaries.sort.each_cons(2) do |left, right|
    dose = dose_at(person, left)
    each_age_segment(person, left, right) do |age, from, to|
      age_label_cache[age].each do |label|
        intervals = by_key[[label, dose]]
        if intervals.last && intervals.last[1] == from
          intervals.last[1] = to
        else
          intervals << [from, to]
        end
      end
    end
  end
  by_key
end

# 人物時系列と差分配列を使い、期間数に比例する反復を避ける。
# Use person timelines and difference arrays to avoid work proportional to every period.
def run_personyear(dataset, opts)
  return run_personyear_legacy(dataset, opts) if opts[:legacy_personyear]

  finish = opts[:until] || dataset.age_reference
  periods_by_step = opts[:steps].to_h { |step| [step, periods(opts[:start], finish, step)] }
  metrics_by_step = periods_by_step.to_h do |step, step_periods|
    factory = lambda do
      count = step_periods.length
      { live_diff: Array.new(count + 1, 0), active_diff: Array.new(count + 1, 0),
        partial_days: Array.new(count, 0), deaths: Array.new(count, 0) }
    end
    [step, Hash.new { |hash, key| hash[key] = factory.call }]
  end
  age_label_cache = Hash.new { |hash, age| hash[age] = age_labels(age, opts[:ages]) }

  dataset.each_person do |person|
    next unless person[:valid_doses]
    person_intervals(person, opts[:start], finish, age_label_cache).each do |key, intervals|
      periods_by_step.each do |step, step_periods|
        metric = metrics_by_step[step][key]
        intervals.each { |from, to| add_interval_to_periods(metric, step_periods, from, to) }
      end
    end

    death = person[:death]
    resident_at_death = death && (!person[:date_in] || person[:date_in] <= death) &&
                        (!person[:date_out] || death <= person[:date_out])
    next unless resident_at_death && opts[:start] <= death && death < finish
    dose = dose_at(person, death)
    age_label_cache[age_on(person[:birthday], death)].each do |label|
      periods_by_step.each do |step, step_periods|
        index = period_index(step_periods, death)
        metrics_by_step[step][[label, dose]][:deaths][index] += 1 if index
      end
    end
  end

  sums_by_step = {}
  periods_by_step.each do |step, step_periods|
    sums = Array.new(step_periods.length) { Hash.new { |hash, key| hash[key] = { lives: 0, days: 0, deaths: 0 } } }
    metrics_by_step[step].each do |key, metric|
      lives = 0
      active = 0
      step_periods.each_with_index do |(start, finish_date, _label), index|
        lives += metric[:live_diff][index]
        active += metric[:active_diff][index]
        sums[index][key] = {
          lives: lives,
          days: metric[:partial_days][index] + active * (finish_date - start).to_i,
          deaths: metric[:deaths][index]
        }
      end
    end
    sums_by_step[step] = sums
  end

  CSV.open(opts[:output], 'w') do |csv|
    csv << OUTPUT_HEADER
    periods_by_step.each do |step, step_periods|
      step_periods.each_with_index do |(_start, _finish, label), index|
        emit_aggregate(csv, dataset, "#{opts[:step_prefix]}#{step}", label, opts[:ages], sums_by_step[step][index])
      end
    end
  end
end


def run_afterdose(dataset, opts)
  sums_by_week = opts[:weeks].to_h do |week|
    [week, Hash.new { |hash, key| hash[key] = { lives: 0, days: 0, deaths: 0 } }]
  end
  age_label_cache = Hash.new { |hash, age| hash[age] = age_labels(age, opts[:ages]) }
  observation_limit = opts[:until] || dataset.age_reference
  dataset.each_person do |person|
    next unless person[:valid_doses]
    (0..dataset.max_dose).each do |dose|
      next if dose.positive? && !person[:doses][dose]
      origin = dose.zero? ? opts[:start] : person[:doses][dose][:date]
      state_end = dose.zero? ? person.dig(:doses, 1, :date) : person.dig(:doses, dose + 1, :date)
      finish = [state_end, person[:death], person[:date_out], observation_limit].compact.min

      # 日本語: この接種状態と重なる週だけを処理し、全99週の総当たりを避ける。
      # English: Process only weeks overlapping this dose state instead of scanning all 99 weeks.
      if origin < finish
        max_week = ((finish - origin).to_i + 6) / 7
        opts[:weeks].each do |week|
          break if week > max_week
          left = origin + 7 * (week - 1)
          right = [origin + 7 * week, finish].min
          next unless left < right
          sums = sums_by_week[week]
          seen = {}
          each_age_segment(person, left, right) do |age, from, to|
            age_label_cache[age].each do |label|
              sums[[label, dose]][:days] += (to - from).to_i
              seen[[label, dose]] = true
            end
          end
          seen.each_key { |key| sums[key][:lives] += 1 }
        end
      end

      death = person[:death]
      next unless death && origin <= death && (!state_end || death <= state_end) &&
                  (!person[:date_in] || person[:date_in] <= death) && (!person[:date_out] || death <= person[:date_out])
      death_week = ((death - origin).to_i / 7) + 1
      next unless sums_by_week.key?(death_week)
      age_label_cache[age_on(person[:birthday], death)].each do |label|
        sums_by_week[death_week][[label, dose]][:deaths] += 1
      end
    end
  end
  CSV.open(opts[:output], 'w') do |csv|
    csv << OUTPUT_HEADER
    opts[:weeks].each do |week|
      emit_aggregate(csv, dataset, "#{opts[:step_prefix]}week", format('W%02d', week), opts[:ages], sums_by_week[week])
    end
  end
end

def run_kcor(dataset, opts)
  cutoffs = []
  month = opts[:cutoff_start]
  while month <= opts[:cutoff_until]
    cutoffs << Date.commercial(month.cwyear, month.cweek, 7)
    month = month.next_month
  end
  grouped_by_cutoff = cutoffs.to_h { |cutoff| [cutoff, Hash.new { |hash, key| hash[key] = Hash.new(0) }] }
  age_label_cache = Hash.new { |hash, age| hash[age] = age_labels(age, opts[:ages]) }
  dataset.each_person do |person|
    next unless person[:valid_doses]
    death = person[:death]
    next unless death && (!person[:date_out] || death <= person[:date_out])
    cutoffs.each do |cutoff|
      next unless cutoff < death
      dose = dose_at(person, cutoff)
      age_label_cache[age_on(person[:birthday], cutoff)].each do |age|
        sunday = Date.commercial(death.cwyear, death.cweek, 7)
        grouped_by_cutoff[cutoff][[age, dose]][sunday] += 1
      end
    end
  end
  CSV.open(opts[:output], 'w') do |csv|
    csv << %w[id areacode area areaj cutoff cweek date age dose deaths]
    cutoffs.each do |cutoff|
      grouped = grouped_by_cutoff[cutoff]
      last = dataset.max_death && Date.commercial(dataset.max_death.cwyear, dataset.max_death.cweek, 7)
      grouped.each do |(age, dose), by_week|
        cumulative = 0
        date = cutoff + 7
        while last && date <= last
          cumulative += by_week[date]
          if cumulative.positive?
            cweek = format('%04d-W%02d', date.cwyear, date.cweek)
            id = [dataset.areacode, cutoff, cweek, age, dose].join('_')
            csv << [id, dataset.areacode, dataset.area, dataset.areaj, cutoff, cweek, date, age, dose, cumulative]
          end
          date += 7
        end
      end
    end
  end
end

# 固定cohortの週初risk setとeventを、解析versionに依存しない形で出力する。
# Emit weekly risk sets and events for fixed cohorts independently of analysis version.
def run_kcor_risk(dataset, opts)
  cutoffs = []
  month = opts[:cutoff_start]
  while month <= opts[:cutoff_until]
    cutoffs << Date.commercial(month.cwyear, month.cweek, 7)
    month = month.next_month
  end
  groups_by_cutoff = cutoffs.to_h do |cutoff|
    [cutoff, Hash.new { |hash, key| hash[key] = {cohort_size: 0, deaths: Hash.new(0), censored: Hash.new(0)} }]
  end
  age_label_cache = Hash.new { |hash, age| hash[age] = age_labels(age, opts[:ages]) }
  dataset.each_person do |person|
    next unless person[:valid_doses]
    cutoffs.each do |cutoff|
      next if cutoff < person[:birthday]
      next if person[:death] && person[:death] <= cutoff
      next if person[:date_in] && cutoff < person[:date_in]
      next if person[:date_out] && person[:date_out] <= cutoff
      dose = dose_at(person, cutoff)
      age_label_cache[age_on(person[:birthday], cutoff)].each do |age|
        group = groups_by_cutoff[cutoff][[age, dose]]
        group[:cohort_size] += 1
        death = person[:death]
        if death && cutoff < death && (!person[:date_out] || death <= person[:date_out])
          sunday = Date.commercial(death.cwyear, death.cweek, 7)
          group[:deaths][sunday] += 1
        elsif person[:date_out] && cutoff < person[:date_out]
          sunday = Date.commercial(person[:date_out].cwyear, person[:date_out].cweek, 7)
          group[:censored][sunday] += 1
        end
      end
    end
  end

  last = dataset.max_death && Date.commercial(dataset.max_death.cwyear, dataset.max_death.cweek, 7)
  cumulative_csv = opts[:output] && CSV.open(opts[:output], 'w')
  cumulative_csv&.then { |csv| csv << %w[id areacode area areaj cutoff cweek date age dose deaths] }
  begin
    CSV.open(opts[:risk_output], 'w') do |risk_csv|
      risk_csv << %w[id areacode area areaj cutoff cweek date age dose cohort_size at_risk deaths_week deaths censored_week]
      cutoffs.each do |cutoff|
        groups_by_cutoff[cutoff].each do |(age, dose), group|
          at_risk = group[:cohort_size]
          cumulative = 0
          date = cutoff + 7
          while last && date <= last
            weekly_deaths = group[:deaths][date]
            weekly_censored = group[:censored][date]
            cumulative += weekly_deaths
            cweek = format('%04d-W%02d', date.cwyear, date.cweek)
            id = [dataset.areacode, cutoff, cweek, age, dose].join('_')
            risk_csv << [id, dataset.areacode, dataset.area, dataset.areaj, cutoff, cweek, date, age, dose,
                         group[:cohort_size], at_risk, weekly_deaths, cumulative, weekly_censored]
            if cumulative_csv && cumulative.positive?
              cumulative_csv << [id, dataset.areacode, dataset.area, dataset.areaj, cutoff, cweek, date,
                                 age, dose, cumulative]
            end
            at_risk -= weekly_deaths + weekly_censored
            date += 7
          end
        end
      end
    end
  ensure
    cumulative_csv&.close
  end
end

def run_anonymize(dataset, opts)
  CSV.open(opts[:output], 'w') do |csv|
    header = %w[id areacode area areaj age date_age vbirthday cweek_in date_in cweek_out date_out cweek_death date_death dose_final]
    (1..9).each { |dose| header.concat(["cweek_dose#{dose}", "date_dose#{dose}", "pharma_dose#{dose}"]) }
    csv << header
    dataset.each_person do |person|
      next unless person[:valid_doses]
      age = age_on(person[:birthday], dataset.age_reference)
      age_label = age >= 100 ? '100+' : format('%02d-%02d', age / 10 * 10, age / 10 * 10 + 9)
      anon = Digest::SHA256.hexdigest([opts[:age_seed_version], dataset.areacode, person[:key]].join(':'))[0, 16]
      row = ["#{dataset.areacode}_#{age_label}_#{anon}", dataset.areacode, dataset.area, dataset.areaj,
             age_label, dataset.age_reference, person[:birthday]]
      [person[:date_in], person[:date_out]].each do |date|
        if date
          sunday = Date.commercial(date.cwyear, date.cweek, 7)
          row.concat([format('%04d-W%02d', sunday.cwyear, sunday.cweek), sunday])
        else
          row.concat([nil, nil])
        end
      end
      if person[:death]
        sunday = Date.commercial(person[:death].cwyear, person[:death].cweek, 7)
        row.concat([format('%04d-W%02d', sunday.cwyear, sunday.cweek), sunday])
      else
        row.concat([nil, nil])
      end
      row << person[:doses].length
      (1..9).each do |dose|
        value = person[:doses][dose]
        if value
          sunday = Date.commercial(value[:date].cwyear, value[:date].cweek, 7)
          row.concat([format('%04d-W%02d', sunday.cwyear, sunday.cweek), sunday, value[:pharma]])
        else
          row.concat([nil, nil, nil])
        end
      end
      csv << row
    end
  end
end

def run_excess(dataset, opts)
  years = (opts[:start_year]..opts[:until_year]).to_a
  table = years.to_h { |year| [year, { lives: Hash.new(0), deaths: Hash.new(0) }] }
  dataset.each_person do |person|
    years.each do |year|
      date = Date.new(year, 1, 1)
      if (!person[:date_in] || person[:date_in] <= date) && (!person[:date_out] || date < person[:date_out]) &&
         (!person[:death] || date <= person[:death])
        age = [age_on(person[:birthday], date) / 10 * 10, 100].min
        table[year][:lives][age] += 1
      end
      if person[:death]&.year == year
        age = [age_on(person[:birthday], person[:death]) / 10 * 10, 100].min
        table[year][:deaths][age] += 1
      end
    end
  end
  standard = table.fetch(opts[:standard_year])[:lives]
  standard_total = standard.values.sum
  CSV.open(opts[:output], 'w') do |csv|
    csv << %w[year age lives deaths mortality adjusted_deaths adjusted_mortality]
    years.each do |year|
      age_living = table[year][:lives]
      age_deaths = table[year][:deaths]
      adjusted = 0.0
      (0..100).step(10) do |age|
        lives = age_living[age].to_i
        deaths = age_deaths[age].to_i
        mortality = lives.zero? ? nil : (deaths.to_f * 100_000 / lives).round(2)
        adjusted += deaths.to_f * standard[age].to_i / lives if lives.positive?
        csv << [year, age == 100 ? '100+' : format('%02d-%02d', age, age + 9), lives, deaths, mortality, nil, nil]
      end
      total = age_living.values.sum
      total_deaths = age_deaths.values.sum
      csv << [year, 'all', total, total_deaths, total.zero? ? nil : (total_deaths.to_f * 100_000 / total).round(2),
              adjusted.round(2), standard_total.zero? ? nil : (adjusted * 100_000 / standard_total).round(2)]
    end
  end
end

command = ARGV.shift
unless COMMANDS.include?(command)
  warn "Usage: #{File.basename($PROGRAM_NAME)} (#{COMMANDS.join('|')}) [options] INPUT.csv [INPUT2.csv]"
  exit 1
end

opts = {
  headers: [], output: nil, start: Date.new(2021, 2, 1), until: nil,
  steps: %w[1 3 6 all], ages: DEFAULT_AGES.dup, weeks: (1..99).to_a,
  cutoff_start: Date.new(2021, 6, 1), cutoff_until: Date.new(2024, 5, 1),
  start_year: 2010, until_year: 2025, standard_year: 2025,
  age_reference: nil, age_seed_version: 'v1', open_age_max: 124,
  step_prefix: '', allow_dup_id: false, prohibit_reason_in: false, debug: false, report: nil,
  first_infection_only: false, iso_week_dates: false, skip_source_header: false, risk_output: nil,
  spread_weekly_dates: nil, legacy_personyear: false,
  areacode: nil, area: nil, areaj: nil, command: command
}

parser = OptionParser.new do |option|
  option.banner = "Usage: #{File.basename($PROGRAM_NAME)} #{command} [options] INPUT.csv [INPUT2.csv]"
  option.on('--headers FILES', Array) { |value| opts[:headers] = value }
  option.on('-o', '--output FILE') { |value| opts[:output] = value }
  option.on('--risk-output FILE') { |value| opts[:risk_output] = value }
  option.on('--start DATE') { |value| opts[:start] = Date.parse(value) }
  option.on('--until DATE') { |value| opts[:until] = Date.parse(value) }
  option.on('--steps LIST', Array) { |value| opts[:steps] = value }
  option.on('--ages LIST', Array) { |value| opts[:ages] = value }
  option.on('--weeks RANGE') { |value| first, last = value.split('-', 2).map(&:to_i); opts[:weeks] = (first..(last || first)).to_a }
  option.on('--cutoff-start DATE') { |value| opts[:cutoff_start] = Date.parse(value) }
  option.on('--cutoff-until DATE') { |value| opts[:cutoff_until] = Date.parse(value) }
  option.on('--start-year YEAR', Integer) { |value| opts[:start_year] = value }
  option.on('--until-year YEAR', Integer) { |value| opts[:until_year] = value }
  option.on('--standard-year YEAR', Integer) { |value| opts[:standard_year] = value }
  option.on('--age-reference DATE') { |value| opts[:age_reference] = Date.parse(value) }
  option.on('--age-seed-version VERSION') { |value| opts[:age_seed_version] = value }
  option.on('--open-age-max AGE', Integer) { |value| opts[:open_age_max] = value }
  option.on('--step-prefix PREFIX') { |value| opts[:step_prefix] = value }
  option.on('--allow-dup-id') { opts[:allow_dup_id] = true }
  option.on('--prohibit-reason-in') { opts[:prohibit_reason_in] = true }
  option.on('--first-infection-only') { opts[:first_infection_only] = true }
  option.on('--iso-week-dates') { opts[:iso_week_dates] = true }
  option.on('--spread-weekly-dates SEED') { |value| opts[:spread_weekly_dates] = value }
  option.on('--progress-total PEOPLE', Integer) { |value| opts[:progress_total] = value }
  option.on('--legacy-personyear') { opts[:legacy_personyear] = true }
  option.on('--skip-source-header') { opts[:skip_source_header] = true }
  option.on('--areacode CODE') { |value| opts[:areacode] = value }
  option.on('--area NAME') { |value| opts[:area] = value }
  option.on('--areaj NAME') { |value| opts[:areaj] = value }
  option.on('--debug') { opts[:debug] = true; Log.level = Logger::DEBUG }
  option.on('--report FILE') { |value| opts[:report] = value }
end
parser.parse!

abort parser.to_s if ARGV.empty? || (!opts[:output] && !opts[:risk_output])
dataset = Dataset.new(ARGV, opts[:headers], opts)

case command
when 'personyear' then run_personyear(dataset, opts)
when 'afterdose' then run_afterdose(dataset, opts)
when 'kcor' then opts[:risk_output] ? run_kcor_risk(dataset, opts) : run_kcor(dataset, opts)
when 'anonymize' then run_anonymize(dataset, opts)
when 'excess' then run_excess(dataset, opts)
end
Log.info "#{dataset.areacode} rows=#{dataset.stats[:rows]} age_reference=#{dataset.age_reference}"

if opts[:report]
  File.write(opts[:report], JSON.pretty_generate({
    command: command, areacode: dataset.areacode, age_reference: dataset.age_reference,
    input_files: ARGV.map { |file| File.basename(file) }, output: opts[:output], stats: dataset.stats
  }) + "\n")
end
