#!/usr/bin/env python3
"""
Usage: sudo python3 build_netplan.py [wifi.env] [wifi.yaml.tpl]

Reads a simple KEY=VALUE env file and substitutes ${VARS} in the template.
Writes 01-wifi.yaml next to this script with mode 600.
"""

import os
import sys
from pathlib import Path
from string import Template

def require_root():
    if os.geteuid() != 0:
        print("Run with sudo", file=sys.stderr)
        sys.exit(1)

def script_dir() -> Path:
    return Path(__file__).resolve().parent

def parse_env(path: Path) -> dict:
    """Parse KEY=VALUE lines; ignore blanks and lines starting with #."""
    env = {}
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip()
    return env

def main():
    require_root()
    d = script_dir()
    env_path = Path(sys.argv[1]) if len(sys.argv) > 1 else d / "wifi.env"
    tpl_path = Path(sys.argv[2]) if len(sys.argv) > 2 else d / "wifi.yaml.tpl"
    out_path = d / "01-wifi.yaml"

    if not env_path.exists():
        print(f"Missing env file: {env_path}", file=sys.stderr)
        sys.exit(1)
    if not tpl_path.exists():
        print(f"Missing template file: {tpl_path}", file=sys.stderr)
        sys.exit(1)

    vars_map = parse_env(env_path)
    tpl_text = tpl_path.read_text()
    try:
        rendered = Template(tpl_text).substitute(vars_map)
    except KeyError as e:
        print(f"Missing variable in env: {e}", file=sys.stderr)
        sys.exit(1)

    out_path.write_text(rendered)
    os.chmod(out_path, 0o600)
    print(f"Wrote {out_path}")

if __name__ == "__main__":
    main()
