# =====================================================
# CyLR One-Click Collection Script (Custom Config)
# Repo: KashY_dfir / cylr-win.conf
# Output: HOSTNAME.zip
# =====================================================

$ErrorActionPreference = "Stop"

# ---------------- CONFIG ----------------
$CYLR_URL   = "https://github.com/orlikoski/CyLR/releases/download/2.2.0/CyLR_win-x64.zip"
$CONF_URL   = "https://raw.githubusercontent.com/Kashyap412/KashY_dfir/main/cylr-win.conf"

$BASE       = Split-Path -Parent $MyInvocation.MyCommand.Path
$HOSTNAME   = $env:COMPUTERNAME

$TOOLS      = Join-Path $BASE "tools"
$CYLR_DIR   = Join-Path $TOOLS "CyLR"
$CONF_FILE  = Join-Path $TOOLS "cylr-win.conf"

$OUT        = Join-Path $BASE "collected_skadi\$HOSTNAME"
$ZIPNAME    = "$HOSTNAME.zip"

# ---------------- PREP ----------------
New-Item -ItemType Directory -Path $TOOLS -Force | Out-Null
New-Item -ItemType Directory -Path $OUT   -Force | Out-Null

# ---------------- DOWNLOAD CONFIG ----------------
if (-not (Test-Path $CONF_FILE)) {
    Write-Host "[*] Downloading CyLR config..."
    Invoke-WebRequest $CONF_URL -OutFile $CONF_FILE
}

# ---------------- CYLR SETUP ----------------
$CYLR = Get-ChildItem $TOOLS -Recurse -Filter "CyLR.exe" -ErrorAction SilentlyContinue |
        Select-Object -First 1

if (-not $CYLR) {
    Write-Host "[*] Downloading CyLR..."
    $ZIP = Join-Path $TOOLS "CyLR_win-x64.zip"

    Invoke-WebRequest $CYLR_URL -OutFile $ZIP
    Expand-Archive $ZIP $CYLR_DIR -Force
    Remove-Item $ZIP -Force

    $CYLR = Get-ChildItem $TOOLS -Recurse -Filter "CyLR.exe" |
            Select-Object -First 1
}

if (-not $CYLR) {
    throw "CyLR.exe not found"
}

# ---------------- RUN COLLECTION ----------------
Write-Host "[*] Running CyLR with custom config on $HOSTNAME ..."

Start-Process `
    -FilePath $CYLR.FullName `
    -ArgumentList "-c `"$CONF_FILE`" -od `"$OUT`" -of `"$ZIPNAME`"" `
    -Wait `
    -NoNewWindow

# ---------------- VERIFY ----------------
$ZIPPATH = Join-Path $OUT $ZIPNAME
if (-not (Test-Path $ZIPPATH)) {
    throw "Collection failed ZIP not created"
}

# ---------------- DONE ----------------
Write-Host ""
Write-Host "\t COLLECTION COMPLETE"
Write-Host "    Hostname : $HOSTNAME"
Write-Host "    Config   : cylr-win.conf"
Write-Host "    Output   : $ZIPPATH"
