#!/usr/bin/env bash
#
# Dokploy Enhanced - Enterprise-Grade Installation Script
# https://github.com/amirhmoradi/dokploy-enhanced
#
# This script provides a robust, configurable installation for Dokploy Enhanced,
# using docker-compose for better visibility and easier maintenance.
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash
#   curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash -s -- install
#   curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash -s -- update
#   curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash -s -- stop
#   curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash -s -- start
#   curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash -s -- status
#   curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash -s -- uninstall
#
# Environment Variables:
#   DOKPLOY_VERSION      - Docker image tag (default: latest)
#   DOKPLOY_PORT         - Dokploy web interface port (default: 3000)
#   DOKPLOY_REGISTRY     - Docker registry (default: ghcr.io/amirhmoradi)
#   DOKPLOY_IMAGE        - Docker image name (default: dokploy-enhanced)
#   ADVERTISE_ADDR       - Docker Swarm advertise address
#   SKIP_DOCKER_INSTALL  - Skip Docker installation if set to "true"
#   SKIP_TRAEFIK         - Skip Traefik installation if set to "true"
#   POSTGRES_PASSWORD    - Custom PostgreSQL password
#   DRY_RUN              - Show commands without executing if set to "true"
#   FORCE                - Force installation even with warnings
#

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_NAME="dokploy-enhanced-installer"

# Default configuration
readonly DEFAULT_REGISTRY="ghcr.io/amirhmoradi"
readonly DEFAULT_IMAGE="dokploy-enhanced"
readonly DEFAULT_VERSION="latest"
readonly DEFAULT_PORT="3000"
readonly DEFAULT_DATA_DIR="/etc/dokploy"

# Docker image versions
readonly POSTGRES_VERSION="16"
readonly REDIS_VERSION="7"
readonly TRAEFIK_VERSION="v3.1.6"

# Network configuration
readonly NETWORK_NAME="dokploy-network"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# =============================================================================
# Utility Functions
# =============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        INFO)    printf "${BLUE}[INFO]${NC}  %s - %s\n" "$timestamp" "$message" ;;
        SUCCESS) printf "${GREEN}[OK]${NC}    %s - %s\n" "$timestamp" "$message" ;;
        WARN)    printf "${YELLOW}[WARN]${NC}  %s - %s\n" "$timestamp" "$message" >&2 ;;
        ERROR)   printf "${RED}[ERROR]${NC} %s - %s\n" "$timestamp" "$message" >&2 ;;
        DEBUG)   [[ "${DEBUG:-false}" == "true" ]] && printf "[DEBUG] %s - %s\n" "$timestamp" "$message" ;;
        *)       printf "%s - %s\n" "$timestamp" "$message" ;;
    esac
}

die() {
    log ERROR "$1"
    exit "${2:-1}"
}

confirm() {
    local prompt="$1"
    local default="${2:-n}"

    if [[ "${FORCE:-false}" == "true" ]]; then
        return 0
    fi

    local yn
    if [[ "$default" == "y" ]]; then
        read -rp "$prompt [Y/n] " yn
        yn=${yn:-y}
    else
        read -rp "$prompt [y/N] " yn
        yn=${yn:-n}
    fi

    [[ "${yn,,}" == "y" || "${yn,,}" == "yes" ]]
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

check_root() {
    if [[ "$(id -u)" != "0" ]]; then
        die "This script must be run as root. Please use 'sudo' or run as root user."
    fi
}

check_os() {
    if [[ "$(uname)" == "Darwin" ]]; then
        die "This script is designed for Linux systems. macOS is not supported for server deployment."
    fi

    if [[ -f "/.dockerenv" ]]; then
        die "This script cannot be run inside a Docker container. Please run on the host system."
    fi
}

generate_password() {
    local length="${1:-32}"
    tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w "$length" | head -n 1
}

# =============================================================================
# Environment Detection
# =============================================================================

get_public_ip() {
    local ip=""
    local services=(
        "https://ifconfig.io"
        "https://icanhazip.com"
        "https://ipecho.net/plain"
        "https://api.ipify.org"
    )

    for service in "${services[@]}"; do
        ip=$(curl -4s --connect-timeout 5 "$service" 2>/dev/null | tr -d '[:space:]')
        if [[ -n "$ip" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ip"
            return 0
        fi
    done

    return 1
}

get_private_ip() {
    ip addr show 2>/dev/null | \
        grep -E "inet (192\.168\.|10\.|172\.1[6-9]\.|172\.2[0-9]\.|172\.3[0-1]\.)" | \
        head -n1 | \
        awk '{print $2}' | \
        cut -d/ -f1
}

format_ip_for_url() {
    local ip="$1"
    if [[ "$ip" == *":"* ]]; then
        echo "[${ip}]"
    else
        echo "${ip}"
    fi
}

# =============================================================================
# Port Checking
# =============================================================================

check_port() {
    local port="$1"
    if ss -tulnp 2>/dev/null | grep -q ":${port} "; then
        return 1
    fi
    return 0
}

check_required_ports() {
    local errors=0
    local port="${DOKPLOY_PORT:-$DEFAULT_PORT}"

    log INFO "Checking required ports..."

    if ! check_port 80 "HTTP"; then
        log WARN "Port 80 is already in use. Traefik HTTP may not work."
        errors=$((errors + 1))
    fi

    if ! check_port 443 "HTTPS"; then
        log WARN "Port 443 is already in use. Traefik HTTPS may not work."
        errors=$((errors + 1))
    fi

    if ! check_port "$port" "Dokploy"; then
        log ERROR "Port $port is already in use. Required for Dokploy web interface."
        errors=$((errors + 1))
    fi

    if [[ $errors -gt 0 ]]; then
        log WARN "Some ports are in use. You can use 'ss -tulnp | grep :<port>' to identify services."
        if [[ "${FORCE:-false}" != "true" ]]; then
            if ! confirm "Continue anyway?"; then
                exit 1
            fi
        fi
    else
        log SUCCESS "All required ports are available."
    fi
}

# =============================================================================
# Docker Functions
# =============================================================================

install_docker() {
    if command_exists docker; then
        local docker_version
        docker_version=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')
        log INFO "Docker already installed (version: $docker_version)"
        return 0
    fi

    if [[ "${SKIP_DOCKER_INSTALL:-false}" == "true" ]]; then
        die "Docker is not installed and SKIP_DOCKER_INSTALL is set."
    fi

    log INFO "Installing Docker..."
    curl -sSL https://get.docker.com | sh
    log SUCCESS "Docker installed successfully."
}

install_docker_compose() {
    if command_exists docker-compose || docker compose version &>/dev/null; then
        log INFO "Docker Compose already available."
        return 0
    fi

    log INFO "Installing Docker Compose plugin..."
    apt-get update -qq && apt-get install -y -qq docker-compose-plugin 2>/dev/null || {
        # Fallback: install standalone docker-compose
        log INFO "Installing standalone Docker Compose..."
        curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
            -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    }
    log SUCCESS "Docker Compose installed successfully."
}

init_swarm() {
    local advertise_addr="${ADVERTISE_ADDR:-$(get_private_ip)}"

    if [[ -z "$advertise_addr" ]]; then
        log ERROR "Could not determine private IP address."
        log INFO "Please set the ADVERTISE_ADDR environment variable."
        exit 1
    fi

    log INFO "Using advertise address: $advertise_addr"

    # Check if already in swarm
    if docker info 2>/dev/null | grep -q "Swarm: active"; then
        log INFO "Docker Swarm already initialized."
        echo "$advertise_addr"
        return 0
    fi

    # Leave existing swarm if any
    docker swarm leave --force 2>/dev/null || true

    log INFO "Initializing Docker Swarm..."
    if ! docker swarm init --advertise-addr "$advertise_addr"; then
        die "Failed to initialize Docker Swarm."
    fi

    log SUCCESS "Docker Swarm initialized successfully."
    echo "$advertise_addr"
}

create_network() {
    log INFO "Creating Docker overlay network..."

    if docker network ls | grep -q "$NETWORK_NAME"; then
        log INFO "Network '$NETWORK_NAME' already exists."
        return 0
    fi

    docker network create --driver overlay --attachable "$NETWORK_NAME"
    log SUCCESS "Network '$NETWORK_NAME' created successfully."
}

# =============================================================================
# Docker Compose File Generation
# =============================================================================

generate_env_file() {
    local data_dir="$1"
    local advertise_addr="$2"
    local pg_password="$3"
    local env_file="$data_dir/.env"

    log INFO "Generating .env file..."

    cat > "$env_file" << EOF
# =============================================================================
# Dokploy Enhanced Configuration
# Generated on $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# =============================================================================

# Docker Registry
DOKPLOY_REGISTRY=${DOKPLOY_REGISTRY:-$DEFAULT_REGISTRY}
DOKPLOY_IMAGE=${DOKPLOY_IMAGE:-$DEFAULT_IMAGE}
DOKPLOY_VERSION=${DOKPLOY_VERSION:-$DEFAULT_VERSION}

# Network
ADVERTISE_ADDR=${advertise_addr}
DOKPLOY_PORT=${DOKPLOY_PORT:-$DEFAULT_PORT}
NETWORK_NAME=${NETWORK_NAME}

# Data Directory
DATA_DIR=${data_dir}

# PostgreSQL
POSTGRES_VERSION=${POSTGRES_VERSION}
POSTGRES_USER=dokploy
POSTGRES_DB=dokploy
POSTGRES_PASSWORD=${pg_password}

# Redis
REDIS_VERSION=${REDIS_VERSION}

# Traefik
TRAEFIK_VERSION=${TRAEFIK_VERSION}
SKIP_TRAEFIK=${SKIP_TRAEFIK:-false}
EOF

    chmod 600 "$env_file"
    log SUCCESS ".env file created at $env_file"
}

generate_docker_compose() {
    local data_dir="$1"
    local compose_file="$data_dir/docker-compose.yml"

    log INFO "Generating docker-compose.yml..."

    cat > "$compose_file" << 'EOF'
# =============================================================================
# Dokploy Enhanced - Docker Compose Configuration
# =============================================================================
#
# This file is auto-generated. Edit .env to change configuration.
# Re-run install.sh to regenerate this file if needed.
#

services:
  # ===========================================================================
  # Dokploy - Main Application
  # ===========================================================================
  dokploy:
    image: ${DOKPLOY_REGISTRY}/${DOKPLOY_IMAGE}:${DOKPLOY_VERSION}
    container_name: dokploy
    restart: unless-stopped
    networks:
      - dokploy-network
    ports:
      - "${DOKPLOY_PORT}:3000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ${DATA_DIR}:/etc/dokploy
      - dokploy-docker:/root/.docker
    environment:
      - ADVERTISE_ADDR=${ADVERTISE_ADDR}
    depends_on:
      - postgres
      - redis
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager

  # ===========================================================================
  # PostgreSQL - Database
  # ===========================================================================
  postgres:
    image: postgres:${POSTGRES_VERSION}
    container_name: dokploy-postgres
    restart: unless-stopped
    networks:
      - dokploy-network
    volumes:
      - dokploy-postgres:/var/lib/postgresql/data
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5

  # ===========================================================================
  # Redis - Cache & Queue
  # ===========================================================================
  redis:
    image: redis:${REDIS_VERSION}
    container_name: dokploy-redis
    restart: unless-stopped
    networks:
      - dokploy-network
    volumes:
      - dokploy-redis:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  # ===========================================================================
  # Traefik - Reverse Proxy (Optional)
  # ===========================================================================
  traefik:
    image: traefik:${TRAEFIK_VERSION}
    container_name: dokploy-traefik
    restart: unless-stopped
    profiles:
      - traefik
    networks:
      - dokploy-network
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ${DATA_DIR}/traefik/traefik.yml:/etc/traefik/traefik.yml:ro
      - ${DATA_DIR}/traefik/dynamic:/etc/traefik/dynamic:ro
      - ${DATA_DIR}/traefik/acme:/etc/traefik/acme

# =============================================================================
# Networks
# =============================================================================
networks:
  dokploy-network:
    external: true
    name: ${NETWORK_NAME}

# =============================================================================
# Volumes
# =============================================================================
volumes:
  dokploy-docker:
    name: dokploy-docker
  dokploy-postgres:
    name: dokploy-postgres
  dokploy-redis:
    name: dokploy-redis
EOF

    log SUCCESS "docker-compose.yml created at $compose_file"
}

generate_traefik_config() {
    local data_dir="$1"

    log INFO "Setting up Traefik configuration..."

    mkdir -p "$data_dir/traefik/dynamic"
    mkdir -p "$data_dir/traefik/acme"

    if [[ ! -f "$data_dir/traefik/traefik.yml" ]]; then
        cat > "$data_dir/traefik/traefik.yml" << 'EOF'
# =============================================================================
# Traefik Configuration for Dokploy Enhanced
# =============================================================================

api:
  insecure: true
  dashboard: true

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
          permanent: true
  websecure:
    address: ":443"
    http3: {}

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: dokploy-network
  file:
    directory: "/etc/traefik/dynamic"
    watch: true

certificatesResolvers:
  letsencrypt:
    acme:
      email: admin@example.com
      storage: /etc/traefik/acme/acme.json
      httpChallenge:
        entryPoint: web

log:
  level: "ERROR"

accessLog: {}
EOF
        log SUCCESS "Traefik configuration created."
    else
        log INFO "Traefik configuration already exists."
    fi
}

# =============================================================================
# Docker Compose Wrapper
# =============================================================================

compose_cmd() {
    local data_dir="${DOKPLOY_DATA_DIR:-$DEFAULT_DATA_DIR}"

    if docker compose version &>/dev/null; then
        docker compose -f "$data_dir/docker-compose.yml" --env-file "$data_dir/.env" "$@"
    else
        docker-compose -f "$data_dir/docker-compose.yml" --env-file "$data_dir/.env" "$@"
    fi
}

# =============================================================================
# Main Commands
# =============================================================================

cmd_install() {
    log INFO "Starting Dokploy Enhanced installation..."
    log INFO "Script version: $SCRIPT_VERSION"

    # Pre-flight checks
    check_root
    check_os
    check_required_ports

    # Install Docker and Docker Compose
    install_docker
    install_docker_compose

    # Initialize Swarm
    local advertise_addr
    advertise_addr=$(init_swarm)

    # Create network
    create_network

    # Create data directory
    local data_dir="${DOKPLOY_DATA_DIR:-$DEFAULT_DATA_DIR}"
    mkdir -p "$data_dir"
    chmod 755 "$data_dir"
    log SUCCESS "Data directory created: $data_dir"

    # Generate PostgreSQL password
    local pg_password="${POSTGRES_PASSWORD:-$(generate_password)}"

    # Generate configuration files
    generate_env_file "$data_dir" "$advertise_addr" "$pg_password"
    generate_docker_compose "$data_dir"
    generate_traefik_config "$data_dir"

    # Start services
    log INFO "Starting services with docker-compose..."

    if [[ "${SKIP_TRAEFIK:-false}" == "true" ]]; then
        compose_cmd up -d
    else
        compose_cmd --profile traefik up -d
    fi

    # Wait for services to start
    log INFO "Waiting for services to initialize..."
    sleep 5

    # Get access URL
    local public_ip
    public_ip="${ADVERTISE_ADDR:-$(get_public_ip)}" || public_ip="$advertise_addr"
    local formatted_addr
    formatted_addr=$(format_ip_for_url "$public_ip")
    local port="${DOKPLOY_PORT:-$DEFAULT_PORT}"

    # Save installation info
    cat > "$data_dir/install-info.json" << EOF
{
    "installed_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "script_version": "$SCRIPT_VERSION",
    "docker_version": "$(docker --version 2>/dev/null)",
    "advertise_addr": "$advertise_addr",
    "port": "$port",
    "registry": "${DOKPLOY_REGISTRY:-$DEFAULT_REGISTRY}",
    "image": "${DOKPLOY_IMAGE:-$DEFAULT_IMAGE}",
    "version": "${DOKPLOY_VERSION:-$DEFAULT_VERSION}"
}
EOF

    # Success message
    echo ""
    printf "${GREEN}============================================${NC}\n"
    printf "${GREEN}  Dokploy Enhanced Installation Complete!   ${NC}\n"
    printf "${GREEN}============================================${NC}\n"
    echo ""
    printf "${CYAN}Access your Dokploy instance at:${NC}\n"
    printf "${YELLOW}  http://${formatted_addr}:${port}${NC}\n"
    echo ""
    printf "${BLUE}Please wait 15-30 seconds for all services to fully start.${NC}\n"
    echo ""
    printf "${CYAN}Configuration files:${NC}\n"
    printf "  .env file:           ${YELLOW}${data_dir}/.env${NC}\n"
    printf "  docker-compose.yml:  ${YELLOW}${data_dir}/docker-compose.yml${NC}\n"
    printf "  Traefik config:      ${YELLOW}${data_dir}/traefik/traefik.yml${NC}\n"
    echo ""
    printf "${CYAN}PostgreSQL password:${NC} ${pg_password}\n"
    echo ""
    printf "${CYAN}Useful commands:${NC}\n"
    printf "  View status:    ${YELLOW}$0 status${NC}\n"
    printf "  View logs:      ${YELLOW}$0 logs${NC}\n"
    printf "  Stop services:  ${YELLOW}$0 stop${NC}\n"
    printf "  Start services: ${YELLOW}$0 start${NC}\n"
    printf "  Update:         ${YELLOW}$0 update${NC}\n"
    echo ""

    log SUCCESS "Installation completed successfully!"
}

cmd_update() {
    log INFO "Updating Dokploy Enhanced..."
    check_root

    local data_dir="${DOKPLOY_DATA_DIR:-$DEFAULT_DATA_DIR}"

    if [[ ! -f "$data_dir/docker-compose.yml" ]]; then
        die "docker-compose.yml not found. Please run install first."
    fi

    log INFO "Pulling latest images..."
    compose_cmd pull

    log INFO "Recreating containers with new images..."
    if [[ "${SKIP_TRAEFIK:-false}" == "true" ]]; then
        compose_cmd up -d
    else
        compose_cmd --profile traefik up -d
    fi

    log SUCCESS "Dokploy Enhanced updated successfully!"
}

cmd_stop() {
    log INFO "Stopping Dokploy Enhanced services..."
    check_root

    compose_cmd stop

    log SUCCESS "Services stopped."
}

cmd_start() {
    log INFO "Starting Dokploy Enhanced services..."
    check_root

    if [[ "${SKIP_TRAEFIK:-false}" == "true" ]]; then
        compose_cmd up -d
    else
        compose_cmd --profile traefik up -d
    fi

    log SUCCESS "Services started."
}

cmd_restart() {
    log INFO "Restarting Dokploy Enhanced services..."
    check_root

    compose_cmd restart

    log SUCCESS "Services restarted."
}

cmd_status() {
    local data_dir="${DOKPLOY_DATA_DIR:-$DEFAULT_DATA_DIR}"

    echo ""
    printf "${CYAN}=== Dokploy Enhanced Status ===${NC}\n"
    echo ""

    printf "${BOLD}Services:${NC}\n"
    compose_cmd ps
    echo ""

    printf "${BOLD}Docker Swarm:${NC}\n"
    docker info 2>/dev/null | grep -E "Swarm:|Node Address:|Manager Addresses:" || echo "Not in swarm mode"
    echo ""

    printf "${BOLD}Networks:${NC}\n"
    docker network ls --filter "name=$NETWORK_NAME" 2>/dev/null
    echo ""

    printf "${BOLD}Volumes:${NC}\n"
    docker volume ls --filter "name=dokploy" 2>/dev/null
    echo ""

    if [[ -f "$data_dir/.env" ]]; then
        printf "${BOLD}Configuration (.env):${NC}\n"
        grep -v "PASSWORD" "$data_dir/.env" | grep -v "^#" | grep -v "^$" | head -20
        echo ""
    fi

    if [[ -f "$data_dir/install-info.json" ]]; then
        printf "${BOLD}Installation Info:${NC}\n"
        cat "$data_dir/install-info.json"
        echo ""
    fi
}

cmd_logs() {
    local service="${1:-}"
    local follow="${2:-}"

    if [[ -n "$service" && "$service" != "-f" ]]; then
        if [[ "$follow" == "-f" ]]; then
            compose_cmd logs -f "$service"
        else
            compose_cmd logs --tail 100 "$service"
        fi
    else
        if [[ "$service" == "-f" || "$follow" == "-f" ]]; then
            compose_cmd logs -f
        else
            compose_cmd logs --tail 100
        fi
    fi
}

cmd_uninstall() {
    log WARN "This will remove Dokploy Enhanced and all its data!"

    if ! confirm "Are you sure you want to continue?"; then
        log INFO "Uninstall cancelled."
        exit 0
    fi

    check_root

    local data_dir="${DOKPLOY_DATA_DIR:-$DEFAULT_DATA_DIR}"

    log INFO "Stopping and removing containers..."
    compose_cmd --profile traefik down 2>/dev/null || true

    if confirm "Remove Docker volumes (this will delete all data)?"; then
        log INFO "Removing Docker volumes..."
        compose_cmd --profile traefik down -v 2>/dev/null || true
        docker volume rm dokploy-docker dokploy-postgres dokploy-redis 2>/dev/null || true
    fi

    # Remove network
    docker network rm "$NETWORK_NAME" 2>/dev/null || true

    # Leave swarm
    if confirm "Leave Docker Swarm?"; then
        docker swarm leave --force 2>/dev/null || true
    fi

    if confirm "Remove data directory ($data_dir)?"; then
        rm -rf "$data_dir"
        log INFO "Data directory removed."
    fi

    log SUCCESS "Dokploy Enhanced has been uninstalled."
}

cmd_backup() {
    check_root

    local data_dir="${DOKPLOY_DATA_DIR:-$DEFAULT_DATA_DIR}"
    local backup_dir="${BACKUP_DIR:-/var/backups/dokploy}"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$backup_dir/dokploy_backup_$timestamp"

    log INFO "Creating backup at: $backup_path"

    mkdir -p "$backup_path"

    # Backup configuration files
    log INFO "Backing up configuration..."
    cp -r "$data_dir" "$backup_path/config"

    # Backup PostgreSQL
    log INFO "Backing up PostgreSQL data..."
    docker run --rm \
        -v dokploy-postgres:/data \
        -v "$backup_path":/backup \
        alpine tar czf /backup/postgres.tar.gz -C /data . 2>/dev/null || \
        log WARN "PostgreSQL backup failed or volume doesn't exist."

    # Backup Redis
    log INFO "Backing up Redis data..."
    docker run --rm \
        -v dokploy-redis:/data \
        -v "$backup_path":/backup \
        alpine tar czf /backup/redis.tar.gz -C /data . 2>/dev/null || \
        log WARN "Redis backup failed or volume doesn't exist."

    # Create backup info
    cat > "$backup_path/backup-info.json" << EOF
{
    "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "hostname": "$(hostname)",
    "script_version": "$SCRIPT_VERSION"
}
EOF

    log SUCCESS "Backup completed: $backup_path"
}

cmd_help() {
    cat << EOF
${BOLD}Dokploy Enhanced Installer v${SCRIPT_VERSION}${NC}

${CYAN}Usage:${NC}
    $0 [command] [options]

${CYAN}Commands:${NC}
    install     Install Dokploy Enhanced (default if no command given)
    update      Pull latest images and recreate containers
    start       Start all services
    stop        Stop all services
    restart     Restart all services
    status      Show current status of all services
    logs        Show service logs (use -f to follow)
    backup      Create a backup of all data
    uninstall   Remove Dokploy Enhanced and optionally all data
    help        Show this help message

${CYAN}Environment Variables:${NC}
    DOKPLOY_VERSION          Docker image tag (default: latest)
    DOKPLOY_PORT             Web interface port (default: 3000)
    DOKPLOY_REGISTRY         Docker registry (default: ghcr.io/amirhmoradi)
    DOKPLOY_IMAGE            Docker image name (default: dokploy-enhanced)
    DOKPLOY_DATA_DIR         Data directory (default: /etc/dokploy)
    ADVERTISE_ADDR           Docker Swarm advertise address
    SKIP_DOCKER_INSTALL      Skip Docker installation (true/false)
    SKIP_TRAEFIK             Skip Traefik installation (true/false)
    POSTGRES_PASSWORD        Custom PostgreSQL password
    DRY_RUN                  Show commands without executing (true/false)
    FORCE                    Force installation even with warnings (true/false)
    DEBUG                    Enable debug output (true/false)

${CYAN}Configuration Files:${NC}
    After installation, configuration is stored in:
    - ${DEFAULT_DATA_DIR}/.env              - Environment variables
    - ${DEFAULT_DATA_DIR}/docker-compose.yml - Docker Compose configuration
    - ${DEFAULT_DATA_DIR}/traefik/          - Traefik configuration

${CYAN}Examples:${NC}
    # Basic installation
    curl -sSL <url> | bash

    # Install specific version
    DOKPLOY_VERSION=20241216 curl -sSL <url> | bash

    # Install with custom port
    DOKPLOY_PORT=8080 curl -sSL <url> | bash

    # Update to latest
    $0 update

    # View logs
    $0 logs -f

    # Show status
    $0 status

${CYAN}More Information:${NC}
    GitHub: https://github.com/amirhmoradi/dokploy-enhanced
    Docs:   https://github.com/amirhmoradi/dokploy-enhanced#readme

EOF
}

# =============================================================================
# Main Entry Point
# =============================================================================

main() {
    local command="${1:-install}"

    case "$command" in
        install)
            cmd_install
            ;;
        update)
            cmd_update
            ;;
        start)
            cmd_start
            ;;
        stop)
            cmd_stop
            ;;
        restart)
            cmd_restart
            ;;
        status)
            cmd_status
            ;;
        logs)
            shift
            cmd_logs "$@"
            ;;
        backup)
            cmd_backup
            ;;
        uninstall|remove)
            cmd_uninstall
            ;;
        help|--help|-h)
            cmd_help
            ;;
        version|--version|-v)
            echo "Dokploy Enhanced Installer v$SCRIPT_VERSION"
            ;;
        *)
            log ERROR "Unknown command: $command"
            cmd_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
