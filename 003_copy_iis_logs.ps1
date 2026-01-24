$BASE = Get-Location

Get-ChildItem "$BASE\client_data" -Directory | ForEach-Object {
    $src = "$($_.FullName)\iis_logs"
    $dst = "$BASE\parsed_data\$($_.Name)\iis_logs"

    if (Test-Path $src) {
        New-Item -ItemType Directory -Force -Path $dst | Out-Null
        Copy-Item "$src\*" $dst -Recurse -Force -ErrorAction SilentlyContinue
    }
}
