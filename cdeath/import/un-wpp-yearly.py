#!/usr/bin/env python3
"""Convert UN WPP 2024 population and mortality estimates to annual mstats CSV."""

import argparse
import csv
import gzip
import json
import subprocess
import sys

WPP_URL = "https://population.un.org/wpp/downloads"
WHO_URL = (
    "https://cdn.who.int/media/docs/default-source/gho-documents/"
    "global-health-estimates/gpe_discussion_paper_series_"
    "paper31_2001_age_standardization_rates.pdf"
)
HISTORICAL_END = 2023
NORTHERN_AMERICA = {"BMU", "CAN", "GRL", "SPM", "USA"}

WHO_STANDARD = {
    "age_00_04": 8.86, "age_05_09": 8.69, "age_10_14": 8.60,
    "age_15_19": 8.47, "age_20_24": 8.22, "age_25_29": 7.93,
    "age_30_34": 7.61, "age_35_39": 7.15, "age_40_44": 6.59,
    "age_45_49": 6.04, "age_50_54": 5.37, "age_55_59": 4.55,
    "age_60_64": 3.72, "age_65_69": 2.96, "age_70_74": 2.21,
    "age_75_79": 1.52, "age_80_84": 0.91, "age_85_89": 0.44,
    "age_90_94": 0.15, "age_95_99": 0.04, "age_100plus": 0.005,
}

AGE_FIELDS = [
    "age_all", "age_0", "age_1", "age_2", "age_3", "age_4",
    "age_00_04", "age_05_09", "age_10_14", "age_15_19", "age_20_24",
    "age_25_29", "age_30_34", "age_35_39", "age_40_44", "age_45_49",
    "age_50_54", "age_55_59", "age_60_64", "age_65_69", "age_70_74",
    "age_75_79", "age_80_84", "age_85_89", "age_85plus", "age_90_94",
    "age_95_99", "age_100plus", "age_unknown", "age_elementary",
    "age_junior", "age_00_14", "age_15_64", "age_65_74", "age_75_84",
    "age_05_14", "age_15_29", "age_30_49", "age_50_64",
]
FIELDS = [
    "id", "loc_code", "location", "world_region", "category", "rate", "death_code",
    "death_cause", "algo", "type", "src_url", "date", "year", "sex",
] + AGE_FIELDS


def args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--from-year", type=int, default=1950)
    parser.add_argument("--to-year", type=int, default=2100)
    parser.add_argument("--countries", type=lambda value: set(value.upper().split(",")))
    parser.add_argument("demographic")
    parser.add_argument("historical_deaths_by_age")
    parser.add_argument("projected_deaths_by_age")
    parser.add_argument("historical_exposure_by_age")
    parser.add_argument("projected_exposure_by_age")
    result = parser.parse_args()
    if result.from_year > result.to_year:
        parser.error("--from-year must not exceed --to-year")
    return result


def rows(path):
    with gzip.open(path, "rt", encoding="utf-8-sig", newline="") as handle:
        yield from csv.DictReader(handle)


def age5_rows(paths):
    """Aggregate aligned WPP single-age rows to five-year rows with bounded memory."""
    program = r'''
BEGIN { FS=","; OFS="\t" }
NR == 1 { next }
$4 != "" && $4 != "ISO3_code" {
  year=$(NF-7); age=$(NF-4)+0; group=(age >= 100 ? 100 : int(age/5)*5)
  key=$4 OFS year OFS group
  if (previous != "" && key != previous) {
    print iso, oldyear, oldgroup, male, female, total, age0male, age0female, age0total
    male=female=total=age0male=age0female=age0total=0
  }
  previous=key; iso=$4; oldyear=year; oldgroup=group
  male += $(NF-2); female += $(NF-1); total += $NF
  if (age == 0) { age0male=$(NF-2); age0female=$(NF-1); age0total=$NF }
}
END { if (previous != "") print iso, oldyear, oldgroup, male, female, total, age0male, age0female, age0total }
'''
    gzip_process = subprocess.Popen(["gzip", "-cd", "--", *paths], stdout=subprocess.PIPE)
    awk_process = subprocess.Popen(
        ["awk", program], stdin=gzip_process.stdout, stdout=subprocess.PIPE,
        text=True, encoding="utf-8",
    )
    gzip_process.stdout.close()
    try:
        for line in awk_process.stdout:
            values = line.rstrip("\n").split("\t")
            yield (values[0], int(values[1]), int(values[2]),
                   *(float(value) for value in values[3:]))
    finally:
        awk_process.stdout.close()
        awk_status = awk_process.wait()
        gzip_status = gzip_process.wait()
    if awk_status or gzip_status:
        raise SystemExit(f"failed to aggregate WPP age files: {', '.join(paths)}")


def selected(row, options):
    code = row["ISO3_code"]
    year = int(row["Time"])
    return bool(code) and (not options.countries or code in options.countries) \
        and options.from_year <= year <= options.to_year


def clean(value):
    value = round(value, 2)
    return int(value) if value.is_integer() else value


def record_id(loc, year, category, rate, code, algo, kind, sex):
    return "_".join(map(str, [loc, year, category, rate, code, algo, kind, sex]))


def base(loc, location, world_region, year, sex, category, kind, rate="", code="",
         src_urls=None, algo=""):
    return {
        "id": record_id(loc, year, category, rate, code, algo, kind, sex),
        "loc_code": loc, "location": location, "world_region": world_region,
        "category": category,
        "rate": rate, "death_code": code,
        "death_cause": "All causes" if code == "allcause" else "",
        "algo": algo, "type": kind, "src_url": json.dumps(src_urls or [WPP_URL]),
        "date": f"{year:04d}-01-01", "year": year, "sex": sex,
    }


def age_field(age):
    if age >= 100:
        return "age_100plus"
    start = age // 5 * 5
    return f"age_{start:02d}_{start + 4:02d}"


def empty_totals():
    return {field: 0.0 for field in list(WHO_STANDARD) + ["age_0", "age_all"]}


def main():
    options = args()
    writer = csv.DictWriter(sys.stdout, fieldnames=FIELDS, lineterminator="\n")
    writer.writeheader()
    indicators = {}
    locations = {}

    # WPPの親子関係から、各国が属する最上位の地理地域を求める。
    # Resolve each country's top-level geographic region from the WPP hierarchy.
    hierarchy = {}
    for source in rows(options.demographic):
        loc_id = source["LocID"]
        hierarchy[loc_id] = {
            "parent": source["ParentID"], "name": source["Location"],
            "type": source["LocTypeName"],
        }
    def world_region(source):
        if source["ISO3_code"] in NORTHERN_AMERICA:
            return "Northern America"
        node = hierarchy.get(source["ParentID"])
        while node:
            if node["type"] == "Geographic region":
                return node["name"]
            node = hierarchy.get(node["parent"])
        return "Other"

    # 年央人口を人口recordとして出力する。
    # Emit mid-year population records.
    for source in rows(options.demographic):
        if not selected(source, options):
            continue
        loc, location, year = source["ISO3_code"].lower(), source["Location"], int(source["Time"])
        iso = source["ISO3_code"]
        locations[iso] = (location, world_region(source))
        kind = "unwpp2024est" if year <= HISTORICAL_END else "unwpp2024prj"
        for sex, pop_col, death_col in (
            ("both", "TPopulation1July", "Deaths"),
            ("male", "TPopulationMale1July", "DeathsMale"),
            ("female", "TPopulationFemale1July", "DeathsFemale"),
        ):
            population = float(source[pop_col]) * 1000
            deaths = float(source[death_col]) * 1000
            indicators[(loc, year, sex)] = (population, deaths)
            pop = base(loc, location, locations[iso][1], year, sex, "pop", kind)
            pop["age_all"] = clean(population)
            writer.writerow(pop)

    def flush(key, totals):
        if key is None:
            return
        loc, location, world_region, year = key
        for sex in ("both", "male", "female"):
            death_age = totals[sex]["death"]
            exposure_age = totals[sex]["exposure"]
            midyear_population, total_deaths = indicators[(loc, year, sex)]
            kind = "unwpp2024est" if year <= HISTORICAL_END else "unwpp2024prj"
            exposure_kind = "unwpp2024expest" if year <= HISTORICAL_END else "unwpp2024expprj"
            death = base(loc, location, world_region, year, sex, "death", kind, code="allcause")
            death.update({field: clean(value * 1000) for field, value in death_age.items()})
            death["age_all"] = clean(total_deaths)
            writer.writerow(death)
            exposure = base(loc, location, world_region, year, sex, "pop", exposure_kind)
            exposure.update({field: clean(value * 1000) for field, value in exposure_age.items()})
            writer.writerow(exposure)
            rates = {
                field: death_age[field] * 100_000 / exposure_age[field]
                for field in WHO_STANDARD if exposure_age[field] > 0
            }
            rates["age_0"] = death_age["age_0"] * 100_000 / exposure_age["age_0"]
            rates["age_all"] = total_deaths * 100_000 / midyear_population
            crude = base(loc, location, world_region, year, sex, "death", kind,
                         rate="crude", code="allcause")
            crude.update({field: clean(value) for field, value in rates.items()})
            writer.writerow(crude)
            # 丸めによりpopulation exposureが0の階級があればASRを欠測とする。
            # Omit ASR when rounded population exposure is zero in any standard age group.
            if all(field in rates for field in WHO_STANDARD):
                asr_value = sum(rates[field] * weight for field, weight in WHO_STANDARD.items()) \
                    / sum(WHO_STANDARD.values())
                asr = base(loc, location, world_region, year, sex, "death", kind,
                           rate="asr", code="allcause", src_urls=[WPP_URL, WHO_URL],
                           algo="whostd")
                asr["age_all"] = clean(asr_value)
                writer.writerow(asr)

    # 単年齢死亡数と年間population exposureを逐次結合して5歳階級化する。
    # Stream-join deaths and exposure by single age and aggregate to five-year groups.
    current_key = None
    totals = None
    death_iter = age5_rows([
        options.historical_deaths_by_age, options.projected_deaths_by_age,
    ])
    exposure_iter = age5_rows([
        options.historical_exposure_by_age, options.projected_exposure_by_age,
    ])
    sentinel = object()
    while True:
        death_source = next(death_iter, sentinel)
        exposure_source = next(exposure_iter, sentinel)
        if death_source is sentinel or exposure_source is sentinel:
            if death_source is not exposure_source:
                raise SystemExit("WPP age files have different row counts")
            break
        death_key = death_source[:3]
        exposure_key = exposure_source[:3]
        if death_key != exposure_key:
            raise SystemExit(f"WPP age files are not aligned: {death_key} != {exposure_key}")
        iso, year, age = death_key
        if iso not in locations or not options.from_year <= year <= options.to_year:
            continue
        location, world_region = locations[iso]
        key = (iso.lower(), location, world_region, year)
        if key != current_key:
            flush(current_key, totals)
            current_key = key
            totals = {
                sex: {"death": empty_totals(), "exposure": empty_totals()}
                for sex in ("both", "male", "female")
            }
        field = age_field(age)
        for sex, death_pos, exposure_pos in (
            ("both", 5, 5),
            ("male", 3, 3),
            ("female", 4, 4),
        ):
            deaths, exposure = death_source[death_pos], exposure_source[exposure_pos]
            totals[sex]["death"][field] += deaths
            totals[sex]["death"]["age_all"] += deaths
            totals[sex]["exposure"][field] += exposure
            totals[sex]["exposure"]["age_all"] += exposure
            if age == 0:
                age0_pos = {"male": 6, "female": 7, "both": 8}[sex]
                totals[sex]["death"]["age_0"] += death_source[age0_pos]
                totals[sex]["exposure"]["age_0"] += exposure_source[age0_pos]
    flush(current_key, totals)


if __name__ == "__main__":
    main()
