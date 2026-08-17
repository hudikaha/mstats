# coding: utf-8

# 死亡者の接種歴欠落を仮定し、集計済み死亡数を人日比で再配分する。
# Reallocate aggregated deaths by person-day shares under assumed missing vaccination histories.
module MissingHistory
  extend self

  RATES = [0, 1, 5, 10, 20].freeze

  def rr_with_ci(events_i, total_i, events_c, total_c)
    pi = if total_i.to_f.zero?
           '-'
         elsif events_i.is_a?(Integer) && total_i.is_a?(Integer)
           events_i * 365 * 100_000 / total_i
         else
           events_i.to_f * 365 * 100_000 / total_i.to_f
         end
    ei = events_i.to_f
    ni = total_i.to_f
    ec = events_c.to_f
    nc = total_c.to_f
    return ['-', '-', '-', pi] if ni.zero? || nc.zero?

    p1 = ei / ni
    p2 = ec / nc
    return ['-', '-', '-', pi] if p2.zero?

    rr = (p1 / p2).round(4)
    return [rr, '-', '-', pi] if ei.zero? || ec.zero?

    variance = (1 / ei - 1 / ni) + (1 / ec - 1 / nc)
    return [rr, '-', '-', pi] unless variance.positive?

    se_log_rr = Math.sqrt(variance)
    lower = Math.exp(Math.log(rr) - 1.96 * se_log_rr)
    upper = Math.exp(Math.log(rr) + 1.96 * se_log_rr)
    return [rr, '-', '-', pi] unless lower.finite? && upper.finite?

    lower = lower.round(4)
    upper = upper.round(4)
    [rr, lower, upper, pi]
  end

  def build_missing_history_scenarios(observed)
    scenarios = {}
    groups = observed.group_by do |_id, datum|
      [datum[:loc], datum[:step].to_s, datum[:period], datum[:age]]
    end

    RATES.each do |rate|
      groups.each_value do |entries|
        originals = entries.to_h
        copies = originals.to_h do |id, datum|
          [id, datum.dup.tap { |copy| copy[:miss] = rate }]
        end

        redistribute_missing_deaths(copies, rate) if rate.positive?
        copies.each do |id, datum|
          original = originals.fetch(id)
          raise '接種歴欠落補正で人日が変化しました' unless datum[:persondays] == original[:persondays]

          scenarios["#{id}__miss#{rate}"] = datum
        end
      end
    end
    scenarios
  end

  private

  def redistribute_missing_deaths(copies, rate)
    numeric = copies.values.select { |datum| datum[:dose].to_s.match?(/\A\d+\z/) }
    unvaccinated = numeric.find { |datum| datum[:dose].to_s == '0' }
    vaccinated = numeric.select { |datum| datum[:dose].to_i.positive? }
    vaccinated_days = vaccinated.sum { |datum| datum[:persondays].to_f }
    return unless unvaccinated && vaccinated_days.positive?

    moved = unvaccinated[:deaths].to_f * rate / 100.0
    before_total = numeric.sum { |datum| datum[:deaths].to_f }
    unvaccinated[:deaths] = unvaccinated[:deaths].to_f - moved
    vaccinated.each do |datum|
      datum[:deaths] = datum[:deaths].to_f + moved * datum[:persondays].to_f / vaccinated_days
    end

    numeric_by_dose = numeric.to_h { |datum| [datum[:dose].to_s, datum] }
    all = copies.values.find { |datum| datum[:dose].to_s == 'all' }
    vaxx = copies.values.find { |datum| datum[:dose].to_s == 'vaxx' }
    all[:deaths] = numeric.sum { |datum| datum[:deaths].to_f } if all
    vaxx[:deaths] = vaccinated.sum { |datum| datum[:deaths].to_f } if vaxx

    (numeric + [all, vaxx].compact).each do |datum|
      ref = numeric_by_dose.fetch('0')
      datum[:rr0], datum[:lb0], datum[:ub0], datum[:mortality] =
        rr_with_ci(datum[:deaths], datum[:persondays], ref[:deaths], ref[:persondays])
    end

    after_total = numeric.sum { |datum| datum[:deaths].to_f }
    raise '接種歴欠落補正で死亡総数が変化しました' if (before_total - after_total).abs > 1e-8
    raise '接種歴欠落補正で死亡数が負になりました' if numeric.any? { |datum| datum[:deaths].to_f.negative? }
  end
end
