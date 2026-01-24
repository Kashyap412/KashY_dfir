import os, csv, json, re

BASE_IN  = os.path.join(os.getcwd(), "client_data")
BASE_OUT = os.path.join(os.getcwd(), "parsed_data")

KV = re.compile(r'([^=]+)=(.*)')

def clean(v):
    v = v.strip().strip('"')
    return int(v) if v.isdigit() else v or None

def out_path(src):
    p = os.path.normpath(src).split(os.sep)
    i = p.index("client_data")
    return os.path.join(
        BASE_OUT,
        p[i+1],                 # client
        "network_logs",
        os.path.splitext(p[-1])[0] + ".json"
    )

def parse_kv(src, out):
    with open(src, encoding="utf-8", errors="ignore") as f:
        for row in csv.reader(f):
            evt = {}
            for field in row:
                if "=" in field:
                    k, v = KV.match(field).groups()
                    evt[k] = clean(v)
            if evt:
                out.write(json.dumps(evt) + "\n")

def parse_json(src, out):
    with open(src, encoding="utf-8", errors="ignore") as f:
        for line in f:
            try:
                out.write(json.dumps(json.loads(line)) + "\n")
            except:
                pass

def run():
    for root, _, files in os.walk(BASE_IN):
        if "network_logs" not in root:
            continue

        for f in files:
            if f.split(".")[-1].lower() not in ("log", "txt", "csv", "json"):
                continue

            src = os.path.join(root, f)
            dst = out_path(src)
            os.makedirs(os.path.dirname(dst), exist_ok=True)

            with open(dst, "w", encoding="utf-8") as out:
                parse_json(src, out) if f.endswith(".json") else parse_kv(src, out)

            print(f"[+] {src}")

if __name__ == "__main__":
    run()
    print("\n✔ All network logs parsed")
