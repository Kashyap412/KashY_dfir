import os
import zipfile
import urllib.request
import subprocess
import shutil
from pathlib import Path

# ---------------- USER PROMPT ----------------
RUN_EZ_INSTALL = input(
    "Run Eric Zimmerman Tools installer now? (y/n): "
).strip().lower() == "y"

# ---------------- CONFIG ----------------
BASE = Path("temp").resolve()
TOOLS = BASE / "tools"
EZ    = TOOLS / "eztools"
CYLR  = TOOLS / "CyLR"
TMP   = TOOLS / "_tmp"
CONF  = CYLR / "cylr-win.conf"

EZ_URL   = "https://download.ericzimmermanstools.com/Get-ZimmermanTools.zip"
CYLR_URL = "https://github.com/orlikoski/CyLR/releases/download/2.2.0/CyLR_win-x64.zip"
CONF_URL = "https://raw.githubusercontent.com/Kashyap412/test/refs/heads/main/cylr-win.conf"

# ---------------- HELPERS ----------------
def safe_extract(zip_path: Path, dest: Path):
    with zipfile.ZipFile(zip_path) as z:
        for member in z.namelist():
            target = dest / member
            if not str(target.resolve()).startswith(str(dest.resolve())):
                raise Exception(f"[!] Zip path traversal blocked: {member}")
        z.extractall(dest)

def download(url: str, dest: Path):
    print(f"[↓] Downloading {url}")
    urllib.request.urlretrieve(url, dest)

def tool_exists(path: Path, filename: str):
    return any(p.name.lower() == filename.lower() for p in path.rglob("*"))

# ---------------- DIR SETUP ----------------
for d in (EZ, CYLR, TMP):
    d.mkdir(parents=True, exist_ok=True)

# ---------------- EZ TOOLS ----------------
if not tool_exists(EZ, "EvtxECmd.exe"):
    ez_zip = TMP / "ez.zip"
    download(EZ_URL, ez_zip)
    safe_extract(ez_zip, TMP)

    ps1 = next(p for p in TMP.rglob("Get-ZimmermanTools.ps1"))

    if RUN_EZ_INSTALL:
        print("[▶] Running Get-ZimmermanTools.ps1")
        subprocess.run(
            [
                "powershell",
                "-NoProfile",
                "-ExecutionPolicy", "Bypass",
                "-File", str(ps1)
            ],
            cwd=str(EZ),
            check=True
        )
        print("[✓] EZ Tools installed")
    else:
        print("[!] EZ Tools PS1 downloaded but not executed")
else:
    print("[✓] EZ Tools already present")

# ---------------- CYLR ----------------
if not tool_exists(CYLR, "CyLR.exe"):
    cylr_zip = TMP / "cylr.zip"
    download(CYLR_URL, cylr_zip)
    safe_extract(cylr_zip, CYLR)
    print("[✓] CyLR extracted")
else:
    print("[✓] CyLR already present")

# ---------------- CYLR CONFIG ----------------
if not CONF.exists():
    download(CONF_URL, CONF)
    print("[✓] CyLR config downloaded")
else:
    print("[✓] CyLR config already present")

# ---------------- CLEANUP ----------------
shutil.rmtree(TMP, ignore_errors=True)

print("\n[✓] Tools initialized successfully")
