import os, csv, json, re

# BASE_DIR = r"C:\dfir\client_data"
BASE_DIR = os.path.join(os.getcwd(), "client_data")

# =========================
# REGEX
# =========================
KV_REGEX = re.compile(r'([^=]+)=(.*)')

# =========================
# OUTPUT PATH LOGIC
# =========================
def out_path(src):
    p = os.path.normpath(src).split(os.sep)
    i = p.index("client_data")
    out = p[:i+2] + ["output"] + p[i+2:]
    return os.path.splitext(os.sep.join(out))[0] + ".json"

# =========================
# VALUE CLEANER
# =========================
def clean_value(val):
    val = val.strip()
    if val in ("", '""'):
        return None

    if val.startswith('"') and val.endswith('"'):
        val = val[1:-1]

    if val.startswith('"') and val.endswith('"'):
        val = val[1:-1]

    if val.isdigit():
        return int(val)

    return val

# =========================
# FORTIGATE KV PARSER
# =========================
def parse_kv_fields(fields):
    data = {}
    for field in fields:
        if "=" not in field:
            continue

        m = KV_REGEX.match(field)
        if not m:
            continue

        k, v = m.groups()
        data[k] = clean_value(v)

    return data

# =========================
# TXT PARSER
# =========================
def parse_txt(src, out):
    with open(src, newline="", encoding="utf-8", errors="ignore") as f:
        reader = csv.reader(f)
        for row in reader:
            event = parse_kv_fields(row)
            if event:
                out.write(json.dumps(event, ensure_ascii=False) + "\n")

# =========================
# CSV PARSER
# =========================
def parse_csv(src, out):
    with open(src, newline="", encoding="utf-8", errors="ignore") as f:
        reader = csv.reader(f)
        for row in reader:
            event = parse_kv_fields(row)
            if event:
                out.write(json.dumps(event, ensure_ascii=False) + "\n")

# =========================
# JSON PARSER (PASSTHROUGH)
# =========================
def parse_json(src, out):
    with open(src, encoding="utf-8", errors="ignore") as f:
        try:
            for line in f:
                obj = json.loads(line.strip())
                out.write(json.dumps(obj, ensure_ascii=False) + "\n")
        except json.JSONDecodeError:
            pass

# =========================
# MAIN PROCESSOR
# =========================
def process(base):
    for root, _, files in os.walk(base):
        for f in files:
            src = os.path.join(root, f)
            ext = f.lower().split(".")[-1]

            if ext not in ("txt", "csv", "json"):
                continue

            print(f"[*] Processing: {src}")
            dst = out_path(src)
            os.makedirs(os.path.dirname(dst), exist_ok=True)

            with open(dst, "w", encoding="utf-8") as out:
                if ext == "txt":
                    parse_txt(src, out)
                elif ext == "csv":
                    parse_csv(src, out)
                else:
                    parse_json(src, out)

# =========================
# ENTRY POINT
# =========================
if __name__ == "__main__":
    process(BASE_DIR)
    print("\n[+] All files processed successfully")
