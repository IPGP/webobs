import csv
import os
import sqlite3


def get_sqlite_data_with_date(
    db_path, table_name, columns, fk_date_col, date_table, date_col
):
    """
    Fetch data from SQLite, joining with the date table to get the actual date value.
    Returns data sorted by the actual date.
    """
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Get column information for the table
    cursor.execute(f"PRAGMA table_info({table_name})")
    # Extract column names starting with 'input'
    columns = [x for x in columns if x not in ["time", "valid"]]

    # Build the columns list, replacing the foreign key with the actual date column
    cols = []
    for col in columns:
        if col == fk_date_col:
            cols.append(f"{date_table}.{date_col} as {fk_date_col}")
        else:
            cols.append(f"{table_name}.{col}")
    query = f"""
        SELECT {', '.join(cols)}
        FROM {table_name}
        JOIN {date_table} ON {table_name}.{fk_date_col} = {date_table}.id
    """
    # print(query)
    cursor.execute(query)
    rows = cursor.fetchall()
    conn.close()
    return sorted(rows)


def get_csv_data_sorted(mapping, csv_path, columns):
    """Fetch data from the text file, sorted by the date column."""

    with open(csv_path, "r", encoding="ISO-8859-1") as f:
        reader = csv.DictReader(f, delimiter="|")
        cols = reader.fieldnames
        date_column = next(k for k, v in mapping.items() if v == "edate")
        time_column = next(k for k, v in mapping.items() if v == "time")
        comment_column = next(k for k, v in mapping.items() if v == "comment")
        valid_column = next(k for k, v in mapping.items() if v == "valid")
        operators_column = next((k for k, v in mapping.items() if v == "operators"), "")
        print("Date column: " + date_column)
        print("Time column: " + time_column)
        print("Comment column: " + comment_column)
        print("Valid column: " + valid_column)
        print("CSV columns: " + ", ".join(cols) + "\n")
        data = [row for row in reader]

    result = []
    for row in data:
        line = []
        for col in columns:
            if col == date_column:
                line.append(f"{row[date_column]} {row[time_column]}".strip())
            elif col == comment_column:
                line.append(f"{row[comment_column]} {row[valid_column]}".strip())
            elif col == operators_column:
                line.append(f"{row[col].replace('+',',')}")
            elif col == "F1":  # for EXTENSO
                for i in range(1, 10):
                    d = ""
                    f = row[f"F{i}"]
                    c = row[f"C{i}"]
                    if f:
                        try:
                            d = str(round(float(f) + (float(c) if c else 0), 6))
                            d = d[:-2] if d.endswith(".0") else d
                        except Exception as e:
                            print(f"Column name: {col};", e)
                    line.extend([str(d), row[f"V{i}"]])
            elif col in [f"{fl}{x}" for fl in ["F", "W"] for x in range(1, 10)]:
                continue  # for EXTENSO
            else:
                line.append(row[col])
        result.append(line)
    return sorted(result)


def get_mapping(form):
    """
    Function to map the CSV columns to the database columns.
    form: the form we are working on.
    """

    ## ---------------------------------- EAUX ----------------------------------
    ## ID|Date|Heure|Site|Type|Tair (°C)|Teau (°C)|pH|Débit (l/min)|Cond. (°C)|Niveau (m)|Li|Na|K |Mg|Ca|F |Cl|Br|NO3|SO4|HCO3|I |SiO2|d13C|d18O|dD|Remarques|Valider
    ## 1 |2   |3    |4   |5   |6        |7        |8 |9            |10        |11        |12|13|14|15|16|17|18|19|20 |21 |22  |23|24  |25  |26  |27|28       |29
    if form == "EAUX":

        ## Mapping table: key = name in the file, value = name in the SQLite table
        mapping = {
            "Date": "edate",  ## This is a foreign key
            "Site": "node",
            "Type": "input01",
            "Tair (°C)": "input02",
            "Teau (°C)": "input03",
            "pH": "input04",
            "Débit (l/min)": "input05",
            "Cond. (°C)": "input06",
            "Niveau (m)": "input07",
            "Li": "input08",
            "Na": "input09",
            "K": "input10",
            "Mg": "input11",
            "Ca": "input12",
            "F": "input13",
            "Cl": "input14",
            "Br": "input15",
            "NO3": "input16",
            "SO4": "input17",
            "HCO3": "input18",
            "I": "input19",
            "SiO2": "input20",
            "d13C": "input21",
            "d18O": "input22",
            "dD": "input23",
            "Remarques": "comment",
            "Valider": "valid",
            "Heure": "time",
        }

    ## ---------------------------------- RAINWATER ----------------------------------
    ## ID|Date2|Time2|Site|Date1|Time1|Volume (ml)|Diameter (cm)|pH|Cond. (°C)|Na (ppm)|K (ppm)|Mg (ppm)|Ca (pmm)|HCO3 (ppm)|Cl (ppm)|SO4 (ppm)|dD (?)|d18O (?)|Comments|Valid
    ## id|trash|quality|node|edate|sdate|operators|comment|tsupd|userupd|input01|input02|input03|input04|input05|input06|input07|input08|input09|input10|input11|input12|input13

    if form == "RAINWATER":

        ## Mapping table: key = name in the file, value = name in the SQLite table
        mapping = {
            "Date2": "edate",  ## This is a foreign key
            "Site": "node",
            "Volume (ml)": "input01",
            "Diameter (cm)": "input02",
            "pH": "input03",
            "Cond. (°C)": "input04",
            "Na (ppm)": "input05",
            "K (ppm)": "input06",
            "Mg (ppm)": "input07",
            "Ca (pmm)": "input08",
            "HCO3 (ppm)": "input09",
            "Cl (ppm)": "input10",
            "SO4 (ppm)": "input11",
            "dD (?)": "input12",
            "d18O (?)": "input13",
            "Comments": "comment",
            "Valid": "valid",
            "Time2": "time",
        }

    ## ---------------------------------- SOILSOLUTION ----------------------------------
    ## ID|Date2|Time2|Site|Date1|Time1|Depth (cm)|Level|pH|Cond. (µS)|Na (ppm)|K (ppm)|Mg (ppm)|Ca (pmm)|HCO3 (ppm)|Cl (ppm)|NO3 (ppm)|SO4 (ppm)|SiO2 (ppm)|DOC (ppm)|Comments|Valid
    ## id|trash|quality|node|edate|sdate|operators|comment|tsupd|userupd|input01|input02|input03|input04|input05|input06|input07|input08|input09|input10|input11|input12|input13|input14

    elif form == "SOILSOLUTION":

        ## Mapping table: key = name in the file, value = name in the SQLite table
        mapping = {
            "Date2": "edate",  ## This is a foreign key
            "Site": "node",
            "Depth (cm)": "input01",
            "Level": "input02",
            "pH": "input03",
            "Cond. (µS)": "input04",
            "Na (ppm)": "input05",
            "K (ppm)": "input06",
            "Mg (ppm)": "input07",
            "Ca (pmm)": "input08",
            "HCO3 (ppm)": "input09",
            "Cl (ppm)": "input10",
            "NO3 (ppm)": "input11",
            "SO4 (ppm)": "input12",
            "SiO2 (ppm)": "input13",
            "DOC (ppm)": "input14",
            "Comments": "comment",
            "Valid": "valid",
            "Time2": "time",
        }

    ## ---------------------------------- RIVERS ----------------------------------
    ## ID|Date|Hour|Site|Level|Type|Flask|Twater (°C)|Suspended Load|pH|Conductivity at 25°C|Conductivity|Na|K|Mg|Ca|HCO3|Cl|SO4|SiO2|DOC|POC|Comment|Validate
    ## id|trash|quality|node|edate|sdate|operators|comment|tsupd|userupd|input01|input02|input03|input04|input05|input06|input07|input08|input09|input10|input11|input12|input13|input14|input15|input16|input17|input18

    elif form == "RIVERS":

        ## Mapping table: key = name in the file, value = name in the SQLite table
        mapping = {
            "Date": "edate",  ## This is a foreign key
            "Site": "node",
            "Level": "input01",
            "Type": "input02",
            "Flask": "input03",
            "Twater (°C)": "input04",
            "Suspended Load": "input05",
            "pH": "input06",
            "Conductivity at 25°C": "input07",
            "Conductivity": "input08",
            "Na": "input09",
            "K": "input10",
            "Mg": "input11",
            "Ca": "input12",
            "HCO3": "input13",
            "Cl": "input14",
            "SO4": "input15",
            "SiO2": "input16",
            "DOC": "input17",
            "POC": "input18",
            "Comment": "comment",
            "Validate": "valid",
            "Hour": "time",
        }

    ## ---------------------------------- GAZ ----------------------------------
    ## Id|Date|Heure|Site|Tfum|pH|Debit|Rn|Amp|H2|He|CO|CH4|N2|H2S|Ar|CO2|SO2|O2|d13C|d18O|Observations|Valider
    ## 1 |2   |3    |4   |5   |6 |7    |8 |9  |10|11|12|13 |14|15 |16|17 |18 |19|20  |21  |22          |23
    if form == "GAZ":

        ## Mapping table: key = name in the file, value = name in the SQLite table
        mapping = {
            "Date": "edate",  ## This is a foreign key
            "Site": "node",
            "Tfum": "input01",
            "pH": "input02",
            "Debit": "input03",
            "Rn": "input04",
            "Amp": "input05",
            "H2": "input06",
            "He": "input07",
            "CO": "input08",
            "CH4": "input09",
            "N2": "input10",
            "H2S": "input11",
            "Ar": "input12",
            "CO2": "input13",
            "SO2": "input14",
            "O2": "input15",
            "d13C": "input16",
            "d18O": "input17",
            "Observations": "comment",
            "Valider": "valid",
            "Heure": "time",
        }

    ## ---------------------------------- EXTENSO ----------------------------------
    ## ID|Date|Heure|Site|Opérateurs|Température|Météo|Ruban|Offset|F1|C1|V1|F2|C2|V2|F3|C3|V3|F4|C4|V4|F5|C5|V5|F6|C6|V6|F7|C7|V7|F8|C8|V8|F9|C9|V9|Remarques|Validation
    ## 1 |2   |3    |4   |5         |6          |7    |8    |9     |10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31|32|33|34|35|36|37       |38
    if form == "EXTENSO":

        ## Mapping table: key = name in the file, value = name in the SQLite table
        mapping = {
            "Date": "edate",  ## This is a foreign key
            "Site": "node",
            "Opérateurs": "operators",
            "Température": "input01",
            "Météo": "input02",
            "Ruban": "input03",
            "Offset": "input04",
            "F1": "input05",  # to compare F1 + C1 and V1 in DB
            "F2": "input06",
            "F3": "input07",
            "F4": "input08",
            "F5": "input09",
            "F6": "input10",
            "F7": "input11",
            "F8": "input12",
            "F9": "input13",
            "W1": "input14",  # Wind force
            "W2": "input15",
            "W3": "input16",
            "W4": "input17",
            "W5": "input18",
            "W6": "input19",
            "W7": "input20",
            "W8": "input21",
            "W9": "input22",
            "Remarques": "comment",
            "Validation": "valid",
            "Heure": "time",
        }

    ## ---------------------------------- FISSURO ----------------------------------
    ## ID|Date|Heure|Site|Opérateurs|Température|Météo|Instrument|Composante|Perp1|Para1|Vert1|Perp2|Para2|Vert2|Perp3|Para3|Vert3|Perp4|Para4|Vert4|Perp5|Para5|Vert5|Perp6|Para6|Vert6|Perp7|Para7|Vert7|Perp8|Para8|Vert8|Perp9|Para9|Vert9|Perp10|Para10|Vert10|Perp11|Para11|Vert11|Perp12|Para12|Vert12|Remarques|Validation
    ## ID|Date|Heure|Site|Opérateurs|Température|Météo|Instrument|Composante|P1|L1|V1|P2|L2|V2|P3|L3|V3|P4|L4|V4|P5|L5|V5|P6|L6|V6|P7|L7|V7|P8|L8|V8|P9|L9|V9|P10|L10|V10|P11|L11|V11|P12|L12|V12|Remarques|Validation
    ## 1 |2   |3    |4   |5         |6          |7    |8         |9         |10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31|32|33|34|35|36|37 |38 |39 |40 |41 |42 |43 |44 |45 |46       |47

    if form == "FISSURO":
        ## Mapping table: key = name in the file, value = name in the SQLite table
        mapping = {
            "Date": "edate",  ## This is a foreign key
            "Site": "node",
            "Opérateurs": "operators",
            "Température": "input01",
            "Météo": "input02",
            "Instrument": "input03",
            "Composante": "input04",
            "Perp1": "input05",
            "Para1": "input06",
            "Vert1": "input07",
            "Perp2": "input08",
            "Para2": "input09",
            "Vert2": "input10",
            "Perp3": "input11",
            "Para3": "input12",
            "Vert3": "input13",
            "Perp4": "input14",
            "Para4": "input15",
            "Vert4": "input16",
            "Perp5": "input17",
            "Para5": "input18",
            "Vert5": "input19",
            "Perp6": "input20",
            "Para6": "input21",
            "Vert6": "input22",
            "Perp7": "input23",
            "Para7": "input24",
            "Vert7": "input25",
            "Perp8": "input26",
            "Para8": "input27",
            "Vert8": "input28",
            "Perp9": "input29",
            "Para9": "input30",
            "Vert9": "input31",
            "Perp10": "input32",
            "Para10": "input33",
            "Vert10": "input34",
            "Perp11": "input35",
            "Para11": "input36",
            "Vert11": "input37",
            "Perp12": "input38",
            "Para12": "input39",
            "Vert12": "input40",
            "Remarques": "comment",
            "Validation": "valid",
            "Heure": "time",
        }

    ## ---------------------------------- DISTANCE ----------------------------------
    ## Id|Date|Heure|Site|AEMD|Patm (mmHg)|Tair (°C)|H.R. (%)|Nébulosité|Vitre|D0|d01|d02|d03|d04|d05|d06|d07|d08|d09|d10|d11|d12|d13|d14|d15|d16|d17|d18|d19|d20|Remarques|Valide
    ## 1 |2   |3    |4   |5   |6          |7       |8       |9         |10   |11|12 |13 |14 |15 |16 |17 |18 |19 |20 |21 |22 |23 |24 |25 |26 |27 |28 |29 |30 |31 |32       |33
    if form == "DISTANCE":
        ## Mapping table: key = name in the file, value = name in the SQLite table
        mapping = {
            "Date": "edate",  ## This is a foreign key
            "Site": "node",
            "AEMD": "input01",
            "Patm (mmHg)": "input02",
            "Tair (°C)": "input03",
            "H.R. (%)": "input04",
            "Nébulosité": "input05",
            "Vitre": "input06",
            "D0": "input07",
            "d01": "input08",
            "d02": "input09",
            "d03": "input10",
            "d04": "input11",
            "d05": "input12",
            "d06": "input13",
            "d07": "input14",
            "d08": "input15",
            "d09": "input16",
            "d10": "input17",
            "d11": "input18",
            "d12": "input19",
            "d13": "input20",
            "d14": "input21",
            "d15": "input22",
            "d16": "input23",
            "d17": "input24",
            "d18": "input25",
            "d19": "input26",
            "d20": "input27",
            "Remarques": "comment",
            "Valide": "valid",
            "Heure": "time",
        }

    return mapping


def compare_columns(db_path, form, table, legacy_data, debug=False):
    """
    Compare each column separately, after sorting by the actual date.
    date_table: the table containing the actual date value.
    date_col: the column name in date_table containing the date.
    """

    date_table = "udate"  # Table containing the actual date
    date_col = "date"  # Column in date_table containing the date

    mapping = get_mapping(form)

    # Get columns to compare (both file and SQLite)
    compare = {k: v for k, v in mapping.items() if v not in ["valid", "time"]}
    csv_columns = list(compare.keys())
    sqlite_columns = list(compare.values())

    # Get the foreign key date column name from mapping
    csv_date_col = next((k for k, v in mapping.items() if v == "edate"), "")
    fk_date_col = mapping[csv_date_col]

    # Fetch and sort data
    sqlite_data = get_sqlite_data_with_date(
        db_path, table, sqlite_columns, fk_date_col, date_table, date_col
    )

    csv_data = get_csv_data_sorted(mapping, legacy_data, csv_columns)

    # Compare each column
    results = {}
    for i, sqlite_col in enumerate(sqlite_columns):
        csv_col = csv_columns[sqlite_columns.index(sqlite_col)]
        differences = []
        for j, (sqlite_val, csv_val) in enumerate(
            zip([row[i] for row in sqlite_data], [row[i] for row in csv_data])
        ):
            sqlite_val = "" if sqlite_val is None else sqlite_val
            if sqlite_val != csv_val:
                if debug:
                    print(f"\nSQLITE ({sqlite_col}):")
                    print(sqlite_data[j])
                    print(f"@@{sqlite_val}@@")
                    print(f"\nCSV: ({csv_col}):")
                    print(csv_data[j])
                    print(f"@@{csv_val}@@")
                differences.append(
                    {"line": j + 1, "sqlite_value": sqlite_val, "csv_value": csv_val}
                )

        results[sqlite_col] = {
            "number_of_csv_lines": len(csv_data),
            "number_of_db_lines": len(sqlite_data),
            "differences": differences,
        }

    return results


if __name__ == "__main__":
    ### OBSERA ###
    form, table, data = "RAINWATER", "rainwater_guadeloupe", "RAINWATER.DAT"
    # form, table, data = "SOILSOLUTION", "soil_solution_guadeloupe", "SOILSOLUTION.DAT"
    # form, table, data = "RIVERS", "riverwater_guadeloupe", "RIVERS.DAT"

    ### OVSG ###
    # form, table, data = "EAUX", "tracage2010", "EAUX.DAT"
    # form, table, data = "EAUX", "sources", "EAUX.DAT"
    # form, table, data = "GAZ", "gaz", "GAZ.DAT"
    # form, table, data = "EXTENSO", "extenso", "EXTENSO.DAT"
    # form, table, data = "FISSURO", "fissuro", "FISSURO.DAT"
    # form, table, data = "DISTANCE", "aemd", "DISTANCE.DAT"

    print("Form: " + form)
    print("Table name: " + table)
    print("Legacy data: " + data)

    db_path = "/opt/webobs/DATA/DB/WEBOBSFORMS.db"
    csv_path = os.path.join("/opt/webobs/DATA/BACKUP_LEGACY_FORMS", data)
    result = compare_columns(db_path, form, table, csv_path, debug=True)

    failed = False
    for col, data in result.items():
        print(f"\nColumn: {col}")
        print(f"Number of lines compared: {data['number_of_db_lines']}")
        if data["differences"]:
            failed = True
            print("Differences:")
            for diff in data["differences"]:
                print(
                    f"  Line {diff['line']}: SQLite={diff['sqlite_value']}, CSV={diff['csv_value']}"
                )
        else:
            print(f"No differences found for {col}.")

        nlc = data["number_of_csv_lines"]
        nld = data["number_of_db_lines"]
        if nlc != nld:
            failed = True
            print(
                f"\n---> The number of lines differs between the CVS and the database ({nlc} vs {nld})!"
            )

    print()
    if failed:
        print(f"{form} migration failed!")
    else:
        print(f"{form} migration successfully checked!")
