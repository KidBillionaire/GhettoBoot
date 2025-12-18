#!/bin/bash

################################################################################
# GhettoBoot WiFi Honeypot
# Purpose: Create fake WiFi network that traps attackers
#          Connections allowed but all requests return smiley faces or fail
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
FAKE_SSID="${FAKE_SSID:-SpectrumSetup-1A-Plus}"
HONEYPOT_INTERFACE="${HONEYPOT_INTERFACE:-wlan0}"
HONEYPOT_IP="10.0.66.1"
HONEYPOT_SUBNET="10.0.66.0/24"
DHCP_RANGE_START="10.0.66.10"
DHCP_RANGE_END="10.0.66.250"
WIFI_LOG="/var/log/wifi-honeypot.log"
CONNECTION_LOG="/var/log/wifi-connections.log"

################################################################################
# Logging
################################################################################

log_wifi() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$WIFI_LOG"
    echo -e "${CYAN}[WIFI-HONEYPOT]${NC} $message"
}

log_connection() {
    local mac="$1"
    local ip="$2"
    local hostname="$3"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] MAC:$mac IP:$ip HOST:$hostname" >> "$CONNECTION_LOG"
    echo -e "${YELLOW}[CONNECTION]${NC} Device connected: $mac ($ip)"
}

log_request() {
    local ip="$1"
    local request="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FROM:$ip REQUEST:$request" >> "$WIFI_LOG"
}

################################################################################
# Network Setup
################################################################################

check_dependencies() {
    log_wifi "Checking dependencies..."

    local deps=(hostapd dnsmasq iptables)
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${RED}Missing dependencies: ${missing[*]}${NC}"
        echo "Install with: apt-get install hostapd dnsmasq iptables"
        exit 1
    fi

    log_wifi "All dependencies satisfied"
}

setup_interface() {
    log_wifi "Setting up honeypot interface..."

    # Stop NetworkManager from managing the interface
    if systemctl is-active --quiet NetworkManager; then
        nmcli device set "$HONEYPOT_INTERFACE" managed no 2>/dev/null || true
    fi

    # Bring interface down
    ip link set "$HONEYPOT_INTERFACE" down 2>/dev/null || true

    # Configure interface
    ip addr flush dev "$HONEYPOT_INTERFACE"
    ip addr add "$HONEYPOT_IP/24" dev "$HONEYPOT_INTERFACE"
    ip link set "$HONEYPOT_INTERFACE" up

    log_wifi "Interface configured: $HONEYPOT_INTERFACE ($HONEYPOT_IP)"
}

create_hostapd_config() {
    log_wifi "Creating fake AP configuration..."

    cat > /tmp/hostapd-honeypot.conf <<EOF
# GhettoBoot WiFi Honeypot Configuration
interface=$HONEYPOT_INTERFACE
driver=nl80211

# Network name (looks legitimate)
ssid=$FAKE_SSID
hw_mode=g
channel=6
ieee80211n=1

# Open network (no password - looks like setup mode)
auth_algs=1
wpa=0

# Beacon settings
beacon_int=100
dtim_period=2

# Logging
logger_syslog=-1
logger_syslog_level=2
logger_stdout=-1
logger_stdout_level=2
EOF

    log_wifi "Created AP config: $FAKE_SSID (open network)"
}

create_dnsmasq_config() {
    log_wifi "Creating DHCP/DNS honeypot configuration..."

    cat > /tmp/dnsmasq-honeypot.conf <<EOF
# GhettoBoot WiFi Honeypot DNS/DHCP
interface=$HONEYPOT_INTERFACE
dhcp-range=$DHCP_RANGE_START,$DHCP_RANGE_END,12h
dhcp-option=3,$HONEYPOT_IP
dhcp-option=6,$HONEYPOT_IP

# Log all DHCP requests
log-dhcp
log-queries

# Bind to honeypot interface only
bind-interfaces
listen-address=$HONEYPOT_IP

# DNS - return our IP for everything (captive portal)
address=/#/$HONEYPOT_IP

# Additional logging
log-facility=$WIFI_LOG
EOF

    log_wifi "DHCP range: $DHCP_RANGE_START - $DHCP_RANGE_END"
}

setup_firewall_rules() {
    log_wifi "Setting up firewall rules..."

    # Flush existing rules for honeypot interface
    iptables -t nat -D POSTROUTING -s "$HONEYPOT_SUBNET" -j MASQUERADE 2>/dev/null || true
    iptables -D FORWARD -i "$HONEYPOT_INTERFACE" -j ACCEPT 2>/dev/null || true

    # Drop all forwarding from honeypot (no internet access)
    iptables -I FORWARD -i "$HONEYPOT_INTERFACE" -j DROP

    # Allow DNS and DHCP to our honeypot server
    iptables -I INPUT -i "$HONEYPOT_INTERFACE" -p udp --dport 53 -j ACCEPT
    iptables -I INPUT -i "$HONEYPOT_INTERFACE" -p udp --dport 67 -j ACCEPT

    # Allow HTTP/HTTPS to our fake server
    iptables -I INPUT -i "$HONEYPOT_INTERFACE" -p tcp --dport 80 -j ACCEPT
    iptables -I INPUT -i "$HONEYPOT_INTERFACE" -p tcp --dport 443 -j ACCEPT

    # Log all connection attempts
    iptables -I INPUT -i "$HONEYPOT_INTERFACE" -j LOG --log-prefix "WIFI-HONEYPOT: " --log-level 4

    log_wifi "Firewall configured: No internet access for attackers"
}

################################################################################
# Fake HTTP Server (Returns Smiley Faces)
################################################################################

create_smiley_http_server() {
    log_wifi "Creating smiley face HTTP server..."

    cat > /tmp/honeypot-http-server.py <<'EOFPYTHON'
#!/usr/bin/env python3
"""
GhettoBoot WiFi Honeypot HTTP Server
Returns smiley faces and fake responses to all requests
"""

import http.server
import socketserver
import datetime
import os

PORT = 80
LOG_FILE = "/var/log/wifi-honeypot.log"

class HoneypotHTTPHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        """Log all HTTP requests"""
        with open(LOG_FILE, 'a') as f:
            f.write(f"[{datetime.datetime.now()}] HTTP {self.client_address[0]} {format % args}\n")

    def do_GET(self):
        """Handle all GET requests"""
        # Log the request
        self.log_message(f"GET {self.path}")

        # Check what they're requesting
        if "login" in self.path.lower() or "admin" in self.path.lower():
            self.send_fake_login()
        elif "api" in self.path.lower():
            self.send_fake_api()
        elif "config" in self.path.lower() or "setup" in self.path.lower():
            self.send_fake_config()
        else:
            self.send_smiley_response()

    def do_POST(self):
        """Handle all POST requests"""
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length)

        self.log_message(f"POST {self.path} DATA: {post_data}")
        self.send_smiley_response()

    def send_smiley_response(self):
        """Send smiley face response"""
        html = """
<!DOCTYPE html>
<html>
<head>
    <title>😊 Everything is Fine!</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            text-align: center;
            padding: 50px;
            background: linear-gradient(45deg, #FFD700, #FFA500);
        }
        h1 { font-size: 72px; }
        p { font-size: 24px; }
    </style>
</head>
<body>
    <h1>😊 😊 😊</h1>
    <h2>Welcome to SpectrumSetup!</h2>
    <p>Your connection is being processed...</p>
    <p>😊 Everything is working perfectly! 😊</p>
    <hr>
    <p style="font-size:16px;">Loading... Please wait...</p>
    <p style="font-size:100px;">😊</p>
</body>
</html>
"""
        self.send_response(200)
        self.send_header('Content-Type', 'text/html')
        self.end_headers()
        self.wfile.write(html.encode())

    def send_fake_login(self):
        """Send fake login page"""
        html = """
<!DOCTYPE html>
<html>
<head>
    <title>Router Login</title>
    <style>
        body { font-family: Arial; text-align: center; padding: 50px; }
        input { margin: 10px; padding: 10px; font-size: 16px; }
        button { padding: 10px 30px; font-size: 16px; background: #4CAF50; color: white; border: none; cursor: pointer; }
    </style>
</head>
<body>
    <h2>😊 Router Configuration</h2>
    <form action="/submit" method="post">
        <input type="text" name="username" placeholder="Username" required><br>
        <input type="password" name="password" placeholder="Password" required><br>
        <button type="submit">Login 😊</button>
    </form>
</body>
</html>
"""
        self.send_response(200)
        self.send_header('Content-Type', 'text/html')
        self.end_headers()
        self.wfile.write(html.encode())

    def send_fake_api(self):
        """Send fake API response"""
        json_response = """{
    "status": "success",
    "message": "😊 Everything is great!",
    "data": {
        "connection": "excellent",
        "signal": "strong",
        "happiness": "maximum 😊"
    }
}"""
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json_response.encode())

    def send_fake_config(self):
        """Send fake configuration page"""
        html = """
<!DOCTYPE html>
<html>
<head>
    <title>Router Setup</title>
</head>
<body>
    <h1>😊 Spectrum Router Setup</h1>
    <p>Your router is configured and working perfectly!</p>
    <h2>Network Status</h2>
    <ul>
        <li>Status: ✅ Connected</li>
        <li>Signal: ✅ Excellent</li>
        <li>Internet: ✅ Active</li>
        <li>Security: ✅ Protected</li>
        <li>Happiness: ✅ 😊 😊 😊</li>
    </ul>
</body>
</html>
"""
        self.send_response(200)
        self.send_header('Content-Type', 'text/html')
        self.end_headers()
        self.wfile.write(html.encode())

# Start server
with socketserver.TCPServer(("", PORT), HoneypotHTTPHandler) as httpd:
    print(f"😊 Honeypot HTTP server running on port {PORT}")
    httpd.serve_forever()
EOFPYTHON

    chmod +x /tmp/honeypot-http-server.py
    log_wifi "HTTP smiley server created"
}

start_http_server() {
    log_wifi "Starting HTTP server (smiley mode)..."

    # Kill any existing server
    pkill -f "honeypot-http-server.py" 2>/dev/null || true

    # Start new server in background
    python3 /tmp/honeypot-http-server.py > /dev/null 2>&1 &

    log_wifi "HTTP server started (PID: $!)"
}

################################################################################
# Main WiFi Honeypot Control
################################################################################

start_wifi_honeypot() {
    echo -e "${CYAN}"
    echo "═══════════════════════════════════════════════════════════"
    echo "        STARTING WIFI HONEYPOT"
    echo "═══════════════════════════════════════════════════════════"
    echo -e "${NC}"

    check_dependencies
    setup_interface
    create_hostapd_config
    create_dnsmasq_config
    setup_firewall_rules
    create_smiley_http_server
    start_http_server

    # Start dnsmasq
    log_wifi "Starting DHCP/DNS server..."
    pkill dnsmasq 2>/dev/null || true
    dnsmasq -C /tmp/dnsmasq-honeypot.conf

    # Start hostapd (fake AP)
    log_wifi "Starting fake WiFi AP..."
    pkill hostapd 2>/dev/null || true
    hostapd /tmp/hostapd-honeypot.conf > /var/log/hostapd-honeypot.log 2>&1 &

    sleep 3

    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}WiFi Honeypot Active!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Fake Network:${NC} $FAKE_SSID"
    echo -e "${YELLOW}Mode:${NC} Open (No password - looks like setup)"
    echo -e "${YELLOW}Honeypot IP:${NC} $HONEYPOT_IP"
    echo -e "${YELLOW}Attacker Experience:${NC} Connects but gets smiley faces 😊"
    echo ""
    echo -e "${CYAN}Monitor connections:${NC}"
    echo "  tail -f $CONNECTION_LOG"
    echo "  tail -f $WIFI_LOG"
    echo ""
    echo -e "${RED}Note:${NC} Attackers can connect but have NO internet access"
    echo -e "${RED}      All requests return smiley faces or fake data${NC}"
    echo ""
}

stop_wifi_honeypot() {
    log_wifi "Stopping WiFi honeypot..."

    # Kill services
    pkill hostapd 2>/dev/null || true
    pkill dnsmasq 2>/dev/null || true
    pkill -f "honeypot-http-server.py" 2>/dev/null || true

    # Restore interface
    ip addr flush dev "$HONEYPOT_INTERFACE" 2>/dev/null || true
    ip link set "$HONEYPOT_INTERFACE" down 2>/dev/null || true

    # Restore NetworkManager control
    if systemctl is-active --quiet NetworkManager; then
        nmcli device set "$HONEYPOT_INTERFACE" managed yes 2>/dev/null || true
    fi

    # Clean up firewall rules
    iptables -D FORWARD -i "$HONEYPOT_INTERFACE" -j DROP 2>/dev/null || true
    iptables -D INPUT -i "$HONEYPOT_INTERFACE" -j LOG --log-prefix "WIFI-HONEYPOT: " --log-level 4 2>/dev/null || true

    log_wifi "WiFi honeypot stopped"
}

show_connections() {
    echo -e "${CYAN}═══ WiFi Honeypot Connections ═══${NC}"
    echo ""

    if [[ -f "$CONNECTION_LOG" ]]; then
        tail -50 "$CONNECTION_LOG"
    else
        echo "No connections yet"
    fi

    echo ""
    echo -e "${CYAN}═══ Active DHCP Leases ═══${NC}"
    if [[ -f /var/lib/misc/dnsmasq.leases ]]; then
        cat /var/lib/misc/dnsmasq.leases
    else
        echo "No active leases"
    fi
}

show_status() {
    echo -e "${CYAN}═══ WiFi Honeypot Status ═══${NC}"
    echo ""

    if pgrep hostapd >/dev/null; then
        echo -e "${GREEN}✓${NC} Fake AP (hostapd) running"
    else
        echo -e "${RED}✗${NC} Fake AP not running"
    fi

    if pgrep dnsmasq >/dev/null; then
        echo -e "${GREEN}✓${NC} DHCP/DNS server running"
    else
        echo -e "${RED}✗${NC} DHCP/DNS not running"
    fi

    if pgrep -f "honeypot-http-server" >/dev/null; then
        echo -e "${GREEN}✓${NC} Smiley HTTP server running"
    else
        echo -e "${RED}✗${NC} HTTP server not running"
    fi

    echo ""
    echo -e "${YELLOW}Network:${NC} $FAKE_SSID"
    echo -e "${YELLOW}Interface:${NC} $HONEYPOT_INTERFACE"

    if ip addr show "$HONEYPOT_INTERFACE" 2>/dev/null | grep -q "$HONEYPOT_IP"; then
        echo -e "${GREEN}✓${NC} Interface configured: $HONEYPOT_IP"
    else
        echo -e "${RED}✗${NC} Interface not configured"
    fi

    echo ""
}

################################################################################
# Main
################################################################################

show_help() {
    cat <<EOF
WiFi Honeypot - Fake WiFi network that traps attackers

Usage: $0 [COMMAND]

Commands:
    start               Start WiFi honeypot
    stop                Stop WiFi honeypot
    restart             Restart WiFi honeypot
    status              Show honeypot status
    connections         Show connected devices
    logs                Tail honeypot logs

    help                Show this help message

Configuration:
    SSID: $FAKE_SSID
    Interface: $HONEYPOT_INTERFACE
    Network: $HONEYPOT_SUBNET

How it works:
    - Creates fake open WiFi network (looks like router setup)
    - Attackers can connect but get NO internet
    - All web requests return smiley faces 😊
    - All connections are logged
    - Completely isolated from real network

Examples:
    $0 start            # Start honeypot
    $0 connections      # See who connected
    $0 logs             # Watch activity

EOF
}

main() {
    local command="${1:-help}"

    if [[ $EUID -ne 0 && "$command" != "help" ]]; then
        echo -e "${RED}Must run as root${NC}"
        exit 1
    fi

    case "$command" in
        start)
            start_wifi_honeypot
            ;;
        stop)
            stop_wifi_honeypot
            ;;
        restart)
            stop_wifi_honeypot
            sleep 2
            start_wifi_honeypot
            ;;
        status)
            show_status
            ;;
        connections|clients)
            show_connections
            ;;
        logs)
            tail -f "$WIFI_LOG" "$CONNECTION_LOG"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
