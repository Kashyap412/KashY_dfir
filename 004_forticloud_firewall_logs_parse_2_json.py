import os
import csv
import json
import shlex
import re
from datetime import datetime, timezone

# =========================
# CONFIG
# =========================
BASE_IN  = os.path.join("temp", "client_data")
BASE_OUT = os.path.join("temp", "parsed_data")

SYSLOG_PREFIX = re.compile(r'^<\d+><\d+>\w+:\s*')

# =========================
# UTILS
# =========================
def clean(v):
    if v is None:
        return None
    v = v.strip().strip('"')
    if v == "":
        return None
    if v.isdigit():
        return int(v)
    return v

def out_path(src):
    p = os.path.normpath(src).split(os.sep)
    i = p.index("client_data")
    return os.path.join(
        BASE_OUT,
        p[i + 1],
        "network_logs",
        os.path.splitext(p[-1])[0] + ".json"
    )

# =========================
# PARSERS
# =========================
def parse_syslog_line(line):
    evt = {}
    line = SYSLOG_PREFIX.sub("", line).strip()

    try:
        parts = shlex.split(line)
    except ValueError:
        return None

    for part in parts:
        if "=" not in part:
            continue
        k, v = part.split("=", 1)
        evt[k] = clean(v)

    return evt or None

def parse_csv_row(row):
    evt = {}
    for field in row:
        if "=" not in field:
            continue
        k, v = field.split("=", 1)
        evt[k] = clean(v)
    return evt or None

# =========================
# NORMALIZATION
# =========================
def split_addr(v):
    # ip:port:intf
    if not v or ":" not in v:
        return {}
    p = v.split(":")
    return {
        "ip": p[0],
        "port": int(p[1]) if len(p) > 1 and p[1].isdigit() else None,
        "intf": p[2] if len(p) > 2 else None
    }

def split_proto(v):
    # String form: tcp/https
    if isinstance(v, str):
        p = v.split("/")
        return {
            "transport": p[0],
            "application": p[1] if len(p) > 1 else None
        }

    # Integer form: 6, 17, 1
    if isinstance(v, int):
        proto_map = {
            6: "tcp",
            17: "udp",
            1: "icmp"
        }
        return {
            "transport": proto_map.get(v, str(v)),
            "application": None
        }

    return {}


def normalize_timestamp(evt):
    if "eventtime" in evt:
        return datetime.fromtimestamp(
            int(evt["eventtime"]) / 1e9,
            tz=timezone.utc
        ).isoformat()

    if "itime" in evt:
        return datetime.fromtimestamp(
            int(evt["itime"]),
            tz=timezone.utc
        ).isoformat()

    if "date" in evt and "time" in evt:
        try:
            return datetime.fromisoformat(
                f"{evt['date']} {evt['time']}"
            ).replace(tzinfo=timezone.utc).isoformat()
        except Exception:
            pass

    return None

# =========================
# FLATTEN (ELASTICSAFE)
# =========================
def flatten_event(evt):
    flat = {}

    # ---- Timestamp ----
    ts = normalize_timestamp(evt)
    if ts:
        flat["@timestamp"] = ts

    # ---- Source / Destination ----
    if "src" in evt:
        s = split_addr(evt["src"])
        flat["src_ip"] = s.get("ip")
        flat["src_port"] = s.get("port")
        flat["src_intf"] = s.get("intf")

    if "dst" in evt:
        d = split_addr(evt["dst"])
        flat["dst_ip"] = d.get("ip")
        flat["dst_port"] = d.get("port")
        flat["dst_intf"] = d.get("intf")

    # ---- Protocol ----
    if "proto" in evt:
        p = split_proto(evt["proto"])
        flat["network_transport"] = p.get("transport")
        flat["network_application"] = p.get("application")

    # ---- Policy ----
    if "policyid" in evt:
        flat["policy_id"] = evt["policyid"]
    if "policyname" in evt:
        flat["policy_name"] = evt["policyname"]

    # ---- Traffic Counters ----
    counter_map = {
        "sent": "network_bytes_sent",
        "sentbyte": "network_bytes_sent",
        "rcvd": "network_bytes_received",
        "rcvdbyte": "network_bytes_received",
        "spkt": "network_packets_sent",
        "rpkt": "network_packets_received"
    }
    for k, nk in counter_map.items():
        if k in evt:
            flat[nk] = evt[k]

    # ---- User ----
    if "user" in evt:
        flat["user_name"] = evt["user"]

    # ---- Device ----
    for k in ("devid", "devname", "vd", "fw"):
        if k in evt:
            flat[f"device_{k}"] = evt[k]

    # ---- VPN ----
    for k in ("vpntype", "vpnpolicy"):
        if k in evt:
            flat[f"vpn_{k}"] = evt[k]

    # ---- Fallback (safe fields only) ----
    skip = {
        "src","dst","proto","policyid","policyname","user",
        "sent","sentbyte","rcvd","rcvdbyte","spkt","rpkt",
        "eventtime","itime","date","time"
    }

    for k, v in evt.items():
        if k not in skip and k not in flat:
            flat[k] = v

    return {k: v for k, v in flat.items() if v is not None}

# =========================
# FILE HANDLER
# =========================
def parse_file(src, out):
    with open(src, encoding="utf-8", errors="ignore") as f:
        first = f.readline()
        f.seek(0)

        # Syslog traffic
        if first.lstrip().startswith("<"):
            for line in f:
                evt = parse_syslog_line(line)
                if evt:
                    out.write(json.dumps(flatten_event(evt)) + "\n")
        else:
            reader = csv.reader(f)
            for row in reader:
                evt = parse_csv_row(row)
                if evt:
                    out.write(json.dumps(flatten_event(evt)) + "\n")

# =========================
# RUNNER
# =========================
def run():
    for root, _, files in os.walk(BASE_IN):
        if "network_logs" not in root:
            continue

        for fname in files:
            if fname.split(".")[-1].lower() not in ("log", "txt", "csv", "json"):
                continue

            src = os.path.join(root, fname)
            dst = out_path(src)
            os.makedirs(os.path.dirname(dst), exist_ok=True)

            with open(dst, "w", encoding="utf-8") as out:
                parse_file(src, out)

            print(f"[+] Parsed & flattened: {src}")

if __name__ == "__main__":
    run()
    print("\n✔ All FortiGate logs parsed & flattened for Elasticsearch")
