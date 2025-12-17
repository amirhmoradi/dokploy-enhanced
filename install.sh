#!/usr/bin/env bash
#
# Dokploy Enhanced - Enterprise-Grade Installation Script
# https://github.com/amirhmoradi/dokploy-enhanced
#
# This script provides a robust, configurable installation for Dokploy Enhanced,
# an enhanced version of Dokploy with additional features and custom PR merges.
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash
#   curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash -s -- install
#   curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash -s -- update
#   curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash -s -- uninstall
#   curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash -s -- status
#   curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash -s -- backup
#
# Environment Variables:
#   DOKPLOY_VERSION      - Docker image tag (default: latest)
#   DOKPLOY_PORT         - Dokploy web interface port (default: 3000)
#   DOKPLOY_REGISTRY     - Docker registry (default: ghcr.io/amirhmoradi)
#   DOKPLOY_IMAGE        - Docker image name (default: dokploy-enhanced)
#   ADVERTISE_ADDR       - Docker Swarm advertise address
#   DOCKER_SWARM_INIT_ARGS - Additional Docker Swarm init arguments
#   SKIP_DOCKER_INSTALL  - Skip Docker installation if set to "true"
#   SKIP_TRAEFIK         - Skip Traefik installation if set to "true"
#   POSTGRES_PASSWORD    - Custom PostgreSQL password
#   DRY_RUN              - Show commands without executing if set to "true"
#   FORCE                - Force installation even with warnings
#   BACKUP_DIR           - Directory for backups (default: /var/backups/dokploy)
#

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="dokploy-enhanced-installer"

# Default configuration
readonly DEFAULT_REGISTRY="ghcr.io/amirhmoradi"
readonly DEFAULT_IMAGE="dokploy-enhanced"
readonly DEFAULT_VERSION="latest"
readonly DEFAULT_PORT="3000"
readonly DEFAULT_BACKUP_DIR="/var/backups/dokploy"
readonly DEFAULT_DATA_DIR="/etc/dokploy"

# Docker versions
readonly DOCKER_VERSION="28.5.0"
readonly POSTGRES_VERSION="16"
readonly REDIS_VERSION="7"
readonly TRAEFIK_VERSION="v3.6.1"

# Network configuration
readonly NETWORK_NAME="dokploy-network"

# Service names
readonly SERVICE_DOKPLOY="dokploy"
readonly SERVICE_POSTGRES="dokploy-postgres"
readonly SERVICE_REDIS="dokploy-redis"
readonly CONTAINER_TRAEFIK="dokploy-traefik"

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

run_cmd() {
    local cmd="$*"
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log INFO "[DRY RUN] $cmd"
        return 0
    fi
    if [[ "${DEBUG:-false}" == "true" ]]; then
        log DEBUG "Executing command: $cmd"
    fi
    eval "$cmd"
    local exit_code=$?
    if [[ "${DEBUG:-false}" == "true" ]]; then
        log DEBUG "Command exit code: $exit_code"
    fi
    return $exit_code
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

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while ps -p "$pid" > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "      \b\b\b\b\b\b"
}

# =============================================================================
# Environment Detection
# =============================================================================

is_proxmox_lxc() {
    # Check for LXC in environment
    if [[ -n "${container:-}" && "$container" == "lxc" ]]; then
        return 0
    fi

    # Check for LXC in /proc/1/environ
    if grep -q "container=lxc" /proc/1/environ 2>/dev/null; then
        return 0
    fi

    return 1
}

is_wsl() {
    grep -qEi "(microsoft|wsl)" /proc/version 2>/dev/null
}

get_distro() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        echo "${ID:-unknown}"
    else
        echo "unknown"
    fi
}

get_public_ip() {
    local ip=""
    local services=(
        "https://ifconfig.io"
        "https://icanhazip.com"
        "https://ipecho.net/plain"
        "https://api.ipify.org"
    )

    # Try IPv4 first
    for service in "${services[@]}"; do
        ip=$(curl -4s --connect-timeout 5 "$service" 2>/dev/null | tr -d '[:space:]')
        if [[ -n "$ip" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ip"
            return 0
        fi
    done

    # Fall back to IPv6
    for service in "${services[@]}"; do
        ip=$(curl -6s --connect-timeout 5 "$service" 2>/dev/null | tr -d '[:space:]')
        if [[ -n "$ip" ]]; then
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
    local service_name="${2:-service}"

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
        log ERROR "Port 80 is already in use. Required for Traefik HTTP."
        ((errors++))
    fi

    if ! check_port 443 "HTTPS"; then
        log ERROR "Port 443 is already in use. Required for Traefik HTTPS."
        ((errors++))
    fi

    if ! check_port "$port" "Dokploy"; then
        log ERROR "Port $port is already in use. Required for Dokploy web interface."
        ((errors++))
    fi

    if [[ $errors -gt 0 ]]; then
        log ERROR "Please stop the services using these ports and try again."
        log INFO "You can use 'ss -tulnp | grep :<port>' to identify the services."
        if [[ "${FORCE:-false}" != "true" ]]; then
            exit 1
        fi
        log WARN "Continuing due to FORCE=true..."
    fi

    log SUCCESS "All required ports are available."
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
    run_cmd "curl -sSL https://get.docker.com | sh -s -- --version $DOCKER_VERSION"
    log SUCCESS "Docker installed successfully."
}

init_swarm() {
    local advertise_addr="${ADVERTISE_ADDR:-$(get_private_ip)}"

    if [[ -z "$advertise_addr" ]]; then
        log ERROR "Could not determine private IP address."
        log INFO "Please set the ADVERTISE_ADDR environment variable."
        log INFO "Example: export ADVERTISE_ADDR=192.168.1.100"
        exit 1
    fi

    log INFO "Using advertise address: $advertise_addr"

    # Leave existing swarm if any
    docker swarm leave --force 2>/dev/null || true

    # Build swarm init command
    local swarm_args="--advertise-addr $advertise_addr"

    if [[ -n "${DOCKER_SWARM_INIT_ARGS:-}" ]]; then
        log INFO "Using custom swarm init arguments: $DOCKER_SWARM_INIT_ARGS"
        swarm_args="$swarm_args $DOCKER_SWARM_INIT_ARGS"
    fi

    log INFO "Initializing Docker Swarm..."
    if ! run_cmd "docker swarm init $swarm_args"; then
        die "Failed to initialize Docker Swarm."
    fi

    log SUCCESS "Docker Swarm initialized successfully."
    echo "$advertise_addr"
}

create_network() {
    log INFO "Creating Docker overlay network..."

    # Remove existing network if any
    docker network rm -f "$NETWORK_NAME" 2>/dev/null || true

    run_cmd "docker network create --driver overlay --attachable $NETWORK_NAME"
    log SUCCESS "Network '$NETWORK_NAME' created successfully."
}

# =============================================================================
# Service Functions
# =============================================================================

generate_password() {
    local length="${1:-32}"
    tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w "$length" | head -n 1
}

create_postgres_service() {
    local password="${POSTGRES_PASSWORD:-$(generate_password)}"
    local endpoint_mode="$1"

    log INFO "Creating PostgreSQL service..."

    # Build command arguments as an array
    local -a docker_args=(
        "service" "create"
        "--name" "$SERVICE_POSTGRES"
        "--constraint" "node.role==manager"
        "--network" "$NETWORK_NAME"
        "--env" "POSTGRES_USER=dokploy"
        "--env" "POSTGRES_DB=dokploy"
        "--env" "POSTGRES_PASSWORD=$password"
        "--mount" "type=volume,source=dokploy-postgres,target=/var/lib/postgresql/data"
    )

    # Add endpoint mode if set (for LXC compatibility)
    if [[ -n "$endpoint_mode" ]]; then
        docker_args+=($endpoint_mode)
    fi

    docker_args+=("postgres:$POSTGRES_VERSION")

    log INFO "Running: docker ${docker_args[*]}"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log INFO "[DRY RUN] docker ${docker_args[*]}"
    else
        if ! docker "${docker_args[@]}"; then
            log ERROR "Failed to create PostgreSQL service"
            return 1
        fi
    fi

    log SUCCESS "PostgreSQL service created."
    echo "$password"
}

create_redis_service() {
    local endpoint_mode="$1"

    log INFO "Creating Redis service..."

    # Build command arguments as an array
    local -a docker_args=(
        "service" "create"
        "--name" "$SERVICE_REDIS"
        "--constraint" "node.role==manager"
        "--network" "$NETWORK_NAME"
        "--mount" "type=volume,source=dokploy-redis,target=/data"
    )

    # Add endpoint mode if set (for LXC compatibility)
    if [[ -n "$endpoint_mode" ]]; then
        docker_args+=($endpoint_mode)
    fi

    docker_args+=("redis:$REDIS_VERSION")

    log INFO "Running: docker ${docker_args[*]}"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log INFO "[DRY RUN] docker ${docker_args[*]}"
    else
        if ! docker "${docker_args[@]}"; then
            log ERROR "Failed to create Redis service"
            return 1
        fi
    fi

    log SUCCESS "Redis service created."
}

create_dokploy_service() {
    local advertise_addr="$1"
    local endpoint_mode="$2"
    local version="${DOKPLOY_VERSION:-$DEFAULT_VERSION}"
    local registry="${DOKPLOY_REGISTRY:-$DEFAULT_REGISTRY}"
    local image="${DOKPLOY_IMAGE:-$DEFAULT_IMAGE}"
    local port="${DOKPLOY_PORT:-$DEFAULT_PORT}"
    local data_dir="${DOKPLOY_DATA_DIR:-$DEFAULT_DATA_DIR}"

    local full_image="$registry/$image:$version"

    log INFO "Creating Dokploy Enhanced service..."
    log INFO "Using image: $full_image"
    log INFO "Advertise address: $advertise_addr"
    log INFO "Port: $port"
    log INFO "Data directory: $data_dir"

    # Build command arguments as an array to handle quoting properly
    local -a docker_args=(
        "service" "create"
        "--name" "$SERVICE_DOKPLOY"
        "--replicas" "1"
        "--network" "$NETWORK_NAME"
        "--mount" "type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock"
        "--mount" "type=bind,source=$data_dir,target=/etc/dokploy"
        "--mount" "type=volume,source=dokploy,target=/root/.docker"
        "--publish" "published=$port,target=3000,mode=host"
        "--update-parallelism" "1"
        "--update-order" "stop-first"
        "--constraint" "node.role==manager"
        "--env" "ADVERTISE_ADDR=$advertise_addr"
    )

    # Add endpoint mode if set (for LXC compatibility)
    if [[ -n "$endpoint_mode" ]]; then
        # endpoint_mode is like "--endpoint-mode dnsrr", split it
        docker_args+=($endpoint_mode)
    fi

    # Add release tag env if not latest
    if [[ "$version" != "latest" ]]; then
        docker_args+=("--env" "RELEASE_TAG=$version")
    fi

    # Add the image at the end
    docker_args+=("$full_image")

    # Debug output
    if [[ "${DEBUG:-false}" == "true" ]]; then
        log DEBUG "Docker command: docker ${docker_args[*]}"
    fi
    log INFO "Running: docker ${docker_args[*]}"

    # Execute directly without eval
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log INFO "[DRY RUN] docker ${docker_args[*]}"
    else
        if ! docker "${docker_args[@]}"; then
            log ERROR "Failed to create Dokploy service"
            log ERROR "Command was: docker ${docker_args[*]}"
            return 1
        fi
    fi

    log SUCCESS "Dokploy Enhanced service created."
}

create_traefik_container() {
    local data_dir="${DOKPLOY_DATA_DIR:-$DEFAULT_DATA_DIR}"

    if [[ "${SKIP_TRAEFIK:-false}" == "true" ]]; then
        log WARN "Skipping Traefik installation (SKIP_TRAEFIK=true)."
        return 0
    fi

    log INFO "Creating Traefik container..."

    # Create traefik directories if they don't exist
    mkdir -p "$data_dir/traefik/dynamic"

    # Wait for Dokploy to create traefik config (give it a few seconds)
    local max_wait=10
    local waited=0
    while [[ ! -f "$data_dir/traefik/traefik.yml" && $waited -lt $max_wait ]]; do
        log INFO "Waiting for Dokploy to create traefik config... ($waited/$max_wait)"
        sleep 1
        waited=$((waited + 1))
    done

    # If traefik.yml doesn't exist, create a default one
    if [[ ! -f "$data_dir/traefik/traefik.yml" ]]; then
        log INFO "Creating default Traefik configuration..."
        cat > "$data_dir/traefik/traefik.yml" << 'TRAEFIK_CONFIG'
api:
  insecure: true
  dashboard: true

entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: dokploy-network
  file:
    directory: "/etc/dokploy/traefik/dynamic"
    watch: true

log:
  level: "ERROR"
TRAEFIK_CONFIG
        log SUCCESS "Default Traefik configuration created."
    fi

    # Remove existing container if any
    docker rm -f "$CONTAINER_TRAEFIK" 2>/dev/null || true

    # Build docker run command as array
    local -a docker_args=(
        "run" "-d"
        "--name" "$CONTAINER_TRAEFIK"
        "--restart" "always"
        "-v" "$data_dir/traefik/traefik.yml:/etc/traefik/traefik.yml"
        "-v" "$data_dir/traefik/dynamic:/etc/dokploy/traefik/dynamic"
        "-v" "/var/run/docker.sock:/var/run/docker.sock:ro"
        "-p" "80:80/tcp"
        "-p" "443:443/tcp"
        "-p" "443:443/udp"
        "traefik:$TRAEFIK_VERSION"
    )

    log INFO "Running: docker ${docker_args[*]}"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log INFO "[DRY RUN] docker ${docker_args[*]}"
    else
        if ! docker "${docker_args[@]}"; then
            log ERROR "Failed to create Traefik container"
            log ERROR "Command was: docker ${docker_args[*]}"
            return 1
        fi
    fi

    # Connect Traefik to the network
    log INFO "Connecting Traefik to network $NETWORK_NAME..."
    docker network connect "$NETWORK_NAME" "$CONTAINER_TRAEFIK" 2>/dev/null || true

    log SUCCESS "Traefik container created."
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

    # Environment info
    local distro
    distro=$(get_distro)
    log INFO "Detected distribution: $distro"

    if is_proxmox_lxc; then
        log WARN "Detected Proxmox LXC container environment."
        log WARN "Adding --endpoint-mode dnsrr for LXC compatibility."
    fi

    if is_wsl; then
        log WARN "Detected WSL environment. Some features may not work correctly."
    fi

    # Install Docker
    install_docker

    # Determine endpoint mode for LXC
    local endpoint_mode=""
    if is_proxmox_lxc; then
        endpoint_mode="--endpoint-mode dnsrr"
    fi

    # Initialize Swarm
    local advertise_addr
    advertise_addr=$(init_swarm)

    # Create network
    create_network

    # Create data directory
    local data_dir="${DOKPLOY_DATA_DIR:-$DEFAULT_DATA_DIR}"
    mkdir -p "$data_dir"
    chmod 777 "$data_dir"
    log SUCCESS "Data directory created: $data_dir"

    # Create services
    local pg_password
    pg_password=$(create_postgres_service "$endpoint_mode")
    create_redis_service "$endpoint_mode"
    create_dokploy_service "$advertise_addr" "$endpoint_mode"

    # Wait a bit for services to start
    log INFO "Waiting for services to initialize..."
    sleep 5

    # Create Traefik
    create_traefik_container

    # Get access URL
    local public_ip
    public_ip="${ADVERTISE_ADDR:-$(get_public_ip)}" || public_ip="$advertise_addr"
    local formatted_addr
    formatted_addr=$(format_ip_for_url "$public_ip")
    local port="${DOKPLOY_PORT:-$DEFAULT_PORT}"

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
    printf "${CYAN}PostgreSQL password:${NC} ${pg_password}\n"
    printf "${CYAN}Data directory:${NC} ${data_dir}\n"
    echo ""
    printf "${CYAN}Useful commands:${NC}\n"
    printf "  View status:    ${YELLOW}docker service ls${NC}\n"
    printf "  View logs:      ${YELLOW}docker service logs dokploy${NC}\n"
    printf "  Update:         ${YELLOW}curl -sSL <install-url> | bash -s -- update${NC}\n"
    echo ""

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

    log SUCCESS "Installation completed successfully!"
}

cmd_update() {
    log INFO "Updating Dokploy Enhanced..."

    check_root

    local version="${DOKPLOY_VERSION:-$DEFAULT_VERSION}"
    local registry="${DOKPLOY_REGISTRY:-$DEFAULT_REGISTRY}"
    local image="${DOKPLOY_IMAGE:-$DEFAULT_IMAGE}"
    local full_image="$registry/$image:$version"

    log INFO "Pulling new image: $full_image"
    run_cmd "docker pull $full_image"

    log INFO "Updating Dokploy service..."
    run_cmd "docker service update --image $full_image $SERVICE_DOKPLOY"

    log SUCCESS "Dokploy Enhanced updated to version: $version"
}

cmd_uninstall() {
    log WARN "This will remove Dokploy Enhanced and all its data!"

    if ! confirm "Are you sure you want to continue?"; then
        log INFO "Uninstall cancelled."
        exit 0
    fi

    check_root

    log INFO "Stopping and removing services..."

    # Remove services
    docker service rm "$SERVICE_DOKPLOY" 2>/dev/null || true
    docker service rm "$SERVICE_POSTGRES" 2>/dev/null || true
    docker service rm "$SERVICE_REDIS" 2>/dev/null || true

    # Remove Traefik container
    docker rm -f "$CONTAINER_TRAEFIK" 2>/dev/null || true

    # Remove network
    docker network rm "$NETWORK_NAME" 2>/dev/null || true

    # Leave swarm
    docker swarm leave --force 2>/dev/null || true

    if confirm "Remove Docker volumes (this will delete all data)?"; then
        log INFO "Removing Docker volumes..."
        docker volume rm dokploy dokploy-postgres dokploy-redis 2>/dev/null || true
    fi

    if confirm "Remove data directory (${DOKPLOY_DATA_DIR:-$DEFAULT_DATA_DIR})?"; then
        local data_dir="${DOKPLOY_DATA_DIR:-$DEFAULT_DATA_DIR}"
        rm -rf "$data_dir"
        log INFO "Data directory removed."
    fi

    log SUCCESS "Dokploy Enhanced has been uninstalled."
}

cmd_status() {
    echo ""
    printf "${CYAN}=== Dokploy Enhanced Status ===${NC}\n"
    echo ""

    printf "${BOLD}Docker Services:${NC}\n"
    docker service ls 2>/dev/null || echo "No swarm services found."
    echo ""

    printf "${BOLD}Containers:${NC}\n"
    docker ps --filter "name=dokploy" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null
    echo ""

    printf "${BOLD}Volumes:${NC}\n"
    docker volume ls --filter "name=dokploy" 2>/dev/null
    echo ""

    printf "${BOLD}Network:${NC}\n"
    docker network ls --filter "name=$NETWORK_NAME" 2>/dev/null
    echo ""

    local data_dir="${DOKPLOY_DATA_DIR:-$DEFAULT_DATA_DIR}"
    if [[ -f "$data_dir/install-info.json" ]]; then
        printf "${BOLD}Installation Info:${NC}\n"
        cat "$data_dir/install-info.json"
        echo ""
    fi
}

cmd_backup() {
    check_root

    local backup_dir="${BACKUP_DIR:-$DEFAULT_BACKUP_DIR}"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$backup_dir/dokploy_backup_$timestamp"

    log INFO "Creating backup at: $backup_path"

    mkdir -p "$backup_path"

    # Backup data directory
    local data_dir="${DOKPLOY_DATA_DIR:-$DEFAULT_DATA_DIR}"
    if [[ -d "$data_dir" ]]; then
        log INFO "Backing up data directory..."
        cp -r "$data_dir" "$backup_path/data"
    fi

    # Backup Docker volumes
    log INFO "Backing up PostgreSQL data..."
    docker run --rm \
        -v dokploy-postgres:/data \
        -v "$backup_path":/backup \
        alpine tar czf /backup/postgres.tar.gz -C /data . 2>/dev/null || \
        log WARN "PostgreSQL backup failed or volume doesn't exist."

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

cmd_restore() {
    check_root

    local backup_path="$1"

    if [[ -z "$backup_path" || ! -d "$backup_path" ]]; then
        die "Please provide a valid backup directory path."
    fi

    log WARN "This will restore from backup and overwrite current data!"

    if ! confirm "Are you sure you want to continue?"; then
        log INFO "Restore cancelled."
        exit 0
    fi

    log INFO "Restoring from: $backup_path"

    # Stop services
    docker service scale "$SERVICE_DOKPLOY=0" 2>/dev/null || true

    # Restore data directory
    local data_dir="${DOKPLOY_DATA_DIR:-$DEFAULT_DATA_DIR}"
    if [[ -d "$backup_path/data" ]]; then
        log INFO "Restoring data directory..."
        rm -rf "$data_dir"
        cp -r "$backup_path/data" "$data_dir"
    fi

    # Restore PostgreSQL
    if [[ -f "$backup_path/postgres.tar.gz" ]]; then
        log INFO "Restoring PostgreSQL data..."
        docker run --rm \
            -v dokploy-postgres:/data \
            -v "$backup_path":/backup \
            alpine sh -c "rm -rf /data/* && tar xzf /backup/postgres.tar.gz -C /data"
    fi

    # Restore Redis
    if [[ -f "$backup_path/redis.tar.gz" ]]; then
        log INFO "Restoring Redis data..."
        docker run --rm \
            -v dokploy-redis:/data \
            -v "$backup_path":/backup \
            alpine sh -c "rm -rf /data/* && tar xzf /backup/redis.tar.gz -C /data"
    fi

    # Restart services
    docker service scale "$SERVICE_DOKPLOY=1" 2>/dev/null || true

    log SUCCESS "Restore completed!"
}

cmd_logs() {
    local service="${1:-$SERVICE_DOKPLOY}"
    local follow="${2:-}"

    if [[ "$follow" == "-f" || "$follow" == "--follow" ]]; then
        docker service logs -f "$service"
    else
        docker service logs --tail 100 "$service"
    fi
}

cmd_help() {
    cat << EOF
${BOLD}Dokploy Enhanced Installer v${SCRIPT_VERSION}${NC}

${CYAN}Usage:${NC}
    $0 [command] [options]

${CYAN}Commands:${NC}
    install     Install Dokploy Enhanced (default if no command given)
    update      Update Dokploy Enhanced to the latest version
    uninstall   Remove Dokploy Enhanced and optionally all data
    status      Show current status of Dokploy Enhanced
    backup      Create a backup of all Dokploy data
    restore     Restore from a backup (requires backup path)
    logs        Show service logs (use -f to follow)
    help        Show this help message

${CYAN}Environment Variables:${NC}
    DOKPLOY_VERSION          Docker image tag (default: latest)
    DOKPLOY_PORT             Web interface port (default: 3000)
    DOKPLOY_REGISTRY         Docker registry (default: ghcr.io/amirhmoradi)
    DOKPLOY_IMAGE            Docker image name (default: dokploy-enhanced)
    DOKPLOY_DATA_DIR         Data directory (default: /etc/dokploy)
    ADVERTISE_ADDR           Docker Swarm advertise address
    DOCKER_SWARM_INIT_ARGS   Additional Docker Swarm init arguments
    SKIP_DOCKER_INSTALL      Skip Docker installation (true/false)
    SKIP_TRAEFIK             Skip Traefik installation (true/false)
    POSTGRES_PASSWORD        Custom PostgreSQL password
    BACKUP_DIR               Backup directory (default: /var/backups/dokploy)
    DRY_RUN                  Show commands without executing (true/false)
    FORCE                    Force installation even with warnings (true/false)
    DEBUG                    Enable debug output (true/false)

${CYAN}Examples:${NC}
    # Basic installation
    curl -sSL <url> | bash

    # Install specific version
    DOKPLOY_VERSION=20241216 curl -sSL <url> | bash

    # Install with custom port
    DOKPLOY_PORT=8080 curl -sSL <url> | bash

    # Update to latest
    curl -sSL <url> | bash -s -- update

    # Create backup
    curl -sSL <url> | bash -s -- backup

    # Show status
    curl -sSL <url> | bash -s -- status

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
        uninstall|remove)
            cmd_uninstall
            ;;
        status)
            cmd_status
            ;;
        backup)
            cmd_backup
            ;;
        restore)
            shift
            cmd_restore "$@"
            ;;
        logs)
            shift
            cmd_logs "$@"
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
