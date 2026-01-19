# =====================================================
# SKADI – ONE CLICK ALL ARTIFACT PARSER (EZ TOOLS)
# Multi-Client | Multi-Case | DFIR Ready
# =====================================================

$ErrorActionPreference = "Stop"

# ---------------- BASE PATHS ----------------
# $BASE   = "C:\dfir_copy"
$BASE = (Get-Location).Path
Write-Host $BASE
$TOOLS  = "$BASE\tools\eztools"
$TMP    = "$BASE\tools\_tmp"
$CLIENT = "$BASE\client_data"

Write-Host $BASE

# ---------------- LOGGING ----------------
function New-Logger($BASE) {
    $logDir = "$BASE\Metadata\ParserLogs"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    return "$logDir\parser.log"
}

function Log($msg, $log) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts | $msg" | Tee-Object -Append -FilePath $log
}

# =====================================================
# STEP 1: INSTALL EZ TOOLS (ONCE)
# =====================================================

$ezUrl = "https://download.ericzimmermanstools.com/Get-ZimmermanTools.zip"
$ezZip = "$TMP\Get-ZimmermanTools.zip"

@($TOOLS,$TMP,$TOOLS,$TOOLS) | ForEach-Object {
    New-Item -ItemType Directory -Force -Path $_ | Out-Null
}

if (-not (Get-ChildItem $TOOLS -Recurse -Filter "EvtxECmd.exe" -ErrorAction SilentlyContinue)) {
    Write-Host "[*] Installing EZ Tools..."
    Invoke-WebRequest $ezUrl -OutFile $ezZip
    Expand-Archive $ezZip $TMP -Force

    $installer = Get-ChildItem $TMP -Recurse -Filter "Get-ZimmermanTools.ps1" | Select-Object -First 1
    if (-not $installer) { throw "EZ Tools installer not found" }

    Push-Location $TOOLS
    powershell -ExecutionPolicy Bypass -File $installer.FullName
    Pop-Location

    Remove-Item $ezZip -Force
}

# =====================================================
# STEP 2: RESOLVE TOOLS (SAFE)
# =====================================================

function Get-EZTool($exe) {
    $t = Get-ChildItem $TOOLS -Recurse -Filter $exe -File | Select-Object -First 1
    if (-not $t) { throw "Missing EZ Tool: $exe" }
    return $t.FullName
}

$EvtxECmd  = Get-EZTool "EvtxECmd.exe"
$PECmd     = Get-EZTool "PECmd.exe"
$MFTECmd   = Get-EZTool "MFTECmd.exe"
$SrumECmd  = Get-EZTool "SrumECmd.exe"
$Amcache   = Get-EZTool "AmcacheParser.exe"
$Shimcache = Get-EZTool "AppCompatCacheParser.exe"
$JLECmd    = Get-EZTool "JLECmd.exe"
$LECmd     = Get-EZTool "LECmd.exe"
$RECmd     = Get-EZTool "RECmd.exe"

# =====================================================
# STEP 2: PROCESS ALL CLIENTS
# =====================================================
$clients = Get-ChildItem $CLIENT -Directory

foreach ($client in $clients) {

    $SUBMIT = "$($client.FullName)\submit_skadi"
    if (-not (Test-Path $SUBMIT)) { continue }

    $OUT = "$($client.FullName)\output"

    $zips = Get-ChildItem $SUBMIT -Filter "*_skadi.zip" -File
    if (-not $zips) { continue }

    foreach ($zip in $zips) {

        $caseName = $zip.BaseName
        $EXTRACT  = "$OUT\extracted\$($client.Name)_$caseName"
        $PARSED   = "$OUT\parsed\ $($client.Name)_$caseName"
        $LOG      = New-Logger $PARSED

        Log "[*] Client: $($client.Name) | Case: $caseName" $LOG


        # ---------- Extract ZIP ----------
        # Expand-Archive $zip.FullName $EXTRACT -Force
        $SRC = "$EXTRACT\C"
        
        # ---------- Create folders ----------
        $dirs = @(
            $EXTRACT,$PARSED,
            "$PARSED\EventLogs","$PARSED\Prefetch","$PARSED\Amcache",
            "$PARSED\Shimcache","$PARSED\JumpList","$PARSED\LNK",
            "$PARSED\SRUM","$PARSED\MFT","$PARSED\Registry"
        )
        $dirs | ForEach-Object { New-Item -ItemType Directory -Force -Path $_ | Out-Null }

        # # =================================================
        # # Amcache
        # # =================================================
        # if (Test-Path "$SRC\Windows\AppCompat\Programs\Amcache.hve") {
        #     Log "[*] Amcache" $LOG
        #     Start-Process $Amcache -Wait -NoNewWindow `
        #         -ArgumentList "-f `"$SRC\Windows\AppCompat\Programs\Amcache.hve`" --csv `"$PARSED\Amcache`""
        #     Get-ChildItem "$PARSED\Amcache\*.csv" | ForEach-Object {Rename-Item $_.FullName "$PARSED\Amcache\$caseName`_$($_.Name)" -Force}
        # Get-ChildItem $PARSED -Recurse -Filter "*.csv" | ForEach-Object {
        # $newName = $_.Name -replace '_skadi_\d{14}', ''
        # if ($newName -ne $_.Name) {
        #     Rename-Item $_.FullName $newName -Force
        # }
        # }

        # }


        # # =================================================
        # # EVTX → JSON (PREFIX WITH CLIENT NAME)
        # # =================================================
        # $evtx = "$SRC\Windows\System32\winevt\Logs"

        # # Extract clean client name (before _skadi_)
        # $clientPrefix = ($caseName -split '_skadi_')[0]

        # if (Test-Path $evtx) {
        #     Log "[*] EVTX" $LOG
        #     Get-ChildItem $evtx -Filter "*.evtx" -File | ForEach-Object {

        #         $jsonName = "${clientPrefix}_$($_.BaseName).json"

        #         Start-Process $EvtxECmd -Wait -NoNewWindow `
        #             -ArgumentList @(
        #                 "-f","`"$($_.FullName)`"",
        #                 "--json","`"$PARSED\EventLogs`"",
        #                 "--jsonf","`"$jsonName`""
        #             )
        #             Get-ChildItem "$PARSED\EventLogs" -Filter "*.json" | ForEach-Object {
        #             $newName = $_.Name -replace '_skadi_', '_'
        #             if ($newName -ne $_.Name) {
        #                 Rename-Item $_.FullName $newName -Force
        #             }
        #             }
        #     }

        # }



        # # =================================================
        # # Jumplists
        # # =================================================
        # Get-ChildItem "$SRC\Users" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        #     $jl = "$($_.FullName)\AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations"
        #     if (Test-Path $jl) {
        #         Log "[*] Jumplist $($_.Name)" $LOG
        #         Start-Process $JLECmd -Wait -NoNewWindow `
        #             -ArgumentList "-d `"$jl`" --json `"$PARSED\JumpList`""
            
                    
        #     }
        # }

        # # =================================================
        # # LNK
        # # =================================================
        # Log "[*] LNK" $LOG

        # $caseClean = ($caseName -split '_skadi')[0]

        # Start-Process $LECmd -Wait -NoNewWindow `
        #     -ArgumentList "-d `"$SRC`" --all --json `"$PARSED\LNK`""

        # # Rename LECmd output
        # Get-ChildItem "$PARSED\LNK" -Filter "*.json" | ForEach-Object {

        #     # Match default LECmd format: TIMESTAMP_LECmd_Output.json
        #     if ($_.Name -match '^\d{14}_LECmd_Output\.json$') {

        #         $newName = "${caseClean}_lnk_Output.json"
        #         Rename-Item $_.FullName $newName -Force
        #     }
        # }

        # # =================================================
        # # MFT 
        # # =================================================
        # $mft = Get-ChildItem $SRC -Force -ErrorAction SilentlyContinue |
        #     Where-Object { $_.Name -eq '$MFT' }

        # if ($mft) {

        #     Log "[*] MFT" $LOG

        #     $caseClean = ($caseName -split '_skadi')[0]

        #     Copy-Item $mft.FullName "$PARSED\MFT\$($mft.Name)" -Force

        #     Start-Process $MFTECmd -Wait -NoNewWindow `
        #         -ArgumentList "-f `"$PARSED\MFT\$($mft.Name)`" --json `"$PARSED\MFT`""

        #     # Rename MFTECmd output
        #     Get-ChildItem "$PARSED\MFT" -Filter "*.json" | ForEach-Object {

        #         # Default MFTECmd format:
        #         # TIMESTAMP_MFTECmd_$MFT_Output.json
        #         if ($_.Name -match '^\d{14}_MFTECmd_\$MFT_Output\.json$') {

        #             $newName = "${caseClean}_MFT_Output.json"
        #             Rename-Item $_.FullName $newName -Force
        #         }
        #     }
        # }


        # # =================================================
        # # Prefetch
        # # =================================================
        # if (Test-Path "$SRC\Windows\Prefetch") {

        #     Log "[*] Prefetch" $LOG

        #     $caseClean = ($caseName -split '_skadi')[0]

        #     Start-Process $PECmd -Wait -NoNewWindow `
        #         -ArgumentList "-d `"$SRC\Windows\Prefetch`" --json `"$PARSED\Prefetch`""

        #     # Rename PECmd output
        #     Get-ChildItem "$PARSED\Prefetch" -Filter "*.json" | ForEach-Object {

        #         # Default PECmd format:
        #         # TIMESTAMP_PECmd_Output.json
        #         if ($_.Name -match '^\d{14}_PECmd_Output\.json$') {

        #             $newName = "${caseClean}_Prefetch_Output.json"
        #             Rename-Item $_.FullName $newName -Force
        #         }
        #     }
        # }


        # =================================================
        # No Registry – NTUSER.DAT
        # =================================================

        # $rebs = Get-ChildItem "$TOOLS\net9\RECmd\BatchExamples" -Filter "*.reb" -File

        # Get-ChildItem "$SRC\Users" -Directory -ErrorAction SilentlyContinue | ForEach-Object {

        #     $ntuser = "$($_.FullName)\NTUSER.DAT"
        #     if (-not (Test-Path $ntuser)) { return }

        #     Log "[*] Registry NTUSER.DAT $($_.Name)" $LOG

        #     foreach ($reb in $rebs) {

        #         Start-Process $RECmd -Wait -NoNewWindow `
        #             -ArgumentList @(
        #                 "-f","`"$ntuser`"",
        #                 "--bn","`"$($reb.FullName)`"",
        #                 "--csv","`"$PARSED\Registry`""
        #             )
                    
        #     }


            
        # }

        # $regRoot   = "$PARSED\Registry"
        # $caseClean = ($caseName -split '_skadi')[0]

        # # Move all CSVs up + add case prefix
        # Get-ChildItem $regRoot -Recurse -File -Filter "*.csv" | ForEach-Object {

        #     # Avoid double-prefixing
        #     if ($_.Name -notmatch "^$caseClean`_") {

        #         $newName = "${caseClean}_$($_.Name)"
        #     }
        #     else {
        #         $newName = $_.Name
        #     }

        #     $dest = Join-Path $regRoot $newName
        #     Move-Item $_.FullName $dest -Force
        # }

        # # Remove empty subdirectories (timestamp folders)
        # Get-ChildItem $regRoot -Directory | Remove-Item -Recurse -Force


        
        # # =================================================
        # # Shimcache
        # # =================================================

        # if (Test-Path "$SRC\Windows\System32\config\SYSTEM") {

        #     Log "[*] Shimcache" $LOG

        #     $caseClean = ($caseName -split '_skadi')[0]

        #     Start-Process $Shimcache -Wait -NoNewWindow `
        #         -ArgumentList "-f `"$SRC\Windows\System32\config\SYSTEM`" --csv `"$PARSED\Shimcache`""

        #     # Rename AppCompatCacheParser output
        #     Get-ChildItem "$PARSED\Shimcache" -Filter "*.csv" | ForEach-Object {

        #         # Default format:
        #         # TIMESTAMP_WindowsXX_SYSTEM_AppCompatCache.csv
        #         if ($_.Name -match '^\d{14}_.+_SYSTEM_AppCompatCache\.csv$') {

        #             $newName = "${caseClean}_Shimcache_AppCompatCache.csv"
        #             Rename-Item $_.FullName $newName -Force
        #         }
        #     }
        # }

        # # =================================================
        # # SRUM
        # # =================================================

        # if (Test-Path "$SRC\Windows\System32\sru\SRUDB.dat") {

        #     Log "[*] SRUM" $LOG

        #     $caseClean = ($caseName -split '_skadi')[0]

        #     Start-Process $SrumECmd -Wait -NoNewWindow `
        #         -ArgumentList "-d `"$SRC\Windows\System32\sru`" --csv `"$PARSED\SRUM`""

        #     # Rename SRUM outputs
        #     Get-ChildItem "$PARSED\SRUM" -Filter "*.csv" | ForEach-Object {

        #         # Default format:
        #         # TIMESTAMP_SrumECmd_<Artifact>_Output.csv
        #         if ($_.Name -match '^\d{14}_SrumECmd_(.+)$') {

        #             $newName = "${caseClean}_$($Matches[1])"
        #             Rename-Item $_.FullName $newName -Force
        #         }
        #     }
        # }


        Log "[✓] Completed $caseName" $LOG
    }
}

Write-Host "`nSKADI DONE All clients & cases processed successfully"
