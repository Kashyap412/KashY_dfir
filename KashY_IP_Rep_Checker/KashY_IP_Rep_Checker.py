import os, csv, time, ipaddress, tarfile, urllib.request, itertools, requests, threading
import geoip2.database
import tkinter as tk
from tkinter import ttk, filedialog, messagebox, scrolledtext
from concurrent.futures import ThreadPoolExecutor, as_completed
from dotenv import load_dotenv

# ================= ENV =================
load_dotenv()

MAXMIND_KEY = os.getenv("MAXMIND_KEY")
ABUSE_KEYS = [k.strip() for k in os.getenv("ABUSE_KEYS", "").split(",") if k.strip()]

if not MAXMIND_KEY or not ABUSE_KEYS:
    raise SystemExit("Missing MAXMIND_KEY or ABUSE_KEYS in .env")

abuse_cycle = itertools.cycle(ABUSE_KEYS)
DB_DIR = "GeoDB"

FIELDS = [
    "ip", "ip_version", "country", "region", "city", "timezone",
    "asn", "asn_org", "isTor", "Categories", "abusescore", "Comment"
]

CATEGORIES = {
    4: "DDoS", 7: "Phishing", 9: "Open Proxy", 14: "Port Scan",
    15: "Hacking", 18: "Brute-Force", 19: "Bad Web Bot", 22: "SSH"
}

# ================= HELPERS =================
def old(path, days):
    return not os.path.exists(path) or time.time() - os.path.getmtime(path) > days * 86400

def dl_mm(edition):
    url = (
        f"https://download.maxmind.com/app/geoip_download?"
        f"edition_id={edition}&license_key={MAXMIND_KEY}&suffix=tar.gz"
    )
    tgz = f"{edition}.tgz"
    urllib.request.urlretrieve(url, tgz)

    with tarfile.open(tgz) as t:
        for m in t.getmembers():
            if m.name.endswith(".mmdb"):
                m.name = os.path.basename(m.name)
                t.extract(m, DB_DIR)
    os.remove(tgz)

def setup_db(force=False):
    os.makedirs(DB_DIR, exist_ok=True)

    if force or old(f"{DB_DIR}/GeoLite2-City.mmdb", 7):
        dl_mm("GeoLite2-City")

    if force or old(f"{DB_DIR}/GeoLite2-ASN.mmdb", 7):
        dl_mm("GeoLite2-ASN")

def abuse(ip):
    try:
        r = requests.get(
            "https://api.abuseipdb.com/api/v2/check",
            headers={"Key": next(abuse_cycle)},
            params={"ipAddress": ip, "maxAgeInDays": 90, "verbose": True},
            timeout=6
        )

        if r.status_code != 200:
            return {}

        data = r.json().get("data", {})
        cats = {
            c for rep in data.get("reports", [])
            for c in rep.get("categories", [])
        }

        return {
            "isTor": data.get("isTor"),
            "Categories": "|".join(CATEGORIES.get(c, str(c)) for c in sorted(cats)),
            "abusescore": data.get("abuseConfidenceScore"),
            "Comment": " | ".join(
                rep.get("comment", "")
                for rep in data.get("reports", [])[:2]
                if rep.get("comment")
            )
        }
    except Exception:
        return {}

# ================= GUI HELPERS =================
def log(msg):
    root.after(0, lambda: (output.insert(tk.END, msg + "\n"), output.see(tk.END)))

def ui_progress(i, total):
    progress["value"] = i
    status.set(f"{i}/{total}")

# ================= MAIN =================
def browse():
    p = filedialog.askopenfilename(filetypes=[("TXT Files", "*.txt")])
    if p:
        input_var.set(p)
        base = os.path.splitext(os.path.basename(p))[0]
        output_var.set(os.path.join(os.path.dirname(p), f"{base}_enriched.csv"))

def start():
    inp = input_var.get()
    if not inp:
        messagebox.showerror("Error", "Select input TXT file")
        return

    out = output_var.get() or os.path.join(os.path.dirname(inp), "output.csv")

    def worker():
        try:
            status.set("Loading DB")
            setup_db()

            city = geoip2.database.Reader(f"{DB_DIR}/GeoLite2-City.mmdb")
            asn = geoip2.database.Reader(f"{DB_DIR}/GeoLite2-ASN.mmdb")

            ips = set()
            with open(inp, encoding="utf-8") as f:
                for line in f:
                    try:
                        ip = line.strip()
                        obj = ipaddress.ip_address(ip)
                        if not obj.is_private and not obj.is_loopback:
                            ips.add(ip)
                    except:
                        pass

            ips = sorted(ips)
            total = len(ips)
            progress["maximum"] = total

            rows = []

            with ThreadPoolExecutor(max_workers=6) as pool:
                futures = {}

                for ip in ips:
                    row = dict.fromkeys(FIELDS)
                    row["ip"] = ip
                    row["ip_version"] = ipaddress.ip_address(ip).version

                    try:
                        g = city.city(ip)
                        row.update(
                            country=g.country.name,
                            region=g.subdivisions.most_specific.name,
                            city=g.city.name,
                            timezone=g.location.time_zone
                        )
                    except:
                        pass

                    try:
                        a = asn.asn(ip)
                        row["asn"] = a.autonomous_system_number
                        row["asn_org"] = a.autonomous_system_organization
                    except:
                        pass

                    futures[pool.submit(abuse, ip)] = row

                for i, f in enumerate(as_completed(futures), 1):
                    r = futures[f]
                    r.update(f.result())
                    rows.append(r)
                    root.after(0, ui_progress, i, total)

            city.close()
            asn.close()

            with open(out, "w", newline="", encoding="utf-8") as f:
                writer = csv.DictWriter(f, FIELDS)
                writer.writeheader()
                writer.writerows(rows)

            status.set("Completed")
            log(f"Saved → {out}")

        except Exception as e:
            messagebox.showerror("Error", str(e))

    threading.Thread(target=worker, daemon=True).start()

# ================= GUI =================
root = tk.Tk()
root.title("KashY IP Enrichment Tool")
root.geometry("820x420")
root.resizable(False, False)

style = ttk.Style(root)
style.theme_use("clam")

style.configure("Start.TButton", background="#2E7D32", foreground="white", font=("Segoe UI", 9, "bold"))
style.configure("Upd.TButton", background="#1565C0", foreground="white", font=("Segoe UI", 9, "bold"))
style.configure("Quit.TButton", background="#C62828", foreground="white", font=("Segoe UI", 9, "bold"))

style.configure("Blue.Horizontal.TProgressbar", background="#1E88E5", thickness=18)

ttk.Label(root, text="KashY IP Enrichment Tool", font=("Segoe UI", 15, "bold")).pack(pady=(10, 2))
ttk.Label(root, text="Fast IP reputation, GeoIP & Abuse intelligence enrichment").pack(pady=(0, 10))

card = ttk.LabelFrame(root, text=" File Selection ")
card.pack(fill="x", padx=20, pady=10)

row1 = tk.Frame(card)
row1.pack(fill="x", pady=6)

ttk.Label(row1, text="Input TXT", width=12).pack(side="left")
input_var = tk.StringVar()
ttk.Entry(row1, textvariable=input_var, width=60).pack(side="left", padx=6)
ttk.Button(row1, text="Browse", command=browse).pack(side="left")

row2 = tk.Frame(card)
row2.pack(fill="x", pady=6)

ttk.Label(row2, text="Output CSV", width=12).pack(side="left")
output_var = tk.StringVar()
ttk.Entry(row2, textvariable=output_var, width=60).pack(side="left", padx=6)

btns = tk.Frame(root)
btns.pack(pady=10)

ttk.Button(btns, text="▶ Start", style="Start.TButton", width=14, command=start).pack(side="left", padx=10)
ttk.Button(btns, text="⟳ Update DB", style="Upd.TButton", width=14,
           command=lambda: threading.Thread(target=lambda: setup_db(True), daemon=True).start()).pack(side="left", padx=10)
ttk.Button(btns, text="✖ Quit", style="Quit.TButton", width=10, command=root.quit).pack(side="left", padx=10)

progress = ttk.Progressbar(root, style="Blue.Horizontal.TProgressbar")
progress.pack(fill="x", padx=30, pady=(5, 5))

status = tk.StringVar(value="Idle")
ttk.Label(root, textvariable=status).pack()

output = scrolledtext.ScrolledText(root, height=5)
output.pack(fill="x", padx=20, pady=5)

ttk.Label(root, text="© A Kashyap").pack(pady=3)

root.mainloop()
