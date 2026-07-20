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

def parse_date(value)
  return nil if value.nil? || value.to_s.strip.empty? || value.to_s.match?(/^(NA|#N\/A|NULL|0)$/i)
  Date.parse(value.to_s)
rescue Date::Error
  nil
end

def safe_ago(date, years)
  date.prev_year(years)
rescue Date::Error
  Date.new(date.year - years, date.month, -1)
end

def age_range(value, open_age_max)
  text = value.to_s.strip.tr('～', '〜').delete('歳 ')
  return [text.to_i, text.to_i] if text.match?(/^\d+$/)
  match = text.match(/^(\d+)[〜~-](\d+)$/)
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
    scan_metadata
    raise '死亡日がないため年齢基準日を決定できません。--age-referenceを指定してください' if !@max_death && !opts[:age_reference]
    @age_reference = opts[:age_reference] || @max_death + 1
  end

  def each_person
    return enum_for(__method__) unless block_given?
    seen = Hash.new(0)
    @stats.clear
    each_raw_row do |row, file_index, row_number, file|
      range = age_range(row['age'], @opts[:open_age_max])
      next unless range
      raw_id = row['id'].to_s.strip
      next if row.headers.include?('id') && !raw_id.match?(/^\d+$/)
      identity = raw_id.empty? ? "#{file_index}:#{row_number}" : raw_id
      seen[identity] += 1
      if seen[identity] > 1 && !@opts[:allow_dup_id]
        raise "重複ID: #{identity} (#{file})"
      end
      @stats[:duplicate_ids] += 1 if seen[identity] > 1
      key = seen[identity] == 1 ? identity : "#{identity}:#{seen[identity]}"
      person = build_person(row, key, identity, range)
      @stats[:rows] += 1
      @stats[:invalid_dose_sequence] += 1 unless person[:valid_doses]
      yield person
    end
  end

  private

  def parse_area(file)
    match = File.basename(file).match(/^(jp\d+)_([^_]+)_(?:all|lives)/)
    raise "入力file名から自治体を判定できません: #{file}" unless match
    @areacode = match[1]
    names = match[2].split('-', 2)
    @areaj = names[0]
    @area = (names[1] || names[0]).tr('-', '/')
  end

  def each_raw_row
    raise '入力CSVとheaderの数が一致しません' unless @files.length == @headers.length
    @files.zip(@headers).each_with_index do |(file, header), file_index|
      names = CSV.parse_line(File.open(header, &:readline).sub("\uFEFF", ''))
      row_number = 0
      CSV.foreach(file, headers: names, row_sep: :auto) do |row|
        row_number += 1
        yield row, file_index, row_number, file
      end
    end
  end

  def scan_metadata
    @max_death = nil
    @max_dose = 0
    each_raw_row do |row, _file_index, _row_number, _file|
      death = parse_date(row['death'])
      death ||= parse_date(row['out']) if row['reason_out'].to_s.include?('死')
      @max_death = death if death && (!@max_death || @max_death < death)
      (1..9).each { |dose| @max_dose = dose if parse_date(row["dose#{dose}"]) && @max_dose < dose }
    end
  end

  def build_person(row, key, identity, range)
    death = parse_date(row['death'])
    reason_out = row['reason_out'].to_s
    out = parse_date(row['out'])
    death ||= out if reason_out.include?('死')
    in_dates = (['in'] + (2..5).map { |index| "in#{index}" }).filter_map { |field| parse_date(row[field]) }
    out_dates = (['out'] + (2..5).map { |index| "out#{index}" }).filter_map { |field| parse_date(row[field]) }
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
      date = parse_date(row["dose#{dose}"])
      next unless date
      doses[dose] = { date: date, pharma: normalize_pharma(row["pharma#{dose}"]), lot: row["lot#{dose}"].to_s }
    end
    person = {
      key: key, source_id: identity, sex: row['sex'].to_s, age_source: row['age'].to_s,
      age_min: range[0], age_max: range[1], death: death,
      age_death: age_range(row['age_death'], @opts[:open_age_max]),
      date_in: date_in, date_out: date_out, doses: doses,
      valid_doses: doses.keys == (1..doses.length).to_a
    }
    min_age, max_age = range
    earliest = safe_ago(@age_reference, max_age + 1) + 1
    latest = safe_ago(@age_reference, min_age)
    if death && person[:age_death]
      dmin, dmax = person[:age_death]
      earliest = [earliest, safe_ago(death, dmax + 1) + 1].max
      latest = [latest, safe_ago(death, dmin)].min
      @stats[:age_constraint_conflicts] += 1 if earliest > latest
    end
    seed = [@opts[:age_seed_version], @areacode, key, person[:age_source]].join(':')
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
    rescue Date::Error
      Date.new(cursor.year, 2, 28)
    end
    next_birthday = begin
      Date.new(cursor.year + 1, person[:birthday].month, person[:birthday].day)
    rescue Date::Error
      Date.new(cursor.year + 1, 2, 28)
    end if next_birthday <= cursor
    finish = [end_date, next_birthday].min
    yield age, cursor, finish
    cursor = finish
  end
end

def emit_aggregate(csv, dataset, step, period, ages, sums)
  ages.each do |age|
    ref = sums[[age, 0]] || { lives: 0, days: 0, deaths: 0 }
    keys = (sums.keys.select { |candidate| candidate[0] == age }.map(&:last) + (0..dataset.max_dose).to_a).uniq
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

def run_personyear(dataset, opts)
  finish = opts[:until] || dataset.age_reference
  definitions = opts[:steps].flat_map do |step|
    periods(opts[:start], finish, step).map do |period_start, period_end, label|
      [step, period_start, period_end, label]
    end
  end
  sums_by_period = definitions.map { Hash.new { |hash, key| hash[key] = { lives: 0, days: 0, deaths: 0 } } }
  dataset.each_person do |person|
    next unless person[:valid_doses]
    definitions.each_with_index do |(_step, period_start, period_end, _label), index|
      sums = sums_by_period[index]
      death = person[:death]
      resident_at_death = death && (!person[:date_in] || person[:date_in] <= death) &&
                          (!person[:date_out] || death <= person[:date_out])
      if resident_at_death && period_start <= death && death < period_end
        dose = dose_at(person, death)
        age_labels(age_on(person[:birthday], death), opts[:ages]).each { |age| sums[[age, dose]][:deaths] += 1 }
      end
      obs_start = [period_start, person[:date_in] || period_start].max
      obs_end = observation_end(person, period_end)
      next unless obs_start < obs_end
      seen = {}
      boundaries = [obs_start, obs_end] + person[:doses].values.map { |dose| dose[:date] }.select { |date| obs_start < date && date < obs_end }
      boundaries.sort.each_cons(2) do |left, right|
        dose = dose_at(person, left)
        each_age_segment(person, left, right) do |age, from, to|
          age_labels(age, opts[:ages]).each do |age_label|
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
      emit_aggregate(csv, dataset, step, label, opts[:ages], sums_by_period[index])
    end
  end
end


def run_afterdose(dataset, opts)
  sums_by_week = opts[:weeks].to_h do |week|
    [week, Hash.new { |hash, key| hash[key] = { lives: 0, days: 0, deaths: 0 } }]
  end
  dataset.each_person do |person|
    next unless person[:valid_doses]
    opts[:weeks].each do |week|
      sums = sums_by_week[week]
      seen = {}
      (0..dataset.max_dose).each do |dose|
        next if dose.positive? && !person[:doses][dose]
        origin = dose.zero? ? opts[:start] : person[:doses][dose][:date]
        left = origin + 7 * (week - 1)
        right = origin + 7 * week
        state_end = dose.zero? ? person.dig(:doses, 1, :date) : person.dig(:doses, dose + 1, :date)
        finish = [right, state_end, person[:death], person[:date_out], opts[:until] || dataset.age_reference].compact.min
        death = person[:death]
        if death && left <= death && death < right && (!state_end || death <= state_end) &&
           (!person[:date_in] || person[:date_in] <= death) && (!person[:date_out] || death <= person[:date_out])
          age_labels(age_on(person[:birthday], death), opts[:ages]).each { |label| sums[[label, dose]][:deaths] += 1 }
        end
        next unless left < finish
        each_age_segment(person, left, finish) do |age, from, to|
          age_labels(age, opts[:ages]).each do |label|
            sums[[label, dose]][:days] += (to - from).to_i
            seen[[label, dose]] = true
          end
        end
      end
      seen.each_key { |key| sums[key][:lives] += 1 }
    end
  end
  CSV.open(opts[:output], 'w') do |csv|
    csv << OUTPUT_HEADER
    opts[:weeks].each do |week|
      emit_aggregate(csv, dataset, 'week', format('W%02d', week), opts[:ages], sums_by_week[week])
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
  dataset.each_person do |person|
    next unless person[:valid_doses]
    death = person[:death]
    next unless death && (!person[:date_out] || death <= person[:date_out])
    cutoffs.each do |cutoff|
      next unless cutoff < death
      dose = dose_at(person, cutoff)
      age_labels(age_on(person[:birthday], cutoff), opts[:ages]).each do |age|
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

def run_anonymize(dataset, opts)
  CSV.open(opts[:output], 'w') do |csv|
    header = %w[id areacode area areaj age date_age cweek_death date_death dose_final]
    (1..9).each { |dose| header.concat(["cweek_dose#{dose}", "date_dose#{dose}", "pharma_dose#{dose}"]) }
    csv << header
    dataset.each_person do |person|
      next unless person[:valid_doses]
      age = age_on(person[:birthday], dataset.age_reference)
      age_label = age >= 100 ? '100+' : format('%02d-%02d', age / 10 * 10, age / 10 * 10 + 9)
      anon = Digest::SHA256.hexdigest([opts[:age_seed_version], dataset.areacode, person[:key]].join(':'))[0, 16]
      row = ["#{dataset.areacode}_#{age_label}_#{anon}", dataset.areacode, dataset.area, dataset.areaj,
             age_label, dataset.age_reference]
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
  allow_dup_id: false, prohibit_reason_in: false, debug: false, report: nil
}

parser = OptionParser.new do |option|
  option.banner = "Usage: #{File.basename($PROGRAM_NAME)} #{command} [options] INPUT.csv [INPUT2.csv]"
  option.on('--headers FILES', Array) { |value| opts[:headers] = value }
  option.on('-o', '--output FILE') { |value| opts[:output] = value }
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
  option.on('--allow-dup-id') { opts[:allow_dup_id] = true }
  option.on('--prohibit-reason-in') { opts[:prohibit_reason_in] = true }
  option.on('--debug') { opts[:debug] = true; Log.level = Logger::DEBUG }
  option.on('--report FILE') { |value| opts[:report] = value }
end
parser.parse!

abort parser.to_s if ARGV.empty? || opts[:headers].empty? || !opts[:output]
dataset = Dataset.new(ARGV, opts[:headers], opts)

case command
when 'personyear' then run_personyear(dataset, opts)
when 'afterdose' then run_afterdose(dataset, opts)
when 'kcor' then run_kcor(dataset, opts)
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
