#!/usr/bin/env python3
"""Validate the schema of networking/addressing.yml.

Used in two contexts:
  1. CI (.github/workflows/netbox-validate.yml) on every push that touches
     the file or the netbox role.
  2. Ansible role netbox/seed.yml as a pre-flight check before calling
     seed_netbox.py against the real NetBox API.

Exit codes:
  0 — file is valid
  1 — schema or value error
  2 — file not found / YAML parse error

Usage:
    python3 scripts/netbox/validate-addressing.py [path/to/addressing.yml]

If no path is given, defaults to networking/addressing.yml relative to the
repo root.
"""
from __future__ import annotations

import ipaddress
import pathlib
import re
import sys
from typing import Any

try:
    import yaml
except ImportError:
    print("ERROR: pyyaml is required. Install with: pip install pyyaml",
          file=sys.stderr)
    sys.exit(2)


REQUIRED_TOP_KEYS = ("siteA", "siteB")
REQUIRED_SITE_KEYS = ("name", "description", "networks", "hosts")
REQUIRED_NETWORK_KEYS = ("cidr", "description")
HOST_IP_FIELDS = ("ip", "ip_lan", "ip_admin", "vpn_endpoint")
SITE_KEY_PATTERN = re.compile(r"^site[A-Z]([\-_].+)?$")


class ValidationError(Exception):
    """Raised when the addressing file violates the schema."""


def _err(path: str, message: str) -> ValidationError:
    return ValidationError(f"  ✗ {path} → {message}")


def validate_network(site: str, name: str, network: dict[str, Any]) -> list[str]:
    """Validate a single network entry. Returns a list of warnings (non-fatal)."""
    warnings: list[str] = []
    base = f"{site}.networks.{name}"

    for key in REQUIRED_NETWORK_KEYS:
        if key not in network:
            raise _err(f"{base}", f"missing required key '{key}'")

    cidr = network["cidr"]
    try:
        net = ipaddress.ip_network(cidr, strict=False)
    except (ValueError, TypeError) as exc:
        raise _err(f"{base}.cidr", f"invalid CIDR '{cidr}': {exc}") from exc

    if net.is_loopback or net.is_unspecified:
        raise _err(f"{base}.cidr", f"CIDR '{cidr}' is loopback/unspecified")

    description = network["description"]
    if not isinstance(description, str) or not description.strip():
        warnings.append(f"{base}.description is empty or non-string")
    elif len(description.strip()) < 10:
        warnings.append(f"{base}.description is suspiciously short")

    return warnings


def validate_host(site: str, name: str, host: dict[str, Any]) -> list[str]:
    """Validate a single host entry. Returns warnings."""
    warnings: list[str] = []
    base = f"{site}.hosts.{name}"

    if not isinstance(host, dict):
        raise _err(base, f"host must be a mapping, got {type(host).__name__}")

    ip_keys = [k for k in HOST_IP_FIELDS if k in host]
    if not ip_keys:
        raise _err(base, f"missing at least one IP field "
                         f"(any of {HOST_IP_FIELDS})")

    for ip_key in ip_keys:
        ip = host[ip_key]
        try:
            ipaddress.ip_address(ip)
        except (ValueError, TypeError) as exc:
            raise _err(f"{base}.{ip_key}", f"invalid IP '{ip}': {exc}") from exc

    if "description" not in host:
        warnings.append(f"{base}.description is missing")
    elif not host["description"].strip():
        warnings.append(f"{base}.description is empty")

    return warnings


def validate_site(site_key: str, site: dict[str, Any]) -> list[str]:
    """Validate one site. Returns warnings collected during the walk."""
    warnings: list[str] = []
    base = site_key

    if not SITE_KEY_PATTERN.match(site_key):
        warnings.append(f"site key '{site_key}' should match {SITE_KEY_PATTERN.pattern}")

    if not isinstance(site, dict):
        raise _err(base, f"site must be a mapping, got {type(site).__name__}")

    for key in REQUIRED_SITE_KEYS:
        if key not in site:
            raise _err(base, f"missing required key '{key}'")

    networks = site["networks"]
    if not isinstance(networks, dict) or not networks:
        raise _err(f"{base}.networks", "must be a non-empty mapping")
    for name, net in networks.items():
        warnings += validate_network(site_key, name, net)

    hosts = site["hosts"]
    if not isinstance(hosts, dict) or not hosts:
        raise _err(f"{base}.hosts", "must be a non-empty mapping")
    for name, host in hosts.items():
        warnings += validate_host(site_key, name, host)

    return warnings


def validate(plan: dict[str, Any]) -> list[str]:
    """Full validation. Raises ValidationError on the first hard error;
    returns a list of warnings (non-fatal) otherwise."""
    warnings: list[str] = []

    if not isinstance(plan, dict):
        raise _err("<root>", "top-level YAML must be a mapping")

    missing = [k for k in REQUIRED_TOP_KEYS if k not in plan]
    if missing:
        raise _err("<root>", f"missing required top-level sites: {missing}")

    # Check for cidr collisions across sites (except shared VPN tunnel)
    all_networks: list[tuple[str, ipaddress.IPv4Network]] = []
    for site_key, site in plan.items():
        if not site_key.startswith("site"):
            continue
        warnings += validate_site(site_key, site)
        for name, net in site["networks"].items():
            cidr = ipaddress.ip_network(net["cidr"], strict=False)
            all_networks.append((f"{site_key}.networks.{name}", cidr))

    # Inter-site CIDR overlap check (skip identical VPN tunnel both sides)
    for i, (path_i, cidr_i) in enumerate(all_networks):
        for path_j, cidr_j in all_networks[i + 1:]:
            if cidr_i == cidr_j:
                # Same CIDR on both sides = shared VPN tunnel, accepted
                if "vpn_tunnel" in path_i and "vpn_tunnel" in path_j:
                    continue
                warnings.append(f"identical CIDR {cidr_i} in {path_i} and {path_j}")
            elif cidr_i.overlaps(cidr_j):
                # Allow vpn_tunnel to overlap nothing
                warnings.append(f"overlap between {path_i} ({cidr_i}) "
                                f"and {path_j} ({cidr_j})")

    return warnings


def main(argv: list[str]) -> int:
    if len(argv) > 2:
        print(__doc__, file=sys.stderr)
        return 2

    if len(argv) == 2:
        path = pathlib.Path(argv[1])
    else:
        repo_root = pathlib.Path(__file__).resolve().parents[2]
        path = repo_root / "networking" / "addressing.yml"

    if not path.is_file():
        print(f"ERROR: file not found: {path}", file=sys.stderr)
        return 2

    print(f"→ Validating {path}")

    try:
        plan = yaml.safe_load(path.read_text())
    except yaml.YAMLError as exc:
        print(f"ERROR: YAML parse failed: {exc}", file=sys.stderr)
        return 2

    try:
        warnings = validate(plan)
    except ValidationError as exc:
        print(f"FAILED with schema error:\n{exc}", file=sys.stderr)
        return 1

    sites = [k for k in plan if k.startswith("site")]
    total_networks = sum(len(plan[s]["networks"]) for s in sites)
    total_hosts = sum(len(plan[s]["hosts"]) for s in sites)

    print(f"  ✓ {len(sites)} sites · {total_networks} networks · {total_hosts} hosts")
    if warnings:
        print(f"  ⚠ {len(warnings)} warnings (non-fatal):")
        for w in warnings:
            print(f"      · {w}")
    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
