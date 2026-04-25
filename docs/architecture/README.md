# Architecture — diagrammes

Trois diagrammes au format `.drawio` (ouvrables par <https://app.diagrams.net>)
avec, ci-dessous, un **fallback Mermaid** rendu directement par GitHub.

## 1. Infrastructure globale

Source : [`infra.drawio`](infra.drawio)

```mermaid
flowchart TB
  subgraph Internet
    INET((Internet))
  end
  subgraph SiteA[Site A · on-prem]
    direction TB
    pfsA[pfsense-s1<br/>10.10.0.1 / 10.10.10.1]
    svcA[services-s1<br/>NetBox + webapp<br/>10.10.0.20]
    obsA[observability-s1<br/>Elastic + Kibana + Logstash<br/>10.10.0.30]
  end
  subgraph SiteB[Site B · remote]
    direction TB
    pfsB[pfsense-s2<br/>192.168.0.1 / 192.168.10.1]
    bastB[bastion-s2<br/>SSH MFA<br/>192.168.10.10]
    svcB[services-s2<br/>192.168.10.20]
  end
  INET --- pfsA
  INET --- pfsB
  pfsA -. "VPN UDP/1194<br/>172.16.0.0/30" .- pfsB
  pfsA --- svcA
  pfsA --- obsA
  pfsB --- bastB
  pfsB --- svcB
```

## 2. Tunnel VPN

Source : [`vpn.drawio`](vpn.drawio)

```mermaid
flowchart LR
  A["OpenVPN SERVER<br/>Site A · pfsense-s1<br/>172.16.0.1"]
  B["OpenVPN CLIENT<br/>Site B · pfsense-s2<br/>172.16.0.2"]
  A == "UDP 1194 · AES-256-GCM · SHA256 · tls-crypt" ==> B
  B == "reneg-sec 3600 · TLS 1.2+" ==> A
  V[("Vault PKI<br/>pki_cia_vpn<br/>CA 10 ans / cert 1 an")] --> A
  V --> B
```

## 3. Règles firewall

Source : [`firewall-rules.drawio`](firewall-rules.drawio)

```mermaid
flowchart TB
  KS{{"FLOATING prio 0<br/>block out WAN if KILLSWITCH_ACTIVE"}}
  subgraph WAN["WAN · default block"]
    w1[pfsA pass UDP/1194 OpenVPN]
    w2[pfsB pass TCP/2222 → NAT bastion]
  end
  subgraph LAN["LAN · default block"]
    l1[pass TCP 80,443 → Internet]
    l2[pass UDP 53 → pfSense]
    l3[BLOCK LAN → ADMIN]
  end
  subgraph ADMIN["ADMIN · default block"]
    a1[pass 22,443,8000 → LAN]
    a2[pass 22,2222 → bastion]
  end
  subgraph VPNIF["OpenVPN interface"]
    v1[pass 10.10.0/24 ↔ 192.168.0/24]
    v2[pass 10.10.10/24 ↔ 192.168.10/24]
    v3[block any else]
  end
  KS --> WAN
  KS --> LAN
  KS --> ADMIN
  KS --> VPNIF
```

## 4. Export SVG/PNG

Chaque `.drawio` peut être exporté en SVG depuis draw.io :
`File → Export as → SVG / PNG → Selection only · no background`.
Les exports sont committés sous `docs/architecture/export/` (non montré
ici pour éviter de polluer le diff).
