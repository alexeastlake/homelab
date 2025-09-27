#!/usr/bin/env python3
import os, sys, tomllib, subprocess, socket, pathlib
from datetime import datetime

def req(cfg, k):
    if k not in cfg: sys.exit(f"Missing config key: {k}")
    return cfg[k]

base = pathlib.Path(__file__).parent
cfg  = tomllib.load(open(base/"borg_backup.toml","rb"))

repo_raw      = req(cfg,"repo")
include_dirs  = req(cfg,"include_dirs")
exclude_pats  = req(cfg,"exclude_patterns")
archive_prefix= req(cfg,"archive_prefix")
compression   = req(cfg,"compression")
keep_daily    = str(req(cfg,"keep_daily"))
keep_weekly   = str(req(cfg,"keep_weekly"))
keep_monthly  = str(req(cfg,"keep_monthly"))

repo = repo_raw[6:] if repo_raw.startswith("local:") else repo_raw[4:] if repo_raw.startswith("ssh:") else repo_raw
env  = {**os.environ, "BORG_REPO": repo}

host  = socket.gethostname().split(".")[0]
stamp = datetime.now().strftime("%Y-%m-%d_%H-%M")
arch  = f"{archive_prefix}-{host}-{stamp}"

excl = []
for p in exclude_pats: excl += ["--exclude", p]

create = ["borg","create","--compression",compression, repo+"::"+arch, *include_dirs, *excl]
prune  = ["borg","prune","--list","--prefix",f"{archive_prefix}-{host}-",
          "--keep-daily",keep_daily,"--keep-weekly",keep_weekly,"--keep-monthly",keep_monthly]

rc1 = subprocess.run(create, env=env).returncode
rc2 = subprocess.run(prune,  env=env).returncode
sys.exit(max(rc1, rc2))
