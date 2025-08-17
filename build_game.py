import os
import shutil
import zipfile
import subprocess
from datetime import datetime
from getpass import getpass
import paramiko
import requests
from tqdm import tqdm

# === CONFIGURATION ===
PROJECT_PATH = r"C:\Users\creat\Desktop\github\wizards-with-guns\wwg24\gadot"
EXPORT_FOLDER = r"C:\Users\creat\Desktop\github\wizards-with-guns\releases"
EXPORT_PRESET = "Windows Desktop"
REMOTE_HOST = "ssh.pythonanywhere.com"
REMOTE_USER = "joetoscani"
REMOTE_PATH = "/home/joetoscani/wwgsite/wwgsite/wwgsite/media/versions"
SYNC_URL = "https://www.wizardswithguns.com/sync_versions"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

print("[*] Starting build and upload process...")

# === Step 1: Find Godot executable ===
print("[*] Locating Godot executable...")
godot_exe = next((f for f in os.listdir(SCRIPT_DIR) if f.lower().endswith(".exe") and "godot" in f.lower()), None)
if not godot_exe:
    raise FileNotFoundError("No Godot executable found in script folder.")
godot_exe = os.path.join(SCRIPT_DIR, godot_exe)
print(f"[+] Found Godot executable: {godot_exe}")

# === Step 2: Create dated folder ===
today = datetime.today()
base_date = f"{today.strftime('%y')}.{today.month}.{today.day}"  # YY.M.D
release_dir = os.path.join(EXPORT_FOLDER, base_date)
print(f"[*] Creating release folder for version: {base_date}")

for i in range(0, 100):
    suffix = f".{i}" if i else ""
    final_dir = release_dir + suffix
    if not os.path.exists(final_dir):
        os.makedirs(final_dir)
        release_dir = final_dir
        break
else:
    raise Exception("Too many folders with today's date.")
print(f"[+] Release folder created: {release_dir}")


# === Step 3: Run Godot export ===
exported_exe = os.path.join(release_dir, "wizards-with-guns.exe")
print("[*] Exporting game using Godot...")
result = subprocess.run([
    godot_exe,
    "--headless",
    "--path", PROJECT_PATH,
    "--export-release", EXPORT_PRESET,
    exported_exe
], capture_output=True, text=True)

if result.returncode != 0:
    print(result.stdout)
    print(result.stderr)
    raise RuntimeError("Godot export failed.")
print(f"[+] Exported executable: {exported_exe}")

# === Step 4: Copy extra files ===
print("[*] Copying tbmaps, autoexec.json, config.json...")
shutil.copy(os.path.join(PROJECT_PATH, "autoexec.json"), release_dir)
shutil.copy(os.path.join(PROJECT_PATH, "config.json"), release_dir)
shutil.copytree(os.path.join(PROJECT_PATH, "tbmaps"), os.path.join(release_dir, "tbmaps"), dirs_exist_ok=True)
print("[+] All extra files copied.")

# === Step 5: Zip the release folder ===
zip_path = release_dir + ".zip"
print(f"[*] Creating zip file: {zip_path}")
with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zipf:
    for root, _, files in os.walk(release_dir):
        for file in files:
            abs_path = os.path.join(root, file)
            rel_path = os.path.relpath(abs_path, release_dir)
            zipf.write(abs_path, rel_path)
print(f"[+] Zip created: {zip_path}")

# === Step 6: Upload via SFTP with progress ===
password = getpass(f"Enter SSH password for {REMOTE_USER}@{REMOTE_HOST}: ")
print("[*] Connecting to SSH server...")
transport = paramiko.Transport((REMOTE_HOST, 22))
transport.connect(username=REMOTE_USER, password=password)
sftp = paramiko.SFTPClient.from_transport(transport)

remote_filename = os.path.join(REMOTE_PATH, os.path.basename(zip_path)).replace("\\", "/")
file_size = os.path.getsize(zip_path)
print(f"[*] Uploading {os.path.basename(zip_path)} ({file_size / 1024:.1f} KB)...")

with open(zip_path, "rb") as f:
    progress = tqdm(total=file_size, unit='B', unit_scale=True, desc="Uploading", ncols=70)

    def callback(bytes_transferred, total_bytes):
        progress.update(bytes_transferred - progress.n)

    sftp.putfo(f, remote_filename, callback=callback)
    progress.close()

sftp.close()
transport.close()
print(f"[+] Uploaded to: {remote_filename}")

# === Step 7: Sync website ===
print(f"[*] Calling sync URL: {SYNC_URL}")
resp = requests.get(SYNC_URL)
if resp.status_code != 200:
    raise RuntimeError(f"Sync failed with status {resp.status_code}")
print("[+] Sync successful.")

print(f"[✔] Build/export/upload complete: {release_dir}")
