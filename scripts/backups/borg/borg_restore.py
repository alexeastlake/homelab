#!/usr/bin/env python3
import os, sys, tomllib, argparse, subprocess, pathlib

def req(cfg, k):
    if k not in cfg: sys.exit(f"Missing config key: {k}")
    return cfg[k]

base = pathlib.Path(__file__).parent
cfg  = tomllib.load(open(base/"borg_backup.toml","rb"))

repo_raw = req(cfg,"repo")
repo = repo_raw[6:] if repo_raw.startswith("local:") else repo_raw[4:] if repo_raw.startswith("ssh:") else repo_raw
env  = {**os.environ, "BORG_REPO": repo}

p = argparse.ArgumentParser()
p.add_argument("--list", action="store_true")
p.add_argument("--archive")
p.add_argument("--to")
p.add_argument("paths", nargs="*")
a = p.parse_args()

if a.list:
    sys.exit(subprocess.run(["borg","list"], env=env).returncode)

if not a.archive or not a.to:
    p.error("--archive and --to required")

dest = pathlib.Path(a.to).resolve()
if str(dest) == "/":
    sys.exit("Refusing to extract to /")
dest.mkdir(parents=True, exist_ok=True)
os.chdir(dest)

cmd = ["borg","extract", repo+"::"+a.archive, "--", *a.paths]
sys.exit(subprocess.run(cmd, env=env).returncode)
