from pathlib import Path
import shutil

# BASE = Path.cwd()   # equivalent of Get-Location
BASE = Path("temp").resolve()

client_data = BASE / "client_data"
parsed_data = BASE / "parsed_data"

if not client_data.exists():
    print(f"[!] client_data not found: {client_data}")
    exit(1)

for client_dir in client_data.iterdir():
    if not client_dir.is_dir():
        continue

    src = client_dir / "iis_logs"
    dst = parsed_data / client_dir.name / "iis_logs"

    if src.exists():
        dst.mkdir(parents=True, exist_ok=True)

        for item in src.iterdir():
            try:
                if item.is_dir():
                    shutil.copytree(item, dst / item.name, dirs_exist_ok=True)
                else:
                    shutil.copy2(item, dst / item.name)
            except Exception:
                # Match PowerShell: -ErrorAction SilentlyContinue
                pass

print("[✓] IIS logs copied to parsed_data successfully")
