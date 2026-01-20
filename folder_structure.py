import os

def create_folder_structure(base_path, client_name):
    folders = [
        os.path.join(base_path, "tools"),
        os.path.join(base_path, "client_data", client_name, "submit_skadi"),
        os.path.join(base_path, "client_data", client_name, "network_logs"),
        os.path.join(base_path, "client_data", client_name, "iis_logs"),
    ]

    for folder in folders:
        os.makedirs(folder, exist_ok=True)
        print(f"Created: {folder}")

if __name__ == "__main__":
    base_path = os.getcwd()      # pwd
    client_name = "temp1"

    create_folder_structure(base_path, client_name)
