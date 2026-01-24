import os

def create_folder_structure(base_path, client_name):
    paths = [
        os.path.join(base_path, "client_data", client_name, "submit_skadi"),
        os.path.join(base_path, "client_data", client_name, "network_logs"),
        os.path.join(base_path, "client_data", client_name, "iis_logs"),
    ]

    for path in paths:
        os.makedirs(path, exist_ok=True)
        print(f"[+] Created: {path}")

if __name__ == "__main__":
    base_path = os.getcwd()  # current directory
    client_name = input("Enter client name: ").strip()

    if not client_name:
        print("Client name cannot be empty")
    else:
        create_folder_structure(base_path, client_name)
        print("\n✅ Folder structure created successfully")
