#!/usr/bin/ruby
# coding: utf-8

require 'csv'
require 'date'
require 'optparse'

PARAM_HEADER = %w[
  id method areacode area areaj cutoff age dose quiet_start quiet_end
  points theta k rmse fit_status cohort_size deaths
].freeze
SERIES_HEADER = %w[
  id method areacode area areaj cutoff cweek date age dose cohort_size at_risk
  deaths_week deaths censored_week hazard observed_cumulative_hazard
  adjusted_cumulative_hazard theta
].freeze

def parse_date(value)
  return Date.commercial(Regexp.last_match(1).to_i, Regexp.last_match(2).to_i, 7) if value =~ /\A(\d{4})-W(\d{2})\z/

  Date.parse(value)
end

def model_hazard(time, theta, k)
  return k * time if theta.zero?

  Math.log(1.0 + theta * k * time) / theta
end

def sum_squared_error(points, theta, k)
  points.sum do |time, observed|
    difference = observed - model_hazard(time, theta, k)
    difference * difference
  end
end

# 日本語: 一変数のbounded golden-section searchで外部gemなしに最小値を求める。
# English: Find a bounded one-dimensional minimum without external gems.
def golden_min(left, right, iterations: 72)
  ratio = (Math.sqrt(5.0) - 1.0) / 2.0
  x1 = right - ratio * (right - left)
  x2 = left + ratio * (right - left)
  y1 = yield(x1)
  y2 = yield(x2)
  iterations.times do
    if y1 <= y2
      right = x2
      x2 = x1
      y2 = y1
      x1 = right - ratio * (right - left)
      y1 = yield(x1)
    else
      left = x1
      x1 = x2
      y1 = y2
      x2 = left + ratio * (right - left)
      y2 = yield(x2)
    end
  end
  y1 <= y2 ? [x1, y1] : [x2, y2]
end

def profiled_k(points, theta)
  numerator = points.sum do |time, observed|
    neutralized = theta.zero? ? observed : (Math.exp(theta * observed) - 1.0) / theta
    time * neutralized
  end
  numerator / points.sum { |time, _observed| time * time }
end

def profile_error(points, theta)
  k = profiled_k(points, theta)
  [k, sum_squared_error(points, theta, k)]
end

# 日本語: quiet windowの観測累積hazardへconstant-baseline gamma frailty曲線をNLS fittingする。
# English: Fit the constant-baseline gamma-frailty curve to quiet-window cumulative hazards by NLS.
def fit_gamma(points, theta_max)
  candidates = (0..50).map do |index|
    theta = theta_max * index / 50.0
    k, error = profile_error(points, theta)
    [theta, k, error]
  end
  best_index = candidates.each_index.min_by { |index| candidates[index][2] }
  left = candidates[[best_index - 1, 0].max][0]
  right = candidates[[best_index + 1, candidates.length - 1].min][0]
  if left == right
    theta, k, error = candidates[best_index]
  else
    theta, error = golden_min(left, right, iterations: 48) { |value| profile_error(points, value)[1] }
    k, error = profile_error(points, theta)
  end
  theta_step = [theta_max / 25.0, theta].max
  3.times do
    k, error = golden_min(0.0, [k * 2.0, 1.0e-12].max, iterations: 48) do |value|
      sum_squared_error(points, theta, value)
    end
    theta, error = golden_min([theta - theta_step, 0.0].max,
                              [theta + theta_step, theta_max].min,
                              iterations: 48) do |value|
      sum_squared_error(points, value, k)
    end
    theta_step /= 4.0
  end
  [theta, k, Math.sqrt(error / points.length)]
end

options = {theta_max: 100.0, min_points: 12}
parser = OptionParser.new do |option|
  option.banner = 'Usage: kcor_gamma.rb --quiet-start DATE --quiet-end DATE --output FILE [options] CUMD-WK-G.csv ...'
  option.on('--quiet-start DATE') { |value| options[:quiet_start] = parse_date(value) }
  option.on('--quiet-end DATE') { |value| options[:quiet_end] = parse_date(value) }
  option.on('--theta-max NUMBER', Float) { |value| options[:theta_max] = value }
  option.on('--min-points NUMBER', Integer) { |value| options[:min_points] = value }
  option.on('--output FILE') { |value| options[:output] = value }
  option.on('--series-output FILE') { |value| options[:series_output] = value }
end
parser.parse!
abort parser.to_s unless options.values_at(:quiet_start, :quiet_end, :output).all? && !ARGV.empty?
abort 'quiet end must not precede quiet start' if options[:quiet_end] < options[:quiet_start]
abort 'theta max must be positive' unless options[:theta_max].positive?
abort 'min points must be at least 3' if options[:min_points] < 3

groups = Hash.new { |hash, key| hash[key] = [] }
ARGV.each do |path|
  CSV.foreach(path, headers: true) do |row|
    key = %w[areacode area areaj cutoff age dose].map { |field| row[field] }
    groups[key] << row.to_h
  end
end

fits = {}
skipped = Hash.new(0)
groups.each do |key, rows|
  rows.sort_by! { |row| row['date'] }
  cumulative_hazard = 0.0
  rows.each_with_index do |row, index|
    at_risk = row['at_risk'].to_i
    deaths = row['deaths_week'].to_i
    if at_risk <= 0 || deaths.negative? || deaths >= at_risk
      row[:invalid_hazard] = true
      next
    end
    row[:hazard] = -Math.log(1.0 - deaths.fdiv(at_risk))
    cumulative_hazard += row[:hazard]
    row[:observed_hazard] = cumulative_hazard
    row[:time] = index + 1
  end
  quiet_points = rows.map do |row|
    date = Date.parse(row['date'])
    next if row[:invalid_hazard] || date < options[:quiet_start] || date > options[:quiet_end]

    [row[:time], row[:observed_hazard]]
  end.compact
  if quiet_points.length < options[:min_points]
    skipped[:too_few_points] += 1
    next
  end
  if quiet_points.last[1] <= quiet_points.first[1]
    skipped[:no_deaths] += 1
    next
  end
  theta, k, rmse = fit_gamma(quiet_points, options[:theta_max])
  fits[key] = {theta: theta, k: k, rmse: rmse, points: quiet_points.length, rows: rows}
end

CSV.open(options[:output], 'w') do |csv|
  csv << PARAM_HEADER
  fits.each do |key, fit|
    areacode, area, areaj, cutoff, age, dose = key
    rows = fit[:rows]
    id = [areacode, cutoff, age, dose].join('_')
    fit_status = if fit[:theta] <= options[:theta_max] * 1.0e-6
                   'theta_zero'
                 elsif fit[:theta] >= options[:theta_max] * (1.0 - 1.0e-6)
                   'theta_upper_bound'
                 else
                   'ok'
                 end
    csv << [id, 'gamma_constant_nls_v1', areacode, area, areaj, cutoff, age, dose,
            options[:quiet_start], options[:quiet_end],
            fit[:points], fit[:theta], fit[:k], fit[:rmse], fit_status,
            rows.first['cohort_size'], rows.last['deaths']]
  end
end

if options[:series_output]
  CSV.open(options[:series_output], 'w') do |csv|
    csv << SERIES_HEADER
    fits.each do |key, fit|
      theta = fit[:theta]
      fit[:rows].each do |row|
        next if row[:invalid_hazard]

        observed = row[:observed_hazard]
        adjusted = theta.zero? ? observed : (Math.exp(theta * observed) - 1.0) / theta
        csv << [row['id'], 'gamma_constant_nls_v1'] +
               %w[areacode area areaj cutoff cweek date age dose cohort_size at_risk deaths_week deaths censored_week].map { |field| row[field] } +
               [row[:hazard], observed, adjusted, theta]
      end
    end
  end
end

warn "groups=#{groups.length} fitted=#{fits.length} skipped=#{skipped.map { |key, value| "#{key}:#{value}" }.join(',')}"
