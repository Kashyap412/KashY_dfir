import os
import re

def sanitize_client_name(name: str) -> str:
    """
    Keep letters, numbers, dash, underscore.
    Replace spaces with underscore.
    """
    name = name.strip().replace(" ", "_")
    return re.sub(r"[^a-zA-Z0-9_-]", "", name)

def create_folder_structure(base_path, client_name):
    folders = [
        "submit_skadi",
        "network_logs",
        "iis_logs",
    ]

    client_base = os.path.join(base_path, "client_data", client_name)

    for folder in folders:
        path = os.path.join(client_base, folder)
        os.makedirs(path, exist_ok=True)
        print(f"  ├─ {path}")

    print(f"\n[+] Client root: {client_base}")

if __name__ == "__main__":
    base_path = os.path.abspath("temp")  # resolves to full path
    raw_client_name = input("Enter client name: ")

    if not raw_client_name.strip():
        print("❌ Client name cannot be empty")
        exit(1)

    client_name = sanitize_client_name(raw_client_name)

    if not client_name:
        print("❌ Client name became empty after sanitization")
        exit(1)

    create_folder_structure(base_path, client_name)
    print("\n✅ Folder structure created successfully")
