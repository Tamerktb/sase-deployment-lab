#!/usr/bin/env python3
"""Generate SASE architecture diagram using Diagrams library."""

from diagrams import Diagram, Cluster, Edge
from diagrams.programming.flowchart import Action, Decision
from diagrams.generic.network import VPN, Router
from diagrams.generic.storage import Storage
from diagrams.generic.database import SQL
from diagrams.onprem.security import Vault
from diagrams.onprem.network import Nginx
from diagrams.onprem.compute import Server
from diagrams.onprem.container import Docker
from diagrams.onprem.database import PostgreSQL
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
        "WireGuard Encrypted Mesh (Site-to-Site)",
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
        site_a_wg = Server("Site-A\nAmman, Jordan\n10.0.1.0/24")
        hub_wg = Router("Hub\nAWS eu-central-1\n10.0.0.0/24")
        site_b_wg = Server("Site-B\nDubai, UAE\n10.0.2.0/24")

        site_a_wg >> Edge(color="#1565C0", penwidth="3") >> hub_wg
        hub_wg >> Edge(color="#1565C0", penwidth="3") >> site_b_wg

    # ── Site-A Services ────────────────────────────────────────────
    with Cluster(
        "Site-A (Amman)",
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
        site_a_tunnel = Docker("cloudflared\n(site-a-tunnel)")

    # ── Site-B Services ────────────────────────────────────────────
    with Cluster(
        "Site-B (Dubai)",
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
        site_b_tunnel = Docker("cloudflared\n(site-b-tunnel)")

    # ── Hub Services ───────────────────────────────────────────────
    with Cluster(
        "Hub (AWS eu-central-1)",
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
        hub_tunnel = Docker("cloudflared\n(hub-tunnel)")

    # ── Posture & Compliance ───────────────────────────────────────
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
        posture_scripts = Storage("Scripts:\nposture_checker.py\nwindows-posture.ps1\nlinux-posture.sh")

    # ── Data Flows ─────────────────────────────────────────────────
    # PATH 1: Remote User → Cloudflare Zero Trust → cloudflared → Services
    device_posture >> Edge(color="#BF360C", style="dashed", penwidth="2") >> posture_gw
    posture_gw >> Edge(color="#BF360C", style="dashed", penwidth="2") >> posture_scripts
    device_posture >> Edge(color="#F38020", penwidth="3") >> cf_access

    cf_tunnel >> Edge(color="#F38020", penwidth="2", label="Tunnel #1") >> site_a_tunnel
    cf_tunnel >> Edge(color="#F38020", penwidth="2", label="Tunnel #2") >> site_b_tunnel
    cf_tunnel >> Edge(color="#F38020", penwidth="2", label="Tunnel #3") >> hub_tunnel

    site_a_tunnel >> Edge(color="#E65100", penwidth="2") >> site_a_web
    site_a_tunnel >> Edge(color="#E65100", penwidth="2") >> site_a_api
    site_b_tunnel >> Edge(color="#6A1B9A", penwidth="2") >> site_b_web
    site_b_tunnel >> Edge(color="#6A1B9A", penwidth="2") >> site_b_db
    hub_tunnel >> Edge(color="#283593", penwidth="2") >> hub_monitor

    # PATH 2: WireGuard Mesh (site-to-site, independent of Cloudflare)
    site_a_web >> Edge(color="#1565C0", style="dotted", penwidth="2", label="site-to-site") >> site_a_wg
    site_b_web >> Edge(color="#1565C0", style="dotted", penwidth="2", label="site-to-site") >> site_b_wg
    hub_monitor >> Edge(color="#1565C0", style="dotted", penwidth="2", label="site-to-site") >> hub_wg

    # ── Legend ─────────────────────────────────────────────────────
    with Cluster(
        "Traffic Types",
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
        Action("User → Cloudflare\n(Identity + Filtering)")
        Action("Cloudflare → Site\n(Encrypted Tunnel)")
        Action("Site ↔ Site\n(WireGuard Mesh)")

print(f"Architecture diagram saved to: {output_path}.png")
print("NOTE: Docker network (bridge) handles routing inside the simulation.")
print("      WireGuard tunnels are configured but Docker does not route through them.")
print("      cloudflared containers activate when CF_TUNNEL_TOKEN_* env vars are set.")
