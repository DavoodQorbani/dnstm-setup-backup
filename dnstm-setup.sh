#!/usr/bin/env bash
#
# dnstm-setup v1.0
# Interactive DNS Tunnel Setup
# Sets up Slipstream + DNSTT tunnels for censorship-resistant internet access
#
# Made By SamNet Technologies - Saman
# GitHub: github.com/SamNet-dev/dnstm-setup
# License: MIT

set -euo pipefail

VERSION="1.0"
TOTAL_STEPS=12

# ─── Colors & Formatting ───────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

CHECK="${GREEN}[✓]${NC}"
CROSS="${RED}[✗]${NC}"
WARN="${YELLOW}[!]${NC}"
INFO="${CYAN}[i]${NC}"

# ─── TUI Helper Functions ──────────────────────────────────────────────────────

print_header() {
    local title="$1"
    local width=60
    local line
    line=$(printf '─%.0s' $(seq 1 $width))
    echo ""
    echo -e "${BOLD}${CYAN}┌${line}┐${NC}"
    printf "${BOLD}${CYAN}│${NC} %-$((width - 1))s${BOLD}${CYAN}│${NC}\n" "$title"
    echo -e "${BOLD}${CYAN}└${line}┘${NC}"
    echo ""
}

print_step() {
    local step=$1
    local title="$2"
    echo ""
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${BOLD}[${step}/${TOTAL_STEPS}]${NC}  ${BOLD}${title}${NC}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_ok() {
    echo -e "  ${CHECK} $1"
}

print_fail() {
    echo -e "  ${CROSS} $1"
}

print_warn() {
    echo -e "  ${WARN} $1"
}

print_info() {
    echo -e "  ${INFO} $1"
}

print_box() {
    local lines=("$@")
    # Calculate width from longest line
    local width=58
    for l in "${lines[@]}"; do
        local len=${#l}
        if (( len + 2 > width )); then
            width=$((len + 2))
        fi
    done
    local line
    line=$(printf '─%.0s' $(seq 1 $width))
    echo -e "  ${DIM}┌${line}┐${NC}"
    for l in "${lines[@]}"; do
        printf "  ${DIM}│${NC} %-$((width - 1))s${DIM}│${NC}\n" "$l"
    done
    echo -e "  ${DIM}└${line}┘${NC}"
}

prompt_yn() {
    local question="$1"
    local default="${2:-n}"
    local yn_hint
    if [[ "$default" == "y" ]]; then
        yn_hint="[Y/n]"
    else
        yn_hint="[y/N]"
    fi
    while true; do
        echo ""
        echo -ne "  ${BOLD}${question}${NC} ${yn_hint} ${DIM}[h=help]${NC} "
        read -r answer
        answer=${answer:-$default}
        if [[ "$answer" =~ ^[Hh]$ ]]; then
            show_help_menu
            continue
        fi
        if [[ "$answer" =~ ^[Yy] ]]; then
            return 0
        else
            return 1
        fi
    done
}

prompt_input() {
    local question="$1"
    local default="${2:-}"
    local result
    while true; do
        if [[ -n "$default" ]]; then
            echo -ne "  ${BOLD}${question}${NC} [${default}] ${DIM}(h=help)${NC}: " >&2
        else
            echo -ne "  ${BOLD}${question}${NC} ${DIM}(h=help)${NC}: " >&2
        fi
        read -r result
        result=${result:-$default}
        if [[ "$result" =~ ^[Hh]$ ]]; then
            show_help_menu >&2
            continue
        fi
        echo "$result"
        return
    done
}

banner() {
    local w=54
    local border empty
    border=$(printf '═%.0s' $(seq 1 $w))
    empty=$(printf ' %.0s' $(seq 1 $w))
    local ver_text="dnstm-setup v${VERSION}"
    local sub_text="Interactive DNS Tunnel Setup"
    local vl=$(( (w - ${#ver_text}) / 2 ))
    local vr=$(( w - ${#ver_text} - vl ))
    local sl=$(( (w - ${#sub_text}) / 2 ))
    local sr=$(( w - ${#sub_text} - sl ))
    echo ""
    echo -e "${BOLD}${CYAN}"
    printf "  ╔%s╗\n" "$border"
    printf "  ║%s║\n" "$empty"
    printf "  ║%${vl}s%s%${vr}s║\n" "" "$ver_text" ""
    printf "  ║%${sl}s%s%${sr}s║\n" "" "$sub_text" ""
    printf "  ║%s║\n" "$empty"
    printf "  ╚%s╝\n" "$border"
    echo -e "${NC}"
}

# ─── Help System ──────────────────────────────────────────────────────────────

help_topic_header() {
    local title="$1"
    local width=58
    local line
    line=$(printf '─%.0s' $(seq 1 $width))
    # Compensate for multi-byte chars: pad width = visual width + (bytes - chars)
    local byte_len=${#title}
    local byte_count
    byte_count=$(printf '%s' "$title" | wc -c)
    local pad_width=$(( width - 1 + byte_count - byte_len ))
    echo ""
    echo -e "  ${BOLD}${CYAN}┌${line}┐${NC}"
    printf "  ${BOLD}${CYAN}│${NC} ${BOLD}%-${pad_width}s${BOLD}${CYAN}│${NC}\n" "$title"
    echo -e "  ${BOLD}${CYAN}└${line}┘${NC}"
    echo ""
}

help_press_enter() {
    echo ""
    echo -ne "  ${DIM}Press Enter to go back...${NC}"
    read -r
}

help_topic_domain() {
    help_topic_header "1. Domains & DNS Basics"
    echo -e "  ${BOLD}What is a domain?${NC}"
    echo "  A domain (e.g. example.com) is a human-readable address"
    echo "  on the internet. DNS tunneling uses domains to encode"
    echo "  data inside DNS queries, making your traffic look like"
    echo "  normal DNS resolution."
    echo ""
    echo -e "  ${BOLD}Why do you need one?${NC}"
    echo "  DNS tunnels work by making DNS queries for subdomains"
    echo "  of YOUR domain. The DNS system routes these queries to"
    echo "  your server, which decodes the hidden data. Without a"
    echo "  domain you own, you can't receive these queries."
    echo ""
    echo -e "  ${BOLD}How DNS delegation works${NC}"
    echo "  When you create NS records pointing t2.example.com to"
    echo "  ns.example.com (your server), you tell the global DNS"
    echo "  system: 'For any query about t2.example.com, ask my"
    echo "  server directly.' This is how tunnel traffic finds you."
    echo ""
    echo -e "  ${BOLD}Where to buy a domain${NC}"
    echo "  - Namecheap (namecheap.com) — cheap, privacy included"
    echo "  - Cloudflare Registrar — at-cost pricing"
    echo "  - Any registrar works, but you MUST use Cloudflare DNS"
    echo "    (free plan) to manage your records"
    echo ""
    echo -e "  ${BOLD}Subdomains used by this script${NC}"
    echo "  If your domain is example.com:"
    echo "    t2.example.com  ->  Slipstream + SOCKS tunnel"
    echo "    d2.example.com  ->  DNSTT + SOCKS tunnel"
    echo "    s2.example.com  ->  Slipstream + SSH tunnel"
    help_press_enter
}

help_topic_dns_records() {
    help_topic_header "2. DNS Records (Cloudflare Setup)"
    echo -e "  ${BOLD}What are DNS records?${NC}"
    echo "  DNS records are entries that tell the internet how to"
    echo "  find services for your domain."
    echo ""
    echo -e "  ${BOLD}A Record (Address Record)${NC}"
    echo "  Maps a name to an IP address."
    echo "  We create:  ns.yourdomain.com -> your server IP"
    echo "  This tells the internet where your DNS server lives."
    echo ""
    echo -e "  ${BOLD}NS Record (Name Server Record)${NC}"
    echo "  Delegates a subdomain to another DNS server."
    echo "  We create:  t2.yourdomain.com NS -> ns.yourdomain.com"
    echo "  This tells the internet: 'For queries about t2, ask"
    echo "  the server at ns.yourdomain.com (your VPS).'"
    echo ""
    echo -e "  ${BOLD}Why 'DNS Only' (grey cloud)?${NC}"
    echo "  Cloudflare's proxy (orange cloud) intercepts traffic."
    echo "  DNS tunneling requires queries to reach YOUR server"
    echo "  directly. If the proxy is ON, queries go to Cloudflare"
    echo "  instead and tunneling breaks completely."
    echo ""
    echo -e "  ${BOLD}Why 3 subdomains?${NC}"
    echo "  Each tunnel type needs its own subdomain so the DNS"
    echo "  Router can route them to the right tunnel:"
    echo "    t2 -> Slipstream + SOCKS  (fastest, QUIC-based)"
    echo "    d2 -> DNSTT + SOCKS       (classic, Noise protocol)"
    echo "    s2 -> Slipstream + SSH    (SSH over DNS)"
    echo ""
    echo -e "  ${BOLD}Common mistakes${NC}"
    echo "  - Using 'tns' instead of 'ns' for the A record name"
    echo "  - Leaving Cloudflare proxy ON (must be grey cloud)"
    echo "  - Setting NS values to the IP instead of ns.domain"
    echo "  - Forgetting to click Save after adding records"
    help_press_enter
}

help_topic_port53() {
    help_topic_header "3. Port 53 & systemd-resolved"
    echo -e "  ${BOLD}What is port 53?${NC}"
    echo "  Port 53 is the standard port for all DNS traffic."
    echo "  Every DNS query in the world is sent to port 53."
    echo "  Censors almost never block it because it would break"
    echo "  DNS for everyone."
    echo ""
    echo -e "  ${BOLD}Why do DNS tunnels need port 53?${NC}"
    echo "  When a DNS resolver (like 8.8.8.8) forwards a query"
    echo "  to your server, it always sends it to port 53. Your"
    echo "  tunnel server must listen on port 53 to receive these"
    echo "  queries. There is no way to use a different port."
    echo ""
    echo -e "  ${BOLD}What is systemd-resolved?${NC}"
    echo "  systemd-resolved is Ubuntu's built-in DNS cache. It"
    echo "  listens on 127.0.0.53:53 to handle local DNS lookups."
    echo "  Since it occupies port 53, it must be stopped before"
    echo "  the DNS tunnel server can bind to that port."
    echo ""
    echo -e "  ${BOLD}Is it safe to disable?${NC}"
    echo "  Yes! We replace it with 8.8.8.8 (Google DNS) in"
    echo "  /etc/resolv.conf. Your server still resolves domain"
    echo "  names normally — it just queries Google DNS directly"
    echo "  instead of using the local cache."
    help_press_enter
}

help_topic_dnstm() {
    help_topic_header "4. dnstm — DNS Tunnel Manager"
    echo -e "  ${BOLD}What is dnstm?${NC}"
    echo "  A command-line tool that installs, configures, and"
    echo "  manages DNS tunnel servers. Handles all the complex"
    echo "  setup automatically."
    echo ""
    echo -e "  ${BOLD}What is 'multi mode'?${NC}"
    echo "  Multi mode lets multiple tunnels share port 53 through"
    echo "  a DNS Router. The router reads incoming DNS queries and"
    echo "  routes them to the correct tunnel based on subdomain."
    echo ""
    echo -e "  ${BOLD}What gets installed${NC}"
    echo "  - slipstream-server   QUIC-based tunnel binary"
    echo "  - dnstt-server        Classic DNS tunnel binary"
    echo "  - microsocks          SOCKS5 proxy on port 19801"
    echo "  - systemd services    Auto-start tunnels on boot"
    echo "  - DNS Router          Multiplexes port 53"
    echo ""
    echo -e "  ${BOLD}How the DNS Router works${NC}"
    echo "  All DNS queries arrive at port 53. The router inspects"
    echo "  the domain name: if it's for t2.example.com, it sends"
    echo "  the query to Slipstream. If it's for d2.example.com,"
    echo "  it routes to DNSTT. Each tunnel decodes the data and"
    echo "  forwards it through microsocks to the internet."
    help_press_enter
}

help_topic_ssh() {
    help_topic_header "5. SSH Tunnel Users"
    echo -e "  ${BOLD}What is an SSH tunnel user?${NC}"
    echo "  A restricted account that can ONLY create SSH port-"
    echo "  forwarding tunnels. Cannot run commands, access a"
    echo "  shell, or browse the filesystem."
    echo ""
    echo -e "  ${BOLD}How is it different from a regular user?${NC}"
    echo "  A regular user (like root) has full server access."
    echo "  An SSH tunnel user can ONLY forward ports. Even if"
    echo "  the password is leaked, no one can access your server."
    echo ""
    echo -e "  ${BOLD}How Slipstream + SSH works${NC}"
    echo "  Client -> DNS query -> DNS resolver -> Your server"
    echo "   -> Slipstream (decodes DNS) -> SSH connection"
    echo "   -> SSH port forwarding (-D) -> Internet"
    echo ""
    echo -e "  ${BOLD}SSH vs SOCKS backend${NC}"
    echo "  SOCKS (t2/d2 tunnels):"
    echo "    - Faster, no authentication needed"
    echo "    - Anyone who knows the domain can connect"
    echo "  SSH (s2 tunnel):"
    echo "    - Requires username + password to connect"
    echo "    - Only authorized users can use it"
    echo "    - Slightly slower (SSH encryption overhead)"
    echo ""
    echo -e "  ${BOLD}Username & password${NC}"
    echo "  - The username/password are shared with ALL your users"
    echo "  - Keep the username simple (e.g. 'tunnel', 'vpn')"
    echo "  - Use a memorable password, NOT your root password"
    echo "  - Even if leaked, the account is port-forwarding only"
    help_press_enter
}

help_topic_architecture() {
    help_topic_header "6. Architecture & How It Works"
    echo -e "  ${BOLD}The Big Picture${NC}"
    echo "  DNS tunneling encodes your internet traffic inside DNS"
    echo "  queries. Since DNS is almost never blocked, it provides"
    echo "  a reliable channel even during internet shutdowns."
    echo ""
    echo -e "  ${BOLD}Data Flow${NC}"
    echo ""
    echo "    Phone (SlipNet app)"
    echo "      |"
    echo "      v"
    echo "    DNS Query (looks like normal DNS traffic)"
    echo "      |"
    echo "      v"
    echo "    Public DNS Resolver (8.8.8.8, 1.1.1.1, etc.)"
    echo "      |"
    echo "      v"
    echo "    Your Server, Port 53"
    echo "      |"
    echo "      v"
    echo "    DNS Router --+--> t2 --> Slipstream --+--> microsocks"
    echo "                 +--> d2 --> DNSTT -------+    (:19801)"
    echo "                 +--> s2 --> Slip+SSH ----+       |"
    echo "                                                  v"
    echo "                                              Internet"
    echo ""
    echo -e "  ${BOLD}Protocols${NC}"
    echo "  Slipstream: QUIC-based, TLS encryption, ~63 KB/s"
    echo "  DNSTT:      Noise protocol, Curve25519 keys, ~42 KB/s"
    echo ""
    echo -e "  ${BOLD}Why DNS?${NC}"
    echo "  DNS is the internet's phone book. EVERY device needs"
    echo "  it to work, so censors almost never block it. By hiding"
    echo "  traffic inside DNS queries, you can bypass blocks that"
    echo "  shut down VPNs, Tor, and other tools."
    help_press_enter
}

help_topic_about() {
    help_topic_header "About dnstm-setup"
    echo -e "  ${BOLD}Made By SamNet Technologies - Saman${NC}"
    echo ""
    echo -e "  ${BOLD}dnstm-setup${NC} v${VERSION}"
    echo "  Interactive DNS Tunnel Setup Wizard"
    echo ""
    echo "  Automates the complete setup of DNS tunnel servers"
    echo "  for censorship-resistant internet access. Designed"
    echo "  to help people in restricted regions stay connected."
    echo ""
    echo -e "  ${BOLD}Links${NC}"
    echo "  dnstm-setup   github.com/SamNet-dev/dnstm-setup"
    echo "  dnstm          github.com/net2share/dnstm"
    echo "  sshtun-user    github.com/net2share/sshtun-user"
    echo "  SlipNet        github.com/anonvector/SlipNet"
    echo ""
    echo -e "  ${BOLD}Manual Guide (Farsi)${NC}"
    echo "  telegra.ph/Complete-Guide-to-Setting-Up-a-DNS-Tunnel-03-04"
    echo ""
    echo -e "  ${BOLD}Donate${NC}"
    echo "  www.samnet.dev/donate"
    echo ""
    echo -e "  ${BOLD}License${NC}"
    echo "  MIT License"
    help_press_enter
}

show_help_menu() {
    while true; do
        help_topic_header "Help — Pick a Topic"
        echo -e "  ${BOLD}1${NC}  Domains & DNS Basics"
        echo -e "  ${BOLD}2${NC}  DNS Records (Cloudflare Setup)"
        echo -e "  ${BOLD}3${NC}  Port 53 & systemd-resolved"
        echo -e "  ${BOLD}4${NC}  dnstm — DNS Tunnel Manager"
        echo -e "  ${BOLD}5${NC}  SSH Tunnel Users"
        echo -e "  ${BOLD}6${NC}  Architecture & How It Works"
        echo ""
        echo -e "  ${DIM}────────────────────────────────────────${NC}"
        echo -e "  ${BOLD}7${NC}  About"
        echo ""
        echo -ne "  ${DIM}Pick a topic (1-7) or Enter to go back: ${NC}"
        read -r choice
        case "${choice:-}" in
            1) help_topic_domain ;;
            2) help_topic_dns_records ;;
            3) help_topic_port53 ;;
            4) help_topic_dnstm ;;
            5) help_topic_ssh ;;
            6) help_topic_architecture ;;
            7) help_topic_about ;;
            *) echo ""; return ;;
        esac
    done
}

# ─── --help ─────────────────────────────────────────────────────────────────────

show_help() {
    banner
    echo -e "${BOLD}DESCRIPTION${NC}"
    echo "  dnstm-setup automates the complete setup of DNS tunnel servers for"
    echo "  censorship-resistant internet access. It installs and configures dnstm"
    echo "  (DNS Tunnel Manager) with Slipstream and DNSTT protocols, sets up SOCKS"
    echo "  and SSH tunnels, and verifies everything works end-to-end."
    echo ""
    echo -e "${BOLD}PREREQUISITES${NC}"
    echo "  - A VPS running Ubuntu/Debian with root access"
    echo "  - A domain managed on Cloudflare"
    echo "  - curl installed on the server"
    echo ""
    echo -e "${BOLD}USAGE${NC}"
    echo "  sudo bash dnstm-setup.sh            Run interactive setup"
    echo "  sudo bash dnstm-setup.sh --uninstall Remove everything"
    echo "  bash dnstm-setup.sh --help           Show this help"
    echo "  bash dnstm-setup.sh --about          Show project info"
    echo ""
    echo -e "${BOLD}FLAGS${NC}"
    echo "  --help        Show this help message"
    echo "  --about       Show project information and credits"
    echo "  --uninstall   Remove all installed components"
    echo ""
    echo -e "${BOLD}WHAT THIS SCRIPT SETS UP${NC}"
    echo "  1. Slipstream + SOCKS tunnel  (fastest, ~63 KB/s)"
    echo "  2. DNSTT + SOCKS tunnel       (classic, ~42 KB/s)"
    echo "  3. Slipstream + SSH tunnel    (SSH over DNS)"
    echo "  4. microsocks SOCKS5 proxy    (auto-installed by dnstm)"
    echo "  5. SSH tunnel user (optional)"
    echo ""
    echo -e "${BOLD}CLIENT APP${NC}"
    echo "  SlipNet (Android): https://github.com/anonvector/SlipNet/releases"
    echo ""
}

# ─── --about ────────────────────────────────────────────────────────────────────

show_about() {
    banner
    echo -e "${BOLD}ABOUT${NC}"
    echo ""
    echo "  dnstm-setup is an interactive installer for DNS tunnel servers."
    echo "  It provides a guided, step-by-step setup process with colored"
    echo "  output, progress tracking, and automated verification."
    echo ""
    echo -e "${BOLD}HOW DNS TUNNELING WORKS${NC}"
    echo ""
    echo "  DNS tunneling encodes data inside DNS queries and responses."
    echo "  Since DNS is almost never blocked (even during internet shutdowns),"
    echo "  it provides a reliable channel for internet access. Your traffic"
    echo "  flows through public DNS resolvers to your tunnel server, which"
    echo "  decodes it and forwards it to the internet."
    echo ""
    echo "  Architecture:"
    echo ""
    echo "    Client (SlipNet)"
    echo "      --> DNS Query"
    echo "        --> Public Resolver (8.8.8.8)"
    echo "          --> Your Server (Port 53)"
    echo "            --> DNS Router"
    echo "              --> Tunnel --> Internet"
    echo ""
    echo -e "${BOLD}SUPPORTED PROTOCOLS${NC}"
    echo ""
    echo "  Slipstream  QUIC-based DNS tunnel with TLS encryption"
    echo "              Uses self-signed certificates (cert.pem/key.pem)"
    echo "              Speed: ~63 KB/s"
    echo ""
    echo "  DNSTT       Classic DNS tunnel using Noise protocol"
    echo "              Uses Curve25519 key pairs (server.key/server.pub)"
    echo "              Speed: ~42 KB/s"
    echo ""
    echo -e "${BOLD}RELATED PROJECTS${NC}"
    echo ""
    echo "  dnstm          https://github.com/net2share/dnstm"
    echo "  sshtun-user    https://github.com/net2share/sshtun-user"
    echo "  SlipNet        https://github.com/anonvector/SlipNet/releases"
    echo ""
    echo -e "${BOLD}LICENSE${NC}"
    echo ""
    echo "  MIT License"
    echo ""
    echo -e "${BOLD}AUTHOR${NC}"
    echo ""
    echo "  Made By SamNet Technologies - Saman"
    echo "  https://github.com/SamNet-dev"
    echo ""
}

# ─── --uninstall ────────────────────────────────────────────────────────────────

do_uninstall() {
    banner

    if [[ $EUID -ne 0 ]]; then
        echo -e "  ${CROSS} Not running as root. Please run with: sudo bash $0 --uninstall"
        exit 1
    fi

    print_header "Uninstall DNS Tunnel Setup"

    echo -e "  ${YELLOW}This will remove all DNS tunnel components from this server.${NC}"
    echo ""
    echo "  Components to remove:"
    echo "    - All dnstm tunnels and router"
    echo "    - dnstm binary and configuration"
    echo "    - sshtun-user binary (if installed)"
    echo "    - microsocks service"
    echo ""

    if ! prompt_yn "Are you sure you want to uninstall everything?" "n"; then
        echo ""
        print_info "Uninstall cancelled."
        exit 0
    fi

    echo ""

    # Stop and remove tunnels
    if command -v dnstm &>/dev/null; then
        print_info "Stopping tunnels..."
        local tags
        tags=$(dnstm tunnel list 2>/dev/null | grep -o 'tag=[^ ]*' | sed 's/tag=//' || true)
        for tag in $tags; do
            dnstm tunnel stop --tag "$tag" 2>/dev/null && print_ok "Stopped tunnel: $tag" || true
        done

        print_info "Stopping router..."
        dnstm router stop 2>/dev/null && print_ok "Router stopped" || true

        print_info "Removing tunnels..."
        for tag in $tags; do
            dnstm tunnel remove --tag "$tag" 2>/dev/null && print_ok "Removed tunnel: $tag" || true
        done

        print_info "Uninstalling dnstm..."
        dnstm uninstall 2>/dev/null && print_ok "dnstm uninstalled" || print_warn "dnstm uninstall returned an error (may already be removed)"
    else
        print_info "dnstm not found, skipping tunnel cleanup"
    fi

    # Remove binaries
    if [[ -f /usr/local/bin/dnstm ]]; then
        rm -f /usr/local/bin/dnstm
        print_ok "Removed /usr/local/bin/dnstm"
    fi

    if [[ -f /usr/local/bin/sshtun-user ]]; then
        rm -f /usr/local/bin/sshtun-user
        print_ok "Removed /usr/local/bin/sshtun-user"
    fi

    # Stop microsocks
    if systemctl is-active --quiet microsocks 2>/dev/null; then
        systemctl stop microsocks 2>/dev/null || true
        systemctl disable microsocks 2>/dev/null || true
        print_ok "Stopped and disabled microsocks"
    fi

    # Remove config directory
    if [[ -d /etc/dnstm ]]; then
        rm -rf /etc/dnstm
        print_ok "Removed /etc/dnstm"
    fi

    echo ""
    print_ok "${GREEN}Uninstall complete.${NC}"
    echo ""
    print_warn "Note: DNS records in Cloudflare were NOT removed. Remove them manually if needed."
    print_warn "Note: systemd-resolved was NOT re-enabled. Enable manually if needed:"
    echo "         systemctl enable systemd-resolved && systemctl start systemd-resolved"
    echo ""
}

# ─── Parse Arguments ────────────────────────────────────────────────────────────

case "${1:-}" in
    --help|-h)
        show_help
        exit 0
        ;;
    --about)
        show_about
        exit 0
        ;;
    --uninstall)
        do_uninstall
        exit 0
        ;;
    "")
        # No args, continue with setup
        ;;
    *)
        echo "Unknown option: $1"
        echo "Use --help for usage information."
        exit 1
        ;;
esac

# ─── Variables (populated during setup) ─────────────────────────────────────────

DOMAIN=""
SERVER_IP=""
DNSTT_PUBKEY=""
SSH_USER=""
SSH_PASS=""
SSH_SETUP_DONE=false

# ─── STEP 1: Pre-flight Checks ─────────────────────────────────────────────────

step_preflight() {
    print_step 1 "Pre-flight Checks"

    # Check root
    if [[ $EUID -eq 0 ]]; then
        print_ok "Running as root"
    else
        print_fail "Not running as root. Please run with: sudo bash $0"
        exit 1
    fi

    # Check OS
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        if [[ "$ID" == "ubuntu" || "$ID" == "debian" ]]; then
            print_ok "OS: ${PRETTY_NAME:-$ID}"
        else
            print_warn "OS: ${PRETTY_NAME:-$ID} (not Ubuntu/Debian - may work but untested)"
        fi
    else
        print_warn "Cannot detect OS (missing /etc/os-release)"
    fi

    # Check curl
    if command -v curl &>/dev/null; then
        print_ok "curl is installed"
    else
        print_fail "curl is not installed"
        echo ""
        if prompt_yn "Install curl now?" "y"; then
            if apt-get update -qq && apt-get install -y -qq curl; then
                print_ok "curl installed"
            else
                print_fail "Failed to install curl. Check your network/repos."
                exit 1
            fi
        else
            echo ""
            print_fail "curl is required. Please install it and re-run."
            exit 1
        fi
    fi

    # Detect server IP
    SERVER_IP=$(curl -4 -s --max-time 10 https://api.ipify.org 2>/dev/null || true)
    if [[ -n "$SERVER_IP" ]]; then
        print_ok "Server IP: ${SERVER_IP}"
    else
        print_warn "Could not auto-detect server IP"
        SERVER_IP=$(prompt_input "Enter your server's public IP")
        if [[ -z "$SERVER_IP" ]]; then
            print_fail "Server IP is required."
            exit 1
        fi
    fi

    echo ""
    print_ok "All pre-flight checks passed"
}

# ─── STEP 2: Ask Domain ────────────────────────────────────────────────────────

step_ask_domain() {
    print_step 2 "Domain Configuration"

    while true; do
        DOMAIN=$(prompt_input "Enter your domain (e.g. example.com)")
        # Strip whitespace, http(s)://, trailing slashes
        DOMAIN=$(echo "$DOMAIN" | sed 's|^[[:space:]]*||;s|[[:space:]]*$||;s|^https\?://||;s|/.*$||')
        if [[ -z "$DOMAIN" ]]; then
            print_fail "Domain cannot be empty. Please try again."
        elif [[ ! "$DOMAIN" =~ \. ]]; then
            print_fail "Invalid domain (must contain a dot). Please try again."
        else
            break
        fi
    done

    echo ""
    print_ok "Using domain: ${BOLD}${DOMAIN}${NC}"
}

# ─── STEP 3: Show DNS Records ──────────────────────────────────────────────────

step_dns_records() {
    print_step 3 "DNS Records (Cloudflare)"

    print_info "Create these DNS records in your Cloudflare dashboard:"
    echo ""
    print_box \
        "Record 1:  Type: A   | Name: ns | Value: ${SERVER_IP}" \
        "           Proxy: OFF (DNS Only - grey cloud)" \
        "" \
        "Record 2:  Type: NS  | Name: t2 | Value: ns.${DOMAIN}" \
        "Record 3:  Type: NS  | Name: d2 | Value: ns.${DOMAIN}" \
        "Record 4:  Type: NS  | Name: s2 | Value: ns.${DOMAIN}"

    echo ""
    print_warn "IMPORTANT: The A record MUST be DNS Only (grey cloud, NOT orange)"
    print_warn "IMPORTANT: The A record name must be \"ns\" (not \"tns\")"
    echo ""
    echo "  Subdomain purposes:"
    echo "    t2 = Slipstream + SOCKS tunnel"
    echo "    d2 = DNSTT + SOCKS tunnel"
    echo "    s2 = Slipstream + SSH tunnel"
    echo ""

    if ! prompt_yn "Have you created these DNS records in Cloudflare?" "n"; then
        echo ""
        print_info "Please create the DNS records and re-run this script."
        exit 0
    fi

    echo ""
    print_ok "DNS records confirmed"
}

# ─── STEP 4: Free Port 53 ──────────────────────────────────────────────────────

step_free_port53() {
    print_step 4 "Free Port 53"

    local port53_output
    port53_output=$(ss -ulnp 2>/dev/null | grep ':53 ' || true)

    if [[ -z "$port53_output" ]]; then
        print_ok "Port 53 is free"
        return
    fi

    # dnstm already on port 53 is fine (re-run scenario)
    if echo "$port53_output" | grep -q "dnstm"; then
        print_ok "Port 53 is in use by dnstm (already set up)"
        return
    fi

    print_info "Something is using port 53:"
    echo -e "  ${DIM}${port53_output}${NC}"
    echo ""

    if echo "$port53_output" | grep -q "systemd-resolve\|127\.0\.0\.53"; then
        print_warn "systemd-resolved is occupying port 53"
        echo ""
        if prompt_yn "Disable systemd-resolved to free port 53?" "y"; then
            systemctl stop systemd-resolved 2>/dev/null || true
            systemctl disable systemd-resolved 2>/dev/null || true
            echo "nameserver 8.8.8.8" > /etc/resolv.conf
            print_ok "systemd-resolved disabled"
            print_ok "Set DNS to 8.8.8.8"
        else
            print_fail "Port 53 must be free for DNS tunnels to work."
            exit 1
        fi
    else
        print_fail "An unknown service is using port 53."
        print_info "Please stop it manually and re-run this script."
        exit 1
    fi

    # Verify port is now free
    port53_output=$(ss -ulnp 2>/dev/null | grep ':53 ' || true)
    if [[ -z "$port53_output" ]]; then
        print_ok "Port 53 is now free"
    else
        print_fail "Port 53 is still in use. Please investigate manually."
        exit 1
    fi
}

# ─── STEP 5: Install dnstm ─────────────────────────────────────────────────────

step_install_dnstm() {
    print_step 5 "Install dnstm"

    # Check if already installed
    if command -v dnstm &>/dev/null; then
        local ver
        ver=$(dnstm --version 2>/dev/null || echo "unknown")
        print_info "dnstm is already installed (${ver})"
        echo ""
        if ! prompt_yn "Re-install / update dnstm?" "n"; then
            print_ok "Skipping dnstm installation"
            return
        fi
    fi

    # Download binary
    print_info "Downloading dnstm..."
    if curl -fsSL -o /usr/local/bin/dnstm https://github.com/net2share/dnstm/releases/latest/download/dnstm-linux-amd64; then
        chmod +x /usr/local/bin/dnstm
        print_ok "Downloaded dnstm binary"
    else
        print_fail "Failed to download dnstm"
        exit 1
    fi

    # Install in multi mode
    print_info "Running dnstm install --mode multi ..."
    echo ""
    if dnstm install --mode multi; then
        echo ""
        print_ok "dnstm installed successfully"
    else
        echo ""
        print_fail "dnstm install failed"
        exit 1
    fi

    # Verify
    local ver
    ver=$(dnstm --version 2>/dev/null || echo "unknown")
    print_ok "dnstm version: ${ver}"

    echo ""
    print_info "dnstm install sets up:"
    echo "    - Tunnel binaries (slipstream-server, dnstt-server, microsocks)"
    echo "    - System user (dnstm)"
    echo "    - Firewall rules (port 53)"
    echo "    - DNS Router service"
    echo "    - microsocks SOCKS5 proxy (port 19801)"
}

# ─── STEP 6: Verify Port 53 ────────────────────────────────────────────────────

step_verify_port53() {
    print_step 6 "Verify Port 53"

    local port53_output
    port53_output=$(ss -ulnp 2>/dev/null | grep ':53 ' || true)

    if echo "$port53_output" | grep -q "dnstm"; then
        print_ok "dnstm DNS Router is listening on port 53"
    else
        print_warn "DNS Router is not listening on port 53"
        print_info "Starting DNS Router..."
        if dnstm router start 2>/dev/null; then
            print_ok "DNS Router started"
        else
            print_fail "Failed to start DNS Router"
            exit 1
        fi

        # Re-check
        port53_output=$(ss -ulnp 2>/dev/null | grep ':53 ' || true)
        if echo "$port53_output" | grep -q "dnstm"; then
            print_ok "DNS Router confirmed on port 53"
        else
            print_fail "DNS Router still not on port 53. Check logs: dnstm router logs"
            exit 1
        fi
    fi

    # Firewall
    print_info "Ensuring firewall allows port 53..."

    if command -v ufw &>/dev/null; then
        ufw allow 53/tcp &>/dev/null || true
        ufw allow 53/udp &>/dev/null || true
        print_ok "ufw: port 53 TCP/UDP allowed"
    fi

    if command -v iptables &>/dev/null; then
        # Check if rules already exist before adding
        if ! iptables -C INPUT -p tcp --dport 53 -j ACCEPT &>/dev/null; then
            iptables -A INPUT -p tcp --dport 53 -j ACCEPT 2>/dev/null || true
        fi
        if ! iptables -C INPUT -p udp --dport 53 -j ACCEPT &>/dev/null; then
            iptables -A INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || true
        fi
        print_ok "iptables: port 53 TCP/UDP allowed"
    fi

    echo ""
    print_warn "If your hosting provider has an external firewall (web panel),"
    print_warn "make sure port 53 UDP and TCP are open there too."
}

# ─── STEP 7: Create Tunnels ────────────────────────────────────────────────────

step_create_tunnels() {
    print_step 7 "Create Tunnels"

    print_info "Creating 3 tunnels for domain: ${BOLD}${DOMAIN}${NC}"
    echo ""

    # Tunnel 1: Slipstream + SOCKS
    echo -e "  ${DIM}───────────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}Tunnel 1: Slipstream + SOCKS${NC}"
    echo ""
    if dnstm tunnel add --transport slipstream --backend socks --domain "t2.${DOMAIN}" --tag slip1 2>&1; then
        print_ok "Created: slip1 (Slipstream + SOCKS) on t2.${DOMAIN}"
    else
        print_warn "Tunnel slip1 may already exist or creation failed"
        print_info "If it already exists, this is OK"
    fi
    echo ""

    # Tunnel 2: DNSTT + SOCKS
    echo -e "  ${DIM}───────────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}Tunnel 2: DNSTT + SOCKS${NC}"
    echo ""
    local dnstt_output
    dnstt_output=$(dnstm tunnel add --transport dnstt --backend socks --domain "d2.${DOMAIN}" --tag dnstt1 2>&1) || true
    echo "$dnstt_output"

    # Try to extract DNSTT public key
    DNSTT_PUBKEY=""
    if [[ -f /etc/dnstm/tunnels/dnstt1/server.pub ]]; then
        DNSTT_PUBKEY=$(cat /etc/dnstm/tunnels/dnstt1/server.pub 2>/dev/null || true)
    fi

    if [[ -n "$DNSTT_PUBKEY" ]]; then
        print_ok "Created: dnstt1 (DNSTT + SOCKS) on d2.${DOMAIN}"
        echo ""
        echo -e "  ${BOLD}${YELLOW}DNSTT Public Key (save this!):${NC}"
        echo -e "  ${GREEN}${DNSTT_PUBKEY}${NC}"
    else
        print_warn "Tunnel dnstt1 may already exist or creation failed"
        print_info "If it already exists, this is OK"
    fi
    echo ""

    # Tunnel 3: Slipstream + SSH
    echo -e "  ${DIM}───────────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}Tunnel 3: Slipstream + SSH${NC}"
    echo ""
    if dnstm tunnel add --transport slipstream --backend ssh --domain "s2.${DOMAIN}" --tag slip-ssh 2>&1; then
        print_ok "Created: slip-ssh (Slipstream + SSH) on s2.${DOMAIN}"
    else
        print_warn "Tunnel slip-ssh may already exist or creation failed"
        print_info "If it already exists, this is OK"
    fi
    echo ""

    # Re-read DNSTT key if not captured
    if [[ -z "$DNSTT_PUBKEY" && -f /etc/dnstm/tunnels/dnstt1/server.pub ]]; then
        DNSTT_PUBKEY=$(cat /etc/dnstm/tunnels/dnstt1/server.pub 2>/dev/null || true)
        if [[ -n "$DNSTT_PUBKEY" ]]; then
            echo -e "  ${BOLD}${YELLOW}DNSTT Public Key:${NC}"
            echo -e "  ${GREEN}${DNSTT_PUBKEY}${NC}"
        fi
    fi

    print_ok "All tunnels created"
}

# ─── STEP 8: Start Services ────────────────────────────────────────────────────

step_start_services() {
    print_step 8 "Start Services"

    # Start router
    print_info "Starting DNS Router..."
    if dnstm router start 2>/dev/null; then
        print_ok "DNS Router started"
    else
        # May already be running
        if dnstm router status 2>/dev/null | grep -qi "running"; then
            print_ok "DNS Router already running"
        else
            print_warn "DNS Router may have issues. Check: dnstm router logs"
        fi
    fi

    echo ""

    # Start tunnels
    local tunnels=("slip1" "dnstt1" "slip-ssh")
    for tag in "${tunnels[@]}"; do
        print_info "Starting tunnel: ${tag}..."
        if dnstm tunnel start --tag "$tag" 2>/dev/null; then
            print_ok "Started: ${tag}"
        else
            if dnstm tunnel list 2>/dev/null | grep "$tag" | grep -qi "running"; then
                print_ok "Already running: ${tag}"
            else
                print_warn "Could not start: ${tag}. Check: dnstm tunnel logs --tag ${tag}"
            fi
        fi
    done

    echo ""
    print_info "Current tunnel status:"
    echo ""
    dnstm tunnel list 2>/dev/null || print_warn "Could not get tunnel list"
    echo ""
}

# ─── STEP 9: Verify microsocks ─────────────────────────────────────────────────

step_verify_microsocks() {
    print_step 9 "Verify SOCKS Proxy (microsocks)"

    # Check if microsocks is running
    if pgrep -x microsocks &>/dev/null || systemctl is-active --quiet microsocks 2>/dev/null; then
        print_ok "microsocks is running"
    else
        print_warn "microsocks is not running"
        print_info "Starting microsocks..."

        systemctl enable microsocks 2>/dev/null || true
        if systemctl start microsocks 2>/dev/null; then
            print_ok "microsocks started"
        else
            print_fail "Failed to start microsocks"
            print_info "Check: systemctl status microsocks"
        fi
    fi

    # Test SOCKS proxy
    echo ""
    print_info "Testing SOCKS proxy on 127.0.0.1:19801..."
    local test_ip
    test_ip=$(curl -s --max-time 10 --socks5 127.0.0.1:19801 https://api.ipify.org 2>/dev/null || true)

    if [[ -n "$test_ip" ]]; then
        print_ok "SOCKS proxy works! Response: ${test_ip}"
    else
        print_warn "SOCKS proxy test failed (this may be OK if internet is restricted)"
        print_info "The proxy may still work for DNS tunnel clients"
    fi
}

# ─── STEP 10: SSH User (Optional) ──────────────────────────────────────────────

step_ssh_user() {
    print_step 10 "SSH Tunnel User (Optional)"

    print_info "An SSH tunnel user allows clients to connect via Slipstream + SSH."
    print_info "This user can only create tunnels and has no shell access."
    echo ""

    if ! prompt_yn "Do you want to create an SSH tunnel user?" "y"; then
        print_info "Skipping SSH user setup"
        return
    fi

    echo ""

    # Install sshtun-user if not present
    if ! command -v sshtun-user &>/dev/null; then
        print_info "Downloading sshtun-user..."
        if curl -fsSL -o /usr/local/bin/sshtun-user https://github.com/net2share/sshtun-user/releases/latest/download/sshtun-user-linux-amd64; then
            chmod +x /usr/local/bin/sshtun-user
            print_ok "Downloaded sshtun-user"
        else
            print_fail "Failed to download sshtun-user"
            return
        fi
    else
        print_ok "sshtun-user already installed"
    fi

    # Configure SSH (only needed once)
    print_info "Applying SSH security configuration..."
    local configure_output
    configure_output=$(sshtun-user configure 2>&1) || true
    if echo "$configure_output" | grep -qi "already"; then
        print_ok "SSH already configured"
    elif echo "$configure_output" | grep -qi "error\|fail"; then
        print_warn "sshtun-user configure had issues:"
        echo -e "  ${DIM}${configure_output}${NC}"
    else
        print_ok "SSH configuration applied"
    fi

    echo ""

    # Get username
    SSH_USER=$(prompt_input "Enter username for SSH tunnel user" "tunnel")
    if [[ -z "$SSH_USER" ]]; then
        print_fail "Username cannot be empty"
        return
    fi

    # Get password
    SSH_PASS=$(prompt_input "Enter password for SSH tunnel user")
    if [[ -z "$SSH_PASS" ]]; then
        print_fail "Password cannot be empty"
        return
    fi

    echo ""

    # Create user
    print_info "Creating SSH tunnel user: ${SSH_USER}..."
    if sshtun-user create "$SSH_USER" --insecure-password "$SSH_PASS" 2>&1; then
        SSH_SETUP_DONE=true
        print_ok "SSH tunnel user created: ${SSH_USER}"
    else
        print_warn "User creation may have failed or user already exists"
        SSH_SETUP_DONE=true  # Still show in summary
    fi
}

# ─── STEP 11: Run Tests ────────────────────────────────────────────────────────

step_tests() {
    print_step 11 "Verification Tests"

    local pass=0
    local fail=0

    # Test 1: SOCKS proxy
    echo -e "  ${BOLD}Test 1: SOCKS Proxy${NC}"
    local socks_result
    socks_result=$(curl -s --max-time 10 --socks5 127.0.0.1:19801 https://api.ipify.org 2>/dev/null || true)
    if [[ -n "$socks_result" ]]; then
        print_ok "SOCKS proxy: PASS (IP: ${socks_result})"
        pass=$((pass + 1))
    else
        print_fail "SOCKS proxy: FAIL"
        fail=$((fail + 1))
    fi
    echo ""

    # Test 2: Tunnel list
    echo -e "  ${BOLD}Test 2: Tunnel Status${NC}"
    local tunnel_output
    tunnel_output=$(dnstm tunnel list 2>/dev/null || true)
    if [[ -n "$tunnel_output" ]]; then
        local running_count
        running_count=$(echo "$tunnel_output" | grep -ci "running" || true)
        if [[ "$running_count" -ge 3 ]]; then
            print_ok "All tunnels running: PASS (${running_count} running)"
            pass=$((pass + 1))
        elif [[ "$running_count" -ge 1 ]]; then
            print_warn "Some tunnels running: ${running_count}/3"
            pass=$((pass + 1))
        else
            print_fail "No tunnels running: FAIL"
            fail=$((fail + 1))
        fi
    else
        print_fail "Cannot get tunnel list: FAIL"
        fail=$((fail + 1))
    fi
    echo ""

    # Test 3: Router status
    echo -e "  ${BOLD}Test 3: DNS Router${NC}"
    if dnstm router status 2>/dev/null | grep -qi "running"; then
        print_ok "DNS Router: PASS (running)"
        pass=$((pass + 1))
    else
        print_fail "DNS Router: FAIL (not running)"
        fail=$((fail + 1))
    fi
    echo ""

    # Test 4: Port 53
    echo -e "  ${BOLD}Test 4: Port 53${NC}"
    if ss -ulnp 2>/dev/null | grep ':53 ' | grep -q "dnstm"; then
        print_ok "Port 53: PASS (dnstm listening)"
        pass=$((pass + 1))
    else
        print_fail "Port 53: FAIL (dnstm not listening)"
        fail=$((fail + 1))
    fi
    echo ""

    # Summary
    echo -e "  ${DIM}───────────────────────────────────────────────${NC}"
    if [[ $fail -eq 0 ]]; then
        print_ok "${GREEN}All ${pass} tests passed!${NC}"
    else
        print_warn "${pass} passed, ${fail} failed"
        print_info "Check logs with: dnstm router logs / dnstm tunnel logs --tag <tag>"
    fi
}

# ─── STEP 12: Summary ──────────────────────────────────────────────────────────

step_summary() {
    print_step 12 "Setup Complete!"

    local w=54
    local border empty
    border=$(printf '═%.0s' $(seq 1 $w))
    empty=$(printf ' %.0s' $(seq 1 $w))
    local msg="SETUP COMPLETE!"
    local ml=$(( (w - ${#msg}) / 2 ))
    local mr=$(( w - ${#msg} - ml ))

    echo -e "${BOLD}${GREEN}"
    printf "  ╔%s╗\n" "$border"
    printf "  ║%s║\n" "$empty"
    printf "  ║%${ml}s%s%${mr}s║\n" "" "$msg" ""
    printf "  ║%s║\n" "$empty"
    printf "  ╚%s╝\n" "$border"
    echo -e "${NC}"

    echo -e "  ${BOLD}Server Information${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    echo -e "  Server IP:     ${GREEN}${SERVER_IP}${NC}"
    echo -e "  Domain:        ${GREEN}${DOMAIN}${NC}"
    echo ""

    echo -e "  ${BOLD}Tunnel Endpoints${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    echo -e "  Slipstream + SOCKS:  ${GREEN}t2.${DOMAIN}${NC}"
    echo -e "  DNSTT + SOCKS:       ${GREEN}d2.${DOMAIN}${NC}"
    echo -e "  Slipstream + SSH:    ${GREEN}s2.${DOMAIN}${NC}"
    echo ""

    if [[ -n "$DNSTT_PUBKEY" ]]; then
        echo -e "  ${BOLD}DNSTT Public Key${NC}"
        echo -e "  ${DIM}────────────────────────────────────────${NC}"
        echo -e "  ${GREEN}${DNSTT_PUBKEY}${NC}"
        echo ""
    fi

    if [[ "$SSH_SETUP_DONE" == true ]]; then
        echo -e "  ${BOLD}SSH Tunnel User${NC}"
        echo -e "  ${DIM}────────────────────────────────────────${NC}"
        echo -e "  Username:  ${GREEN}${SSH_USER}${NC}"
        echo -e "  Password:  ${GREEN}${SSH_PASS}${NC}"
        echo -e "  Port:      ${GREEN}22${NC}"
        echo ""
    fi

    echo -e "  ${BOLD}DNS Resolvers (use in SlipNet)${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    echo "  8.8.8.8:53        (Google)"
    echo "  1.1.1.1:53        (Cloudflare)"
    echo "  9.9.9.9:53        (Quad9)"
    echo "  208.67.222.222:53 (OpenDNS)"
    echo "  94.140.14.14:53   (AdGuard)"
    echo "  185.228.168.9:53  (CleanBrowsing)"
    echo ""

    echo -e "  ${BOLD}Client App${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    echo "  SlipNet (Android): https://github.com/anonvector/SlipNet/releases"
    echo ""

    echo -e "  ${BOLD}Useful Commands${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    echo "  dnstm tunnel list               Show all tunnels"
    echo "  dnstm router status             Show router status"
    echo "  dnstm router logs               View router logs"
    echo "  dnstm tunnel logs --tag slip1   View tunnel logs"
    echo ""

    echo -e "  ${DIM}Setup by dnstm-setup v${VERSION} — SamNet Technologies${NC}"
    echo -e "  ${DIM}https://github.com/SamNet-dev/dnstm-setup${NC}"
    echo ""
}

# ─── Main ───────────────────────────────────────────────────────────────────────

main() {
    banner
    echo -e "  ${DIM}Tip: Press 'h' at any prompt for help${NC}"

    step_preflight
    step_ask_domain
    step_dns_records
    step_free_port53
    step_install_dnstm
    step_verify_port53
    step_create_tunnels
    step_start_services
    step_verify_microsocks
    step_ssh_user
    step_tests
    step_summary
}

main
