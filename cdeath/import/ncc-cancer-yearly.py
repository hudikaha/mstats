#!/usr/bin/env python3
"""Convert National Cancer Center Japan XLS tables to mstats2026 yearly CSV."""

import argparse
import csv
import io
import os
import tempfile

import xlrd


FIELDS = [
    "id", "loc", "area", "areaj", "category", "rate", "dcode",
    "death_cause", "algo", "type", "src_url", "date", "year", "sex",
    "age_all", "age_0", "age_1", "age_2", "age_3", "age_4",
    "age_00_04", "age_05_09", "age_10_14", "age_15_19", "age_20_24",
    "age_25_29", "age_30_34", "age_35_39", "age_40_44", "age_45_49",
    "age_50_54", "age_55_59", "age_60_64", "age_65_69", "age_70_74",
    "age_75_79", "age_80_84", "age_85_89", "age_85plus", "age_90_94",
    "age_95_99", "age_100plus", "age_unknown", "age_elementary",
    "age_junior", "age_00_14", "age_15_64", "age_65_74", "age_75_84",
    "age_05_14", "age_15_29", "age_30_49", "age_50_64",
]

SITE_CODES = {
    1: ("allcancer", "全部位"),
    3: ("c00-c14", "口腔・咽頭"),
    4: ("c15", "食道"),
    5: ("c16", "胃"),
    6: ("c18", "結腸"),
    7: ("c19-c20", "直腸"),
    8: ("c22", "肝臓"),
    9: ("c23-c24", "胆嚢・胆管"),
    10: ("c25", "膵臓"),
    11: ("c32", "喉頭"),
    12: ("c33-c34", "肺"),
    13: ("c43-c44", "皮膚"),
    14: ("c50", "乳房"),
    16: ("c53-c55", "子宮"),
    17: ("c53", "子宮頸部"),
    18: ("c54", "子宮体部"),
    19: ("c56", "卵巣"),
    20: ("c61", "前立腺"),
    21: ("c67", "膀胱"),
    22: ("c64-c66c68", "腎・尿路（膀胱を除く）"),
    23: ("c70-c72", "脳・中枢神経系"),
    24: ("c73", "甲状腺"),
    25: ("c81-c85c96", "悪性リンパ腫"),
    26: ("c88-c90", "多発性骨髄腫"),
    27: ("c91-c95", "白血病"),
    67: ("c18-c20", "大腸"),
}

SEXES = {"男女計": "both", "総数": "both", "男": "male", "女": "female"}

AGE_FIELDS = {
    "全年齢": "age_all",
    "0-4歳": "age_00_04", "5-9歳": "age_05_09", "10-14歳": "age_10_14",
    "15-19歳": "age_15_19", "20-24歳": "age_20_24", "25-29歳": "age_25_29",
    "30-34歳": "age_30_34", "35-39歳": "age_35_39", "40-44歳": "age_40_44",
    "45-49歳": "age_45_49", "50-54歳": "age_50_54", "55-59歳": "age_55_59",
    "60-64歳": "age_60_64", "65-69歳": "age_65_69", "70-74歳": "age_70_74",
    "75-79歳": "age_75_79", "80-84歳": "age_80_84", "85-89歳": "age_85_89",
    "85歳以上": "age_85plus", "90-94歳": "age_90_94", "95-99歳": "age_95_99",
    "100歳以上": "age_100plus", "年齢不詳": "age_unknown", "不詳": "age_unknown",
}

SOURCE_URL = "https://ganjoho.jp/reg_stat/statistics/data/dl/index.html"


def open_workbook(path, encrypted):
    if not encrypted:
        return xlrd.open_workbook(path)

    import msoffcrypto

    with open(path, "rb") as source, tempfile.NamedTemporaryFile(suffix=".xls") as decrypted:
        office = msoffcrypto.OfficeFile(source)
        office.load_key(password="VelvetSweatshop")
        office.decrypt(decrypted)
        decrypted.flush()
        return xlrd.open_workbook(decrypted.name)


def integer(value):
    if value in (None, ""):
        return ""
    number = float(value)
    if not number.is_integer():
        raise ValueError(f"count is not integral: {value!r}")
    return int(number)


def record_id(row):
    parts = [
        row["loc"], row["year"], row["category"], row["rate"], row["dcode"],
        row["algo"], row["type"], row["sex"],
    ]
    if any("_" in str(part) for part in parts):
        raise ValueError(f"ID component contains underscore: {parts!r}")
    return "_".join(str(part) for part in parts)


def base_row(year, category, series_type, site_code, sex, rate="", algo=""):
    code, name = SITE_CODES[site_code]
    row = {field: "" for field in FIELDS}
    row.update(
        loc="jpn", area="Japan", areaj="日本", category=category, rate=rate,
        dcode=code, death_cause=name, algo=algo, type=series_type,
        src_url=SOURCE_URL, date=f"{year:04d}-01-01", year=year, sex=sex,
    )
    row["id"] = record_id(row)
    return row


def count_rows(workbook, category, series_type, years, codes):
    sheet = workbook.sheet_by_name("number")
    headers = [str(value).strip() for value in sheet.row_values(0)]
    site_col = headers.index("コード")
    sex_col = headers.index("性別")
    year_col = headers.index("死亡年") if "死亡年" in headers else headers.index("診断年")
    age_columns = [(index, AGE_FIELDS[label]) for index, label in enumerate(headers) if label in AGE_FIELDS]

    for row_number in range(1, sheet.nrows):
        site_code = int(float(sheet.cell_value(row_number, site_col)))
        if site_code not in SITE_CODES:
            continue
        code = SITE_CODES[site_code][0]
        if codes and code not in codes:
            continue
        year = int(float(sheet.cell_value(row_number, year_col)))
        if years and year not in years:
            continue
        sex = SEXES[str(sheet.cell_value(row_number, sex_col)).strip()]
        row = base_row(year, category, series_type, site_code, sex)
        for column, field in age_columns:
            row[field] = integer(sheet.cell_value(row_number, column))
        yield row


def asr_rows(workbook, category, series_type, years, codes):
    sheet = workbook.sheet_by_name("asr")
    headers = sheet.row_values(0)
    site_col = headers.index("コード")
    sex_col = headers.index("性別")
    standard_col = headers.index("標準人口")
    year_columns = [(index, int(float(value))) for index, value in enumerate(headers) if isinstance(value, float)]

    for row_number in range(1, sheet.nrows):
        if str(sheet.cell_value(row_number, standard_col)).strip() != "世界人口":
            continue
        site_code = int(float(sheet.cell_value(row_number, site_col)))
        if site_code not in SITE_CODES:
            continue
        code = SITE_CODES[site_code][0]
        if codes and code not in codes:
            continue
        sex = SEXES[str(sheet.cell_value(row_number, sex_col)).strip()]
        for column, year in year_columns:
            if years and year not in years:
                continue
            value = sheet.cell_value(row_number, column)
            if value in (None, "", "-"):
                continue
            row = base_row(year, category, series_type, site_code, sex, rate="asr", algo="whostd")
            row["age_all"] = float(value)
            yield row


def parse_int_set(value):
    if not value:
        return set()
    return {int(part) for part in value.split(",")}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--category", choices=("death", "incidence"), required=True)
    parser.add_argument("--type", required=True, dest="series_type")
    parser.add_argument("--encrypted", action="store_true")
    parser.add_argument("--years", help="comma-separated test years")
    parser.add_argument("--codes", help="comma-separated canonical cancer codes")
    parser.add_argument("source")
    args = parser.parse_args()

    years = parse_int_set(args.years)
    codes = set(args.codes.split(",")) if args.codes else set()
    unknown = codes - {code for code, _name in SITE_CODES.values()}
    if unknown:
        parser.error(f"unknown codes: {','.join(sorted(unknown))}")

    workbook = open_workbook(args.source, args.encrypted)
    rows = list(count_rows(workbook, args.category, args.series_type, years, codes))
    rows.extend(asr_rows(workbook, args.category, args.series_type, years, codes))
    rows.sort(key=lambda row: row["id"])

    writer = csv.DictWriter(os.sys.stdout, fieldnames=FIELDS, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)


if __name__ == "__main__":
    main()
