#!/usr/bin/env python3
# setup_srv_dirs.py
# Usage: sudo python3 setup_srv_dirs.py

import os
import pwd
import grp
from pathlib import Path

def require_root():
    if os.geteuid() != 0:
        print("Run with sudo: sudo python3 setup_srv_dirs.py")
        exit(1)

def main():
    require_root()

    user = os.environ.get("SUDO_USER") or os.environ.get("USER")
    uid = pwd.getpwnam(user).pw_uid
    gid = pwd.getpwnam(user).pw_gid

    dirs = {
        "/srv/data":    (0o750, uid, gid),
        "/srv/secrets": (0o700, 0,   0),
        "/srv/backup":  (0o750, uid, gid),
    }

    for path, (mode, u, g) in dirs.items():
        p = Path(path)
        p.mkdir(parents=True, exist_ok=True)
        os.chmod(p, mode)
        os.chown(p, u, g)
        print(f"{path} (mode {oct(mode)[-3:]}, owner {pwd.getpwuid(u).pw_name}:{grp.getgrgid(g).gr_name})")

if __name__ == "__main__":
    main()
