#!/usr/bin/env python3
"""Importe le plan d'adressage défini dans networking/addressing.yml dans NetBox.

Usage:
    NETBOX_URL=https://netbox.s1.lan NETBOX_TOKEN=xxxx \
        ./seed_netbox.py ../networking/addressing.yml

Idempotent : réexécute sans doublonner (get-or-create).
"""
from __future__ import annotations

import os
import sys
import yaml
import requests
import urllib3

urllib3.disable_warnings()

NETBOX_URL = os.environ["NETBOX_URL"].rstrip("/")
NETBOX_TOKEN = os.environ["NETBOX_TOKEN"]
HEADERS = {
    "Authorization": f"Token {NETBOX_TOKEN}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}


def get_or_create(endpoint: str, match: dict, payload: dict) -> dict:
    url = f"{NETBOX_URL}/api/{endpoint}/"
    r = requests.get(url, params=match, headers=HEADERS, verify=False)
    r.raise_for_status()
    results = r.json().get("results", [])
    if results:
        return results[0]
    r = requests.post(url, json=payload, headers=HEADERS, verify=False)
    r.raise_for_status()
    return r.json()


def main(yaml_path: str) -> int:
    with open(yaml_path) as f:
        plan = yaml.safe_load(f)

    for site_key in ("siteA", "siteB"):
        site_data = plan[site_key]
        slug = site_key.lower()
        site = get_or_create(
            "dcim/sites",
            {"slug": slug},
            {"name": site_data["name"], "slug": slug, "status": "active"},
        )
        print(f"[+] Site {site['name']} (id={site['id']})")

        for net_name, net in site_data["networks"].items():
            prefix = get_or_create(
                "ipam/prefixes",
                {"prefix": net["cidr"]},
                {
                    "prefix": net["cidr"],
                    "site": site["id"],
                    "status": "active",
                    "description": net["description"].strip(),
                },
            )
            print(f"    · prefix {prefix['prefix']}")

        for host_name, host in site_data.get("hosts", {}).items():
            ip = host.get("ip") or host.get("ip_lan") or host.get("ip_admin")
            if not ip:
                continue
            addr = f"{ip}/32"
            get_or_create(
                "ipam/ip-addresses",
                {"address": addr},
                {
                    "address": addr,
                    "status": "active",
                    "dns_name": f"{host_name}.{slug}.lan",
                    "description": host["description"].strip(),
                },
            )
            print(f"    · ip {addr} ({host_name})")

    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: seed_netbox.py <addressing.yml>", file=sys.stderr)
        sys.exit(1)
    sys.exit(main(sys.argv[1]))
