#!/usr/bin/env python3
"""Generate SASE architecture diagram using Diagrams library."""

from diagrams import Diagram, Cluster, Edge
from diagrams.programming.flowchart import Action, Decision
from diagrams.generic.blank import Blank
from diagrams.generic.network import VPN, Router, Switch
from diagrams.generic.storage import Storage
from diagrams.generic.database import SQL
from diagrams.onprem.security import Vault
from diagrams.onprem.network import Nginx
from diagrams.onprem.compute import Server
from diagrams.onprem.container import Docker
from diagrams.onprem.database import PostgreSQL
from diagrams.aws.security import WAF
from diagrams.aws.network import CloudFront
from diagrams.saas.identity import Okta
from diagrams.custom import Custom
import os

script_dir = os.path.dirname(os.path.abspath(__file__))
output_dir = os.path.join(script_dir, "..")
output_path = os.path.join(output_dir, "architecture")

with Diagram(
    "SASE Deployment Lab — Architecture",
    filename=output_path,
    outformat="png",
    show=False,
    direction="LR",
    graph_attr={
        "bgcolor": "white",
        "pad": "0.5",
        "dpi": "150",
        "fontsize": "28",
        "fontname": "Helvetica Bold",
    },
    edge_attr={
        "color": "#555555",
        "penwidth": "2",
    },
):

    # ── Cloudflare Zero Trust ───────────────────────────────────────
    with Cluster(
        "Cloudflare Zero Trust (Global Network)",
        graph_attr={
            "style": "filled",
            "fillcolor": "#F38020",
            "fontcolor": "white",
            "fontsize": "18",
            "fontname": "Helvetica Bold",
            "rounded": "true",
            "penwidth": "3",
        },
    ):
        cf_access = Action("Access Policies\n(SSO / Identity)")
        cf_gateway = Action("Gateway\n(DNS/HTTP Filter)")
        cf_tunnel = VPN("Cloudflare\nTunnel")

        cf_access >> cf_gateway >> cf_tunnel

    # ── Users ──────────────────────────────────────────────────────
    with Cluster(
        "Users & Devices",
        graph_attr={
            "style": "filled",
            "fillcolor": "#E8F5E9",
            "fontcolor": "#2E7D32",
            "fontsize": "16",
            "fontname": "Helvetica Bold",
            "rounded": "true",
            "penwidth": "2",
        },
    ):
        remote_user = Action("Remote\nUser")
        device_posture = Decision("Posture\nCheck")
        warp = Action("WARP\nClient")

        remote_user >> Edge(color="#2E7D32", penwidth="2") >> warp
        warp >> Edge(color="#2E7D32", penwidth="2") >> device_posture

    # ── WireGuard Mesh ─────────────────────────────────────────────
    with Cluster(
        "WireGuard Encrypted Mesh (IPSec-like tunnel)",
        graph_attr={
            "style": "filled",
            "fillcolor": "#E3F2FD",
            "fontcolor": "#1565C0",
            "fontsize": "16",
            "fontname": "Helvetica Bold",
            "rounded": "true",
            "penwidth": "2",
        },
    ):
        site_a = Server("Site-A\nAmman, Jordan\n10.0.1.0/24")
        hub = Server("Hub\nAWS eu-central-1\n10.0.0.0/24")
        site_b = Server("Site-B\nDubai, UAE\n10.0.2.0/24")

        site_a >> Edge(color="#1565C0", penwidth="3") >> hub
        hub >> Edge(color="#1565C0", penwidth="3") >> site_b

    # ── Site Services ──────────────────────────────────────────────
    with Cluster(
        "Site-A Services (Amman)",
        graph_attr={
            "style": "filled",
            "fillcolor": "#FFF3E0",
            "fontcolor": "#E65100",
            "fontsize": "14",
            "fontname": "Helvetica Bold",
            "rounded": "true",
            "penwidth": "1.5",
        },
    ):
        site_a_web = Nginx("Web Server\n(site-a-web)")
        site_a_api = Docker("API Server\n(site-a-api)")

    with Cluster(
        "Site-B Services (Dubai)",
        graph_attr={
            "style": "filled",
            "fillcolor": "#F3E5F5",
            "fontcolor": "#6A1B9A",
            "fontsize": "14",
            "fontname": "Helvetica Bold",
            "rounded": "true",
            "penwidth": "1.5",
        },
    ):
        site_b_web = Nginx("Web Server\n(site-b-web)")
        site_b_db = SQL("PostgreSQL\n(site-b-db)")

    with Cluster(
        "Hub Services (AWS)",
        graph_attr={
            "style": "filled",
            "fillcolor": "#E8EAF6",
            "fontcolor": "#283593",
            "fontsize": "14",
            "fontname": "Helvetica Bold",
            "rounded": "true",
            "penwidth": "1.5",
        },
    ):
        hub_monitor = Nginx("Monitoring\n(hub-monitor)")
        wg_hub = Router("WireGuard\n(wg-hub)")

    # ── Posture Gateway ────────────────────────────────────────────
    with Cluster(
        "Posture & Compliance",
        graph_attr={
            "style": "filled",
            "fillcolor": "#FBE9E7",
            "fontcolor": "#BF360C",
            "fontsize": "14",
            "fontname": "Helvetica Bold",
            "rounded": "true",
            "penwidth": "1.5",
        },
    ):
        posture_gw = Vault("Posture\nGateway")
        posture_scripts = Storage("Scripts:\nposture-checker.py\nwindows-posture.ps1\nlinux-posture.sh")

    # ── Connections ────────────────────────────────────────────────
    device_posture >> Edge(color="#BF360C", style="dashed", penwidth="2") >> posture_gw
    posture_gw >> Edge(color="#BF360C", style="dashed", penwidth="2") >> posture_scripts

    device_posture >> Edge(color="#F38020", penwidth="3") >> cf_access

    cf_tunnel >> Edge(color="#F38020", penwidth="3") >> wg_hub

    wg_hub >> Edge(color="#1565C0", penwidth="2") >> site_a
    wg_hub >> Edge(color="#1565C0", penwidth="2") >> site_b

    site_a >> Edge(color="#E65100", penwidth="2") >> site_a_web
    site_a >> Edge(color="#E65100", penwidth="2") >> site_a_api
    site_b >> Edge(color="#6A1B9A", penwidth="2") >> site_b_web
    site_b >> Edge(color="#6A1B9A", penwidth="2") >> site_b_db
    hub >> Edge(color="#283593", penwidth="2") >> hub_monitor

    # ── Split-Tunnel ──────────────────────────────────────────────
    with Cluster(
        "Split-Tunneling",
        graph_attr={
            "style": "dashed",
            "fillcolor": "#F5F5F5",
            "fontcolor": "#424242",
            "fontsize": "14",
            "fontname": "Helvetica Bold",
            "rounded": "true",
            "penwidth": "2",
        },
    ):
        corp_traffic = Action("Corporate Traffic\n10.0.0.0/8\n→ Tunnel")
        internet_traffic = Action("Internet Traffic\n0.0.0.0/0\n→ Direct (ISP)")

print(f"Architecture diagram saved to: {output_path}.png")
