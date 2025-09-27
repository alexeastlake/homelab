#!/usr/bin/env python3
import os, sys, tomllib, subprocess, pathlib

def req(cfg, k):
    if k not in cfg: sys.exit(f"Missing config key: {k}")
    return cfg[k]

base = pathlib.Path(__file__).parent
cfg  = tomllib.load(open(base/"borg_backup.toml","rb"))

# --- Check that borg is installed ---
if not shutil.which("borg"):
    sys.exit("Error: borgbackup is not installed.")

repo_raw = req(cfg,"repo")
cron_min = req(cfg,"cron_minute")
cron_hr  = req(cfg,"cron_hour")

repo = repo_raw[6:] if repo_raw.startswith("local:") else repo_raw[4:] if repo_raw.startswith("ssh:") else repo_raw
env  = {**os.environ, "BORG_REPO": repo}

if repo_raw.startswith("local:"):
    pathlib.Path(repo).mkdir(parents=True, exist_ok=True)

# init repo if missing
if subprocess.run(["borg","info"],env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode != 0:
    subprocess.check_call(["borg","init","--encryption=none"], env=env)

# cron.d entry
backup_script = base / "borg_backup_run.py"
cron_file = "/etc/cron.d/borg-backup"
cron_line = f"{cron_min} {cron_hr} * * * root {backup_script} >> /var/log/borg.log 2>&1\n"
cron_contents = (
    "SHELL=/bin/bash\n"
    "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\n\n"
    + cron_line
)
with open(cron_file, "w") as f: f.write(cron_contents)
print(f"[+] Cron job written: {cron_file}")
