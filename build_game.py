import os
import re
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
# Same pattern the website uses to register versions (4+ numbers separated by dots)
VERSION_ZIP_PATTERN = re.compile(r"^\d+(?:\.\d+){3,}\.zip$")
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
# Searched in order for a Godot executable; set the GODOT_EXE environment variable to override
GODOT_SEARCH_DIRS = [SCRIPT_DIR, os.path.join(os.path.expanduser("~"), "Desktop")]


def find_godot():
    env_path = os.environ.get("GODOT_EXE")
    if env_path:
        if os.path.isfile(env_path):
            return env_path
        raise FileNotFoundError(f"GODOT_EXE is set but does not exist: {env_path}")
    for folder in GODOT_SEARCH_DIRS:
        if not os.path.isdir(folder):
            continue
        # Newest version first, and skip the *_console.exe wrapper
        candidates = sorted(
            (f for f in os.listdir(folder)
             if f.lower().endswith(".exe") and "godot" in f.lower() and "console" not in f.lower()),
            reverse=True)
        if candidates:
            return os.path.join(folder, candidates[0])
    on_path = shutil.which("godot")
    if on_path:
        return on_path
    raise FileNotFoundError(
        "No Godot executable found. Looked in: " + ", ".join(GODOT_SEARCH_DIRS)
        + " and PATH. Set GODOT_EXE to the full path of your Godot .exe.")


def check_export_templates(godot_path):
    # "4.6.1.stable.official.abc123" -> templates live in .../export_templates/4.6.1.stable
    version = subprocess.run([godot_path, "--version"], capture_output=True, text=True).stdout.strip()
    parts = version.split(".")
    if len(parts) < 3:
        print(f"[!] Could not read Godot version ({version!r}), skipping export template check.")
        return
    template_name = ".".join(parts[:-2]) if len(parts) > 3 else ".".join(parts[:3])
    template_dir = os.path.join(os.environ.get("APPDATA", ""), "Godot", "export_templates", template_name)
    if not os.path.isdir(template_dir):
        raise FileNotFoundError(
            f"Export templates for Godot {template_name} are not installed (expected {template_dir}). "
            "Open the Godot editor > Editor > Manage Export Templates > Download and Install.")
    print(f"[+] Export templates found: {template_dir}")


print("[*] Starting build and upload process...")

# === Step 1: Find Godot executable ===
print("[*] Locating Godot executable...")
godot_exe = find_godot()
print(f"[+] Found Godot executable: {godot_exe}")
check_export_templates(godot_exe)

# === Step 2: Create dated folder ===
today = datetime.today()
base_date = f"{today.strftime('%y')}.{today.month}.{today.day}"  # YY.M.D
release_dir = os.path.join(EXPORT_FOLDER, base_date)
print(f"[*] Creating release folder for version: {base_date}")

# Always YY.M.D.N: the website only registers versions with 4+ numbers
for i in range(1, 100):
    final_dir = f"{release_dir}.{i}"
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

# === Step 8: Remove older version zips from the server ===
uploaded_name = os.path.basename(zip_path)
if not VERSION_ZIP_PATTERN.match(uploaded_name):
    print(f"[!] {uploaded_name} does not match the website's version pattern, skipping cleanup.")
else:
    print("[*] Removing older versions from the server...")
    transport = paramiko.Transport((REMOTE_HOST, 22))
    transport.connect(username=REMOTE_USER, password=password)
    sftp = paramiko.SFTPClient.from_transport(transport)
    try:
        # Only clean up once the new upload is confirmed complete on the server
        remote_size = sftp.stat(remote_filename).st_size
        if remote_size != file_size:
            raise RuntimeError(f"Uploaded size {remote_size} does not match local size {file_size}, not deleting anything.")

        removed = 0
        for name in sftp.listdir(REMOTE_PATH):
            if name == uploaded_name or not VERSION_ZIP_PATTERN.match(name):
                continue
            sftp.remove(f"{REMOTE_PATH}/{name}")
            removed += 1
            print(f"[-] Removed old version: {name}")
    finally:
        sftp.close()
        transport.close()
    print(f"[+] Cleanup complete, removed {removed} old version(s).")

print(f"[✔] Build/export/upload complete: {release_dir}")
