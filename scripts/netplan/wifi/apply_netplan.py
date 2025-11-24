#!/usr/bin/env python3
"""
Usage: sudo python3 apply_netplan.py [01-wifi.yaml]

Copies the built file into /etc/netplan/01-wifi.yaml (mode 600),
then runs: netplan generate; netplan try --timeout 10 && netplan apply
"""

import os
import sys
import shutil
import subprocess
from pathlib import Path

def require_root():
    if os.geteuid() != 0:
        print("Run with sudo", file=sys.stderr)
        sys.exit(1)

def script_dir() -> Path:
    return Path(__file__).resolve().parent

def run(cmd: list[str]) -> int:
    return subprocess.run(cmd, check=False).returncode

def main():
    require_root()
    d = script_dir()
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else d / "01-wifi.yaml"
    dest = Path("/etc/netplan/01-wifi.yaml")

    if not src.exists():
        print(f"Missing built file: {src}", file=sys.stderr)
        sys.exit(1)

    # Optional one-line backup if a file already exists
    if dest.exists():
        shutil.copy2(dest, dest.with_suffix(".yaml.bak"))

    shutil.copy2(src, dest)
    os.chmod(dest, 0o600)
    print(f"Installed {src} to {dest}")

    # Apply netplan (mirror your bash flow)
    if run(["netplan", "generate"]) != 0:
        print("netplan generate failed", file=sys.stderr)
        sys.exit(1)

    # try first; only apply if try succeeds
    if run(["netplan", "try", "--timeout", "10"]) == 0:
        if run(["netplan", "apply"]) == 0:
            print("Netplan applied")
        else:
            print("netplan apply failed", file=sys.stderr)
            sys.exit(1)
    else:
        print("netplan try failed or timed out; NOT applying", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
