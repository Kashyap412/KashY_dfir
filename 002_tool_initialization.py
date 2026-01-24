import os, zipfile, urllib.request, subprocess, shutil

BASE = os.getcwd()
TOOLS = os.path.join(BASE, "tools")
EZ    = os.path.join(TOOLS, "eztools")
CYLR  = os.path.join(TOOLS, "CyLR")
TMP   = os.path.join(TOOLS, "_tmp")
CONF  = os.path.join(CYLR, "cylr-win.conf")

EZ_URL   = "https://download.ericzimmermanstools.com/Get-ZimmermanTools.zip"
CYLR_URL = "https://github.com/orlikoski/CyLR/releases/download/2.2.0/CyLR_win-x64.zip"
CONF_URL = "https://raw.githubusercontent.com/Kashyap412/KashY_dfir/main/cylr-win.conf"

for d in (EZ, CYLR, TMP):
    os.makedirs(d, exist_ok=True)

# ---------------- EZ TOOLS ----------------
if not any("EvtxECmd.exe" in f for _,_,fs in os.walk(EZ) for f in fs):
    ez_zip = os.path.join(TMP, "ez.zip")
    urllib.request.urlretrieve(EZ_URL, ez_zip)
    zipfile.ZipFile(ez_zip).extractall(TMP)

    ps1 = next(os.path.join(r, f)
        for r,_,fs in os.walk(TMP) for f in fs if f == "Get-ZimmermanTools.ps1")

    subprocess.run(
        ["powershell", "-ExecutionPolicy", "Bypass", "-File", ps1],
        cwd=EZ, check=True
    )

# ---------------- CYLR ----------------
if not any(f.lower() == "cylr.exe" for _,_,fs in os.walk(CYLR) for f in fs):
    cylr_zip = os.path.join(TMP, "cylr.zip")
    urllib.request.urlretrieve(CYLR_URL, cylr_zip)
    zipfile.ZipFile(cylr_zip).extractall(CYLR)

# ---------------- CYLR CONFIG ----------------
if not os.path.exists(CONF):
    urllib.request.urlretrieve(CONF_URL, CONF)

# ---------------- CLEANUP ----------------
shutil.rmtree(TMP, ignore_errors=True)

print("[✓] Tools initialized successfully")
