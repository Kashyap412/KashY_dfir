# =====================================================
# SKADI – ONE CLICK ALL ARTIFACT PARSER (EZ TOOLS)
# Multi-Client | Multi-Case | DFIR Ready
# =====================================================

$ErrorActionPreference = "Stop"

# ---------------- BASE PATHS ----------------
# $BASE   = "C:\dfir_copy"
$BASE = "temp"
$TOOLS  = "$BASE\tools\eztools"
$TMP    = "$BASE\tools\_tmp"
$CLIENT = "$BASE\client_data"


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
    if (-not (Test-Path $SUBMIT)) { 
        
        Write-Host "submit_skadi Folder Missing"
        continue 
    }

    $OUT = "$($client.FullName)\output"

    $zips = Get-ChildItem $SUBMIT -Filter "*_skadi.zip" -File
    if (-not $zips) { 
        Write-Host "No Skadi avaliable to Parse"
        continue 
    }

    foreach ($zip in $zips) {

        $caseName = $zip.BaseName
        $EXTRACT  = "$OUT\extracted\$($client.Name)_$caseName"
        $PARSED   = "$OUT\parsed\ $($client.Name)_$caseName"
        $LOG      = New-Logger $PARSED

        Log "[*] Client: $($client.Name) | Case: $caseName" $LOG


        # ---------- Extract ZIP ----------
        Expand-Archive $zip.FullName $EXTRACT -Force
        $SRC = "$EXTRACT\C"
        
        # ---------- Create folders ----------

        $dirs = @( $EXTRACT,$PARSED )
        $dirs | ForEach-Object { New-Item -ItemType Directory -Force -Path $_ | Out-Null }

        # =================================================
        # Amcache
        # =================================================
        if (Test-Path "$SRC\Windows\AppCompat\Programs\Amcache.hve") {
            Log "[*] Amcache" $LOG
            New-Item -ItemType Directory -Force -Path $PARSED\Amcache | Out-Null 
            Start-Process $Amcache -Wait -NoNewWindow `
                -ArgumentList "-f `"$SRC\Windows\AppCompat\Programs\Amcache.hve`" --csv `"$PARSED\Amcache`""
            Get-ChildItem "$PARSED\Amcache\*.csv" | ForEach-Object {Rename-Item $_.FullName "$PARSED\Amcache\$caseName`_$($_.Name)" -Force}
        Get-ChildItem $PARSED -Recurse -Filter "*.csv" | ForEach-Object {
        $newName = $_.Name -replace '_skadi_\d{14}', ''
        if ($newName -ne $_.Name) {
            Rename-Item $_.FullName $newName -Force
        }
        }

        }


        # =================================================
        # EVTX → JSON (PREFIX WITH CLIENT NAME)
        # =================================================
        
        $evtx = "$SRC\Windows\System32\winevt\Logs"

        # Extract skadi name (before _skadi_)
        $clientPrefix = ($caseName -split '_skadi_')[0]

        # Ensure output dir exists
        $null = New-Item -ItemType Directory -Force -Path "$PARSED\EventLogs"

        # ================= EVENT MAP =================
        $EventMap = @{

            "Security.evtx" = @(
                1102,4618,4624,4625,4648,4649,4672,4719,
                4720,4723,4724,4726,4728,4732,4735,4738,
                4740,4742,4756,4765,4766,4794,
                4897,4964,5124,4698,4688
            )

            "System.evtx" = @(104,7036,7045)

            "Windows PowerShell.evtx" = @(400,403,600,800)

            "Microsoft-Windows-PowerShell%4Operational.evtx" = @(
                400,403,4100,4103,4104
            )

            "Microsoft-Windows-TaskScheduler%4Operational.evtx" = @(129)

            "Microsoft-Windows-TerminalServices-LocalSessionManager.evtx" = @(
                21,22,24,25
            )

            "Microsoft-Windows-TerminalServices-RemoteConnectionManager.evtx" = @(1149)

            "Microsoft-WindowsRemoteDesktopServicesRdpCoreTS%4Operational.evtx" = @(98)

            "Microsoft-Windows-WinRM%4Operational.evtx" = @(6)

            "Application.evtx" = @(1000)

            "Microsoft-Windows-Bits-Client%4Operational.evtx" = @(59)

            "Microsoft-Windows-Defender%4Operational.evtx" = @(1116,1117)

            "Microsoft-Windows-WMI-Activity%4Operational.evtx" = @(5857,5860,5861)

            "Microsoft-Windows-User Profile Service%4Operational.evtx" = @(5)
        }

        # ================= PROCESSING =================
        if (Test-Path $evtx) {

            Log "[*] EVTX selective parsing (ALL logs)" $LOG

            foreach ($evtxFile in $EventMap.Keys) {

                $fullEvtx = Join-Path $evtx $evtxFile
                if (-not (Test-Path $fullEvtx)) { continue }

                $evtxName = [System.IO.Path]::GetFileNameWithoutExtension($evtxFile)
                $tempCsv  = Join-Path $PARSED\EventLogs "$clientPrefix`_$evtxName`_ALL.csv"

                # ---- Step 1: Full parse
                Start-Process $EvtxECmd -Wait -NoNewWindow `
                    -ArgumentList @(
                        "-f","`"$fullEvtx`"",
                        "--csv","`"$PARSED\EventLogs`"",
                        "--csvf","`"$clientPrefix`_$evtxName`_ALL.csv`""
                    )

                if (-not (Test-Path $tempCsv)) { continue }

                # ---- Step 2: Filter per Event ID
                $csv = Import-Csv $tempCsv

                foreach ($eid in $EventMap[$evtxFile]) {

                    $rows = $csv | Where-Object { $_.EventId -eq $eid }

                    if ($rows.Count -gt 0) {
                        $outFile = Join-Path $PARSED\EventLogs `
                            "$clientPrefix`_$evtxName`_$eid.csv"

                        $rows | Export-Csv $outFile -NoTypeInformation
                    }
                }

                # ---- Step 3: Cleanup
                Remove-Item $tempCsv -Force
            }
        }




        # =================================================
        # Jumplists 
        # =================================================

        $jumpRoot = Join-Path $PARSED "JumpList"
        New-Item -ItemType Directory -Force -Path $jumpRoot | Out-Null

        Get-ChildItem "$SRC\Users" -Directory -ErrorAction SilentlyContinue | ForEach-Object {

            $user = $_.Name

            $auto = "$($_.FullName)\AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations"
            if (Test-Path $auto) {
                Log "[*] Jumplist AutomaticDestinations ($user)" $LOG
                Start-Process $JLECmd -Wait -NoNewWindow `
                    -ArgumentList "-d `"$auto`" --csv `"$jumpRoot`""
            }

            $custom = "$($_.FullName)\AppData\Roaming\Microsoft\Windows\Recent\CustomDestinations"
            if (Test-Path $custom) {
                Log "[*] Jumplist CustomDestinations ($user)" $LOG
                Start-Process $JLECmd -Wait -NoNewWindow `
                    -ArgumentList "-d `"$custom`" --csv `"$jumpRoot`""
            }
        }
        Get-ChildItem $jumpRoot -File | ForEach-Object {

            if ($_.Name -match '^\d{14}_AutomaticDestinations\.csv$') {
                Rename-Item $_.FullName `
                    (Join-Path $jumpRoot "${caseClean}_AutomaticDestinations.csv") `
                    -Force
            }

            if ($_.Name -match '^\d{14}_CustomDestinations\.csv$') {
                Rename-Item $_.FullName `
                    (Join-Path $jumpRoot "${caseClean}_CustomDestinations.csv") `
                    -Force
            }
        }

        # =================================================
        # LNK
        # =================================================
        Log "[*] LNK" $LOG

        $caseClean = ($caseName -split '_skadi')[0]

        Start-Process $LECmd -Wait -NoNewWindow -ArgumentList "-d `"$SRC`" --all --csv `"$PARSED\LNK`" --csvf `"$caseClean`_lnk_Output.csv`""

        # =================================================
        # MFT
        # =================================================

        $mft = Get-ChildItem $SRC -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq '$MFT' }

        if ($mft) {

            Log "[*] MFT" $LOG

            $caseClean = ($caseName -split '_skadi')[0]

            $mftOutDir = Join-Path $PARSED "MFT"
            New-Item -ItemType Directory -Force -Path $mftOutDir | Out-Null

            $copiedMft = Join-Path $mftOutDir $mft.Name
            $outCsv    = Join-Path $mftOutDir "${caseClean}_MFT_Output.csv"

            # Copy raw $MFT
            Copy-Item $mft.FullName $copiedMft -Force

            # Run MFTECmd (CSV)
            Start-Process $MFTECmd -Wait -NoNewWindow `
                -ArgumentList "-f `"$copiedMft`" --csv `"$mftOutDir`" --csvf `"$caseClean`_MFT_Output.csv`""

            # Remove raw $MFT
            Remove-Item $copiedMft -Force

            # =================================================
            # Split CSV if larger than 200 MB
            # =================================================
            $maxSizeMB = 100
            $maxBytes  = $maxSizeMB * 1MB

            if ((Get-Item $outCsv).Length -gt $maxBytes) {

                Write-Host "[*] Splitting large MFT CSV (>100MB)"

                $reader = [System.IO.StreamReader]::new($outCsv)
                $header = $reader.ReadLine()

                $part = 1
                $partPath = Join-Path $mftOutDir "${caseClean}_MFT_Output_part$part.csv"
                $writer = [System.IO.StreamWriter]::new($partPath)
                $writer.WriteLine($header)

                while (($line = $reader.ReadLine()) -ne $null) {

                    if ((Get-Item $partPath).Length -ge $maxBytes) {
                        $writer.Close()
                        $part++

                        $partPath = Join-Path $mftOutDir "${caseClean}_MFT_Output_part$part.csv"
                        $writer = [System.IO.StreamWriter]::new($partPath)
                        $writer.WriteLine($header)
                    }

                    $writer.WriteLine($line)
                }

                $writer.Close()
                $reader.Close()

                # Remove original oversized CSV
                Remove-Item $outCsv -Force
            }
        }



        # =================================================
        # Prefetch
        # =================================================
        if (Test-Path "$SRC\Windows\Prefetch") {

            Log "[*] Prefetch" $LOG

            $caseClean = ($caseName -split '_skadi')[0]

            # Start-Process $PECmd -Wait -NoNewWindow -ArgumentList "-d `"$SRC\Windows\Prefetch`" --csv `"$PARSED\Prefetch`" --csvf `"$caseClean`_Prefetch_Output.csv`""
            Start-Process $PECmd -Wait -NoNewWindow -ArgumentList "-d `"$SRC\Windows\Prefetch`" --json `"$PARSED\Prefetch`" --jsonf `"$caseClean`_Prefetch_Output.json`""
        }



        # =================================================
        # Registry
        # =================================================

        $rebs = Get-ChildItem "$TOOLS\net9\RECmd\BatchExamples" -Filter "*.reb" -File

        Get-ChildItem "$SRC\Users" -Directory -ErrorAction SilentlyContinue | ForEach-Object {

            $ntuser = "$($_.FullName)\NTUSER.DAT"
            if (-not (Test-Path $ntuser)) { return }

            Log "[*] Registry NTUSER.DAT $($_.Name)" $LOG

            foreach ($reb in $rebs) {

                Start-Process $RECmd -Wait -NoNewWindow `
                    -ArgumentList @(
                        "-f","`"$ntuser`"",
                        "--bn","`"$($reb.FullName)`"",
                        "--csv","`"$PARSED\Registry`""
                    )
                    
            }
            
        }

        $regRoot   = "$PARSED\Registry"
        $caseClean = ($caseName -split '_skadi')[0]

        # Move all CSVs up + add case prefix
        Get-ChildItem $regRoot -Recurse -File -Filter "*.csv" | ForEach-Object {

            # Avoid double-prefixing
            if ($_.Name -notmatch "^$caseClean`_") {

                $newName = "${caseClean}_$($_.Name)"
            }
            else {
                $newName = $_.Name
            }

            $dest = Join-Path $regRoot $newName
            Move-Item $_.FullName $dest -Force
        }

        # Remove empty subdirectories (timestamp folders)
        Get-ChildItem $regRoot -Directory | Remove-Item -Recurse -Force


        
        # =================================================
        # Shimcache
        # =================================================

        if (Test-Path "$SRC\Windows\System32\config\SYSTEM") {

            Log "[*] Shimcache" $LOG

            $caseClean = ($caseName -split '_skadi')[0]

            Start-Process $Shimcache -Wait -NoNewWindow `
                -ArgumentList "-f `"$SRC\Windows\System32\config\SYSTEM`" --csv `"$PARSED\Shimcache`" --csvf `"$caseClean`_Shimcache_AppCompatCache.csv`""
        }

        # =================================================
        # SRUM
        # =================================================

        if (Test-Path "$SRC\Windows\System32\sru\SRUDB.dat") {

            Log "[*] SRUM" $LOG

            $caseClean = ($caseName -split '_skadi')[0]

            Start-Process $SrumECmd -Wait -NoNewWindow `
                -ArgumentList "-d `"$SRC\Windows\System32\sru`" --csv `"$PARSED\SRUM`""

            # Rename SRUM outputs
            Get-ChildItem "$PARSED\SRUM" -Filter "*.csv" | ForEach-Object {

                # Default format:
                # TIMESTAMP_SrumECmd_<Artifact>_Output.csv
                if ($_.Name -match '^\d{14}_SrumECmd_(.+)$') {

                    $newName = "${caseClean}_$($Matches[1])"
                    Rename-Item $_.FullName $newName -Force
                }
            }
        }


        Log "[✓] Completed $caseName" $LOG
    }
    Write-Host "SKADI DONE All clients & cases processed successfully"

}

