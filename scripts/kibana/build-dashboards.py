#!/usr/bin/env python3
"""Build CIA Kibana dashboards as ndjson (importable via Stack Management).

Génère 2 dashboards basés sur le template du Dashboard #2 SSH Security Monitor :
  - CIA — OpenVPN Activity (5 panels)
  - CIA — Network Activity (pfSense + DNS) (5 panels)

Output:
  infra/kibana/dashboards/cia-openvpn-activity.ndjson
  infra/kibana/dashboards/cia-network-activity.ndjson

Réutilise la data view "CIA Logs" (id=919d9619-bb2b-420c-8a28-dd46bd61b06b)
et les tags existants (cia, runtime, security/observability).
"""
import json
import pathlib
import uuid
from datetime import datetime, timezone

REPO = pathlib.Path(__file__).resolve().parents[2]
OUT_DIR = REPO / "infra" / "kibana" / "dashboards"

# Data view + tags référencés (créés par les dashboards précédents)
DATAVIEW_ID = "919d9619-bb2b-420c-8a28-dd46bd61b06b"
TAG_CIA = "870bc1f0-6cd3-11f1-b80e-6bec9004d269"
TAG_RUNTIME = "8d7461f0-6cd3-11f1-b80e-6bec9004d269"
TAG_SECURITY = "f92645c0-6ced-11f1-b80e-6bec9004d269"

NOW = datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def new_id() -> str:
    return str(uuid.uuid4())


def lens_metric_panel(*, panel_id, layer_id, col_id, x, y, w, h, title, kql=""):
    """Génère un panneau Lens Metric (gros chiffre = count of records filtré KQL)."""
    return {
        "type": "lens",
        "gridData": {"x": x, "y": y, "w": w, "h": h, "i": panel_id},
        "panelIndex": panel_id,
        "embeddableConfig": {
            "attributes": {
                "title": "",
                "description": "",
                "visualizationType": "lnsMetric",
                "type": "lens",
                "references": [{
                    "type": "index-pattern",
                    "id": DATAVIEW_ID,
                    "name": f"indexpattern-datasource-layer-{layer_id}",
                }],
                "state": {
                    "visualization": {
                        "layerId": layer_id,
                        "layerType": "data",
                        "metricAccessor": col_id,
                    },
                    "query": {"query": kql, "language": "kuery"},
                    "filters": [],
                    "datasourceStates": {
                        "formBased": {
                            "layers": {
                                layer_id: {
                                    "columns": {
                                        col_id: {
                                            "label": "Count of records",
                                            "dataType": "number",
                                            "operationType": "count",
                                            "isBucketed": False,
                                            "scale": "ratio",
                                            "sourceField": "___records___",
                                            "params": {"emptyAsNull": True},
                                        }
                                    },
                                    "columnOrder": [col_id],
                                    "sampling": 1,
                                    "ignoreGlobalFilters": False,
                                    "incompleteColumns": {},
                                }
                            }
                        },
                        "indexpattern": {"layers": {}},
                        "textBased": {"layers": {}},
                    },
                    "internalReferences": [],
                    "adHocDataViews": {},
                },
            },
            "hidePanelTitles": False,
            "enhancements": {},
        },
        "title": title,
    }


def lens_line_panel(*, panel_id, layer_id, ts_col, count_col, x, y, w, h, title, kql=""):
    """Génère un panneau Lens Line chart (date_histogram x count)."""
    return {
        "type": "lens",
        "gridData": {"x": x, "y": y, "w": w, "h": h, "i": panel_id},
        "panelIndex": panel_id,
        "embeddableConfig": {
            "attributes": {
                "title": "",
                "description": "",
                "visualizationType": "lnsXY",
                "type": "lens",
                "references": [{
                    "type": "index-pattern",
                    "id": DATAVIEW_ID,
                    "name": f"indexpattern-datasource-layer-{layer_id}",
                }],
                "state": {
                    "visualization": {
                        "legend": {"isVisible": True, "position": "right"},
                        "valueLabels": "hide",
                        "fittingFunction": "None",
                        "preferredSeriesType": "line",
                        "layers": [{
                            "layerId": layer_id,
                            "seriesType": "line",
                            "xAccessor": ts_col,
                            "accessors": [count_col],
                            "layerType": "data",
                        }],
                    },
                    "query": {"query": kql, "language": "kuery"},
                    "filters": [],
                    "datasourceStates": {
                        "formBased": {
                            "layers": {
                                layer_id: {
                                    "columns": {
                                        ts_col: {
                                            "label": "@timestamp",
                                            "dataType": "date",
                                            "operationType": "date_histogram",
                                            "sourceField": "@timestamp",
                                            "isBucketed": True,
                                            "scale": "interval",
                                            "params": {
                                                "interval": "auto",
                                                "includeEmptyRows": True,
                                                "dropPartials": False,
                                            },
                                        },
                                        count_col: {
                                            "label": "Count of records",
                                            "dataType": "number",
                                            "operationType": "count",
                                            "isBucketed": False,
                                            "scale": "ratio",
                                            "sourceField": "___records___",
                                            "params": {"emptyAsNull": True},
                                        },
                                    },
                                    "columnOrder": [ts_col, count_col],
                                    "sampling": 1,
                                    "ignoreGlobalFilters": False,
                                    "incompleteColumns": {},
                                }
                            }
                        },
                        "indexpattern": {"layers": {}},
                        "textBased": {"layers": {}},
                    },
                    "internalReferences": [],
                    "adHocDataViews": {},
                },
            },
            "hidePanelTitles": False,
            "enhancements": {},
        },
        "title": title,
    }


def lens_table_panel(*, panel_id, layer_id, term_col, count_col, x, y, w, h,
                     title, term_field, term_label, term_size=10, kql=""):
    """Lens Datatable : terms aggregation + count."""
    return {
        "type": "lens",
        "gridData": {"x": x, "y": y, "w": w, "h": h, "i": panel_id},
        "panelIndex": panel_id,
        "embeddableConfig": {
            "attributes": {
                "title": "",
                "description": "",
                "visualizationType": "lnsDatatable",
                "type": "lens",
                "references": [{
                    "type": "index-pattern",
                    "id": DATAVIEW_ID,
                    "name": f"indexpattern-datasource-layer-{layer_id}",
                }],
                "state": {
                    "visualization": {
                        "columns": [
                            {"columnId": term_col, "isTransposed": False},
                            {"columnId": count_col, "isTransposed": False},
                        ],
                        "layerId": layer_id,
                        "layerType": "data",
                    },
                    "query": {"query": kql, "language": "kuery"},
                    "filters": [],
                    "datasourceStates": {
                        "formBased": {
                            "layers": {
                                layer_id: {
                                    "columns": {
                                        term_col: {
                                            "label": term_label,
                                            "dataType": "string",
                                            "operationType": "terms",
                                            "scale": "ordinal",
                                            "sourceField": term_field,
                                            "isBucketed": True,
                                            "params": {
                                                "size": term_size,
                                                "orderBy": {"type": "column", "columnId": count_col},
                                                "orderDirection": "desc",
                                                "otherBucket": True,
                                                "missingBucket": False,
                                                "parentFormat": {"id": "terms"},
                                                "include": [],
                                                "exclude": [],
                                                "includeIsRegex": False,
                                                "excludeIsRegex": False,
                                            },
                                        },
                                        count_col: {
                                            "label": "Count of records",
                                            "dataType": "number",
                                            "operationType": "count",
                                            "isBucketed": False,
                                            "scale": "ratio",
                                            "sourceField": "___records___",
                                            "params": {"emptyAsNull": True},
                                        },
                                    },
                                    "columnOrder": [term_col, count_col],
                                    "sampling": 1,
                                    "ignoreGlobalFilters": False,
                                    "incompleteColumns": {},
                                }
                            }
                        },
                        "indexpattern": {"layers": {}},
                        "textBased": {"layers": {}},
                    },
                    "internalReferences": [],
                    "adHocDataViews": {},
                },
            },
            "hidePanelTitles": False,
            "enhancements": {},
        },
        "title": title,
    }


def build_dashboard(*, db_id, title, description, panels, tags):
    """Wrap les panels dans un objet dashboard saved object."""
    references = []
    # Une référence index-pattern par layer
    for p in panels:
        for ref in p["embeddableConfig"]["attributes"]["references"]:
            references.append({
                "id": ref["id"],
                "name": f"{p['panelIndex']}:{ref['name']}",
                "type": ref["type"],
            })
    for tag in tags:
        references.append({
            "id": tag,
            "name": f"tag-ref-{tag}",
            "type": "tag",
        })

    return {
        "attributes": {
            "description": description,
            "kibanaSavedObjectMeta": {
                "searchSourceJSON": json.dumps({"query": {"query": "", "language": "kuery"}, "filter": []})
            },
            "optionsJSON": json.dumps({
                "useMargins": True,
                "syncColors": False,
                "syncCursor": True,
                "syncTooltips": False,
                "hidePanelTitles": False,
            }),
            "panelsJSON": json.dumps(panels),
            "timeRestore": False,
            "title": title,
            "version": 1,
        },
        "coreMigrationVersion": "8.8.0",
        "created_at": NOW,
        "id": db_id,
        "managed": False,
        "references": references,
        "type": "dashboard",
        "typeMigrationVersion": "8.9.0",
        "updated_at": NOW,
        "version": "WzEsMV0=",
    }


# ============================================================================
# DASHBOARD #3 — CIA — OpenVPN Activity
# ============================================================================

def build_openvpn_dashboard():
    db_id = new_id()
    panels = [
        # Row 1 : 3 metrics côte-à-côte
        lens_metric_panel(
            panel_id=new_id(), layer_id=new_id(), col_id=new_id(),
            x=0, y=0, w=16, h=10,
            title="Total OpenVPN events 24h",
            kql='message: "openvpn"',
        ),
        lens_metric_panel(
            panel_id=new_id(), layer_id=new_id(), col_id=new_id(),
            x=16, y=0, w=16, h=10,
            title="Connexions OpenVPN établies",
            kql='message: ("openvpn" AND "connected")',
        ),
        lens_metric_panel(
            panel_id=new_id(), layer_id=new_id(), col_id=new_id(),
            x=32, y=0, w=16, h=10,
            title="Cert verification FAILED",
            kql='message: ("openvpn" AND "FAILED")',
        ),
        # Row 2 : Timeline pleine largeur
        lens_line_panel(
            panel_id=new_id(), layer_id=new_id(), ts_col=new_id(), count_col=new_id(),
            x=0, y=10, w=48, h=12,
            title="Timeline OpenVPN events / heure (24h)",
            kql='message: "openvpn"',
        ),
    ]
    return build_dashboard(
        db_id=db_id,
        title="CIA — OpenVPN Activity — services-s2",
        description=(
            "Dashboard runtime FW3-Final : volume + état connexions + échecs cert OpenVPN. "
            "Source: logs synthétiques 'logger -t openvpn' sur services-s2 (TODO: brancher "
            "Filebeat module openvpn sur pfsense-s1 quand runtime école débloqué). "
            "Pattern KQL standard, restituera les logs réels sans modification."
        ),
        panels=panels,
        tags=[TAG_CIA, TAG_RUNTIME],
    )


# ============================================================================
# DASHBOARD #4 — CIA — Network Activity (pfSense + DNS)
# ============================================================================

def build_network_dashboard():
    db_id = new_id()
    panels = [
        # Row 1 : 4 metrics (pfSense blocks/pass, DNS total/nxdomain)
        lens_metric_panel(
            panel_id=new_id(), layer_id=new_id(), col_id=new_id(),
            x=0, y=0, w=12, h=10,
            title="pfSense blocks 24h",
            kql='message: ("filterlog" AND "block")',
        ),
        lens_metric_panel(
            panel_id=new_id(), layer_id=new_id(), col_id=new_id(),
            x=12, y=0, w=12, h=10,
            title="pfSense pass 24h",
            kql='message: ("filterlog" AND "pass")',
        ),
        lens_metric_panel(
            panel_id=new_id(), layer_id=new_id(), col_id=new_id(),
            x=24, y=0, w=12, h=10,
            title="DNS queries 24h",
            kql='message: "unbound"',
        ),
        lens_metric_panel(
            panel_id=new_id(), layer_id=new_id(), col_id=new_id(),
            x=36, y=0, w=12, h=10,
            title="DNS NXDOMAIN 24h",
            kql='message: ("unbound" AND "NXDOMAIN")',
        ),
        # Row 2 : Timeline réseau
        lens_line_panel(
            panel_id=new_id(), layer_id=new_id(), ts_col=new_id(), count_col=new_id(),
            x=0, y=10, w=24, h=14,
            title="Timeline pfSense activity (24h)",
            kql='message: "filterlog"',
        ),
        lens_line_panel(
            panel_id=new_id(), layer_id=new_id(), ts_col=new_id(), count_col=new_id(),
            x=24, y=10, w=24, h=14,
            title="Timeline DNS queries (24h)",
            kql='message: "unbound"',
        ),
    ]
    return build_dashboard(
        db_id=db_id,
        title="CIA — Network Activity (pfSense + DNS) — services-s2",
        description=(
            "Dashboard runtime FW3-Final : activité réseau pfSense (block/pass) + résolveur DNS unbound. "
            "Source: logs synthétiques 'logger -t pfsense/unbound' sur services-s2. "
            "Branchera automatiquement les logs réels filebeat pfsense + unbound dès runtime école débloqué."
        ),
        panels=panels,
        tags=[TAG_CIA, TAG_RUNTIME, TAG_SECURITY],
    )


# ============================================================================
# Wrap dans un export ndjson Kibana (avec metadata footer)
# ============================================================================

def export_ndjson(filename: str, *objects):
    path = OUT_DIR / filename
    with path.open("w", encoding="utf-8") as fh:
        for obj in objects:
            fh.write(json.dumps(obj, ensure_ascii=False) + "\n")
        # Footer metadata Kibana export
        footer = {
            "excludedObjects": [],
            "excludedObjectsCount": 0,
            "exportedCount": len(objects),
            "missingRefCount": 0,
            "missingReferences": [],
        }
        fh.write(json.dumps(footer) + "\n")
    print(f"  ✓ {path.relative_to(REPO)}  ({len(objects)} objets + footer)")


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    print(f"→ Building dashboards into {OUT_DIR.relative_to(REPO)}/")
    print()

    db_vpn = build_openvpn_dashboard()
    export_ndjson("cia-openvpn-activity.ndjson", db_vpn)

    db_net = build_network_dashboard()
    export_ndjson("cia-network-activity.ndjson", db_net)

    print()
    print("Import via : Stack Management → Saved Objects → Import → select files")
    print("Le data view 'CIA Logs' + tags cia/runtime/security existent déjà.")


if __name__ == "__main__":
    main()
