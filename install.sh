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

readonly SCRIPT_VERSION="2.2.0"
readonly SCRIPT_NAME="dokploy-enhanced-installer"

# Default configuration
readonly DEFAULT_REGISTRY="ghcr.io/amirhmoradi"
readonly DEFAULT_IMAGE="dokploy-enhanced"
readonly DEFAULT_VERSION="latest"
readonly DEFAULT_PORT="3000"
readonly DEFAULT_DATA_DIR="/etc/dokploy"
readonly DEFAULT_DEPLOY_MODE="standalone"  # standalone or swarm
readonly STACK_NAME="dokploy"

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

    # All log output goes to stderr to avoid interfering with function return values
    case "$level" in
        INFO)    printf "${BLUE}[INFO]${NC}  %s - %s\n" "$timestamp" "$message" >&2 ;;
        SUCCESS) printf "${GREEN}[OK]${NC}    %s - %s\n" "$timestamp" "$message" >&2 ;;
        WARN)    printf "${YELLOW}[WARN]${NC}  %s - %s\n" "$timestamp" "$message" >&2 ;;
        ERROR)   printf "${RED}[ERROR]${NC} %s - %s\n" "$timestamp" "$message" >&2 ;;
        DEBUG)   [[ "${DEBUG:-false}" == "true" ]] && printf "[DEBUG] %s - %s\n" "$timestamp" "$message" >&2 ;;
        *)       printf "%s - %s\n" "$timestamp" "$message" >&2 ;;
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

    # Read from /dev/tty to work when script is piped to bash
    local yn
    if [[ "$default" == "y" ]]; then
        printf "%s [Y/n] " "$prompt" >&2
        read -r yn < /dev/tty || yn=""
        yn=${yn:-y}
    else
        printf "%s [y/N] " "$prompt" >&2
        read -r yn < /dev/tty || yn=""
        yn=${yn:-n}
    fi

    [[ "${yn,,}" == "y" || "${yn,,}" == "yes" ]]
}

# Handle existing file with user prompts
# Returns: 0 = proceed (overwrite or backup done), 1 = keep existing, 2 = abort
handle_existing_file() {
    local file_path="$1"
    local file_desc="${2:-file}"

    if [[ ! -f "$file_path" ]]; then
        return 0  # File doesn't exist, proceed with creation
    fi

    if [[ "${FORCE:-false}" == "true" ]]; then
        log INFO "Overwriting existing $file_desc (FORCE mode)."
        return 0
    fi

    echo "" >&2
    printf "${YELLOW}Existing $file_desc found:${NC} $file_path\n" >&2
    echo "" >&2
    printf "What would you like to do?\n" >&2
    printf "  ${CYAN}1)${NC} Overwrite - Replace with new configuration\n" >&2
    printf "  ${CYAN}2)${NC} Backup    - Backup existing and create new\n" >&2
    printf "  ${CYAN}3)${NC} Keep      - Keep existing file, skip generation\n" >&2
    printf "  ${CYAN}4)${NC} Abort     - Cancel installation\n" >&2
    echo "" >&2

    # Read from /dev/tty to work when script is piped to bash
    local choice
    printf "Enter choice [1-4]: " >&2
    read -r choice < /dev/tty || choice=""

    case "$choice" in
        1|overwrite|o)
            log INFO "Overwriting existing $file_desc."
            return 0
            ;;
        2|backup|b)
            local timestamp
            timestamp=$(date +%Y%m%d_%H%M%S)
            local backup_path="${file_path}.backup.${timestamp}"
            cp "$file_path" "$backup_path"
            log SUCCESS "Backup created: $backup_path"
            return 0
            ;;
        3|keep|k)
            log INFO "Keeping existing $file_desc."
            return 1
            ;;
        4|abort|a)
            log INFO "Installation aborted by user."
            exit 0
            ;;
        *)
            log WARN "Invalid choice. Defaulting to 'keep existing'."
            return 1
            ;;
    esac
}

# Select deployment mode
select_deploy_mode() {
    local mode="${DEPLOY_MODE:-}"

    if [[ -n "$mode" ]]; then
        if [[ "$mode" != "standalone" && "$mode" != "swarm" ]]; then
            die "Invalid DEPLOY_MODE: $mode. Must be 'standalone' or 'swarm'."
        fi
        echo "$mode"
        return 0
    fi

    if [[ "${FORCE:-false}" == "true" ]]; then
        echo "$DEFAULT_DEPLOY_MODE"
        return 0
    fi

    echo "" >&2
    printf "${CYAN}Select deployment mode:${NC}\n" >&2
    echo "" >&2
    printf "  ${CYAN}1)${NC} Standalone - Uses docker-compose (recommended for single node)\n" >&2
    printf "  ${CYAN}2)${NC} Swarm      - Uses docker stack deploy (for multi-node clusters)\n" >&2
    echo "" >&2

    local choice
    printf "Enter choice [1-2] (default: 1): " >&2
    read -r choice < /dev/tty || choice=""
    choice=${choice:-1}

    case "$choice" in
        1|standalone|s)
            echo "standalone"
            ;;
        2|swarm|w)
            echo "swarm"
            ;;
        *)
            log WARN "Invalid choice. Using standalone mode."
            echo "standalone"
            ;;
    esac
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
    # Redirect swarm init output to stderr so it doesn't get captured
    if ! docker swarm init --advertise-addr "$advertise_addr" >&2; then
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
    local deploy_mode="$4"
    local env_file="$data_dir/.env"

    # Check for existing file
    if ! handle_existing_file "$env_file" ".env configuration file"; then
        log INFO "Using existing .env file."
        return 0
    fi

    log INFO "Generating .env file..."

    cat > "$env_file" << EOF
# =============================================================================
# Dokploy Enhanced Configuration
# Generated on $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# =============================================================================

# Deployment Mode (standalone or swarm)
DEPLOY_MODE=${deploy_mode}

# Docker Registry
DOKPLOY_REGISTRY=${DOKPLOY_REGISTRY:-$DEFAULT_REGISTRY}
DOKPLOY_IMAGE=${DOKPLOY_IMAGE:-$DEFAULT_IMAGE}
DOKPLOY_VERSION=${DOKPLOY_VERSION:-$DEFAULT_VERSION}

# Network
ADVERTISE_ADDR=${advertise_addr}
DOKPLOY_PORT=${DOKPLOY_PORT:-$DEFAULT_PORT}

# Data Directory
DATA_DIR=${data_dir}

# PostgreSQL
POSTGRES_USER=dokploy
POSTGRES_DB=dokploy
POSTGRES_PASSWORD=${pg_password}
DATABASE_URL=postgresql://dokploy:${pg_password}@postgres:5432/dokploy

# Redis
REDIS_URL=redis://redis:6379

# Traefik
SKIP_TRAEFIK=${SKIP_TRAEFIK:-false}
EOF

    chmod 600 "$env_file"
    log SUCCESS ".env file created at $env_file"
}

generate_docker_compose() {
    local data_dir="$1"
    local compose_file="$data_dir/docker-compose.yml"

    # Check for existing file
    if ! handle_existing_file "$compose_file" "docker-compose.yml"; then
        log INFO "Using existing docker-compose.yml file."
        return 0
    fi

    log INFO "Generating docker-compose.yml..."

    # Note: Using mixed heredoc - unquoted EOF allows variable expansion for hardcoded values
    cat > "$compose_file" << EOF
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
    image: \${DOKPLOY_REGISTRY}/\${DOKPLOY_IMAGE}:\${DOKPLOY_VERSION}
    container_name: dokploy
    restart: unless-stopped
    networks:
      - dokploy-network
    ports:
      - "\${DOKPLOY_PORT}:3000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - \${DATA_DIR}:/etc/dokploy
      - dokploy-docker:/root/.docker
    environment:
      - ADVERTISE_ADDR=\${ADVERTISE_ADDR}
      - DATABASE_URL=\${DATABASE_URL}
      - REDIS_URL=\${REDIS_URL}
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
      - POSTGRES_USER=\${POSTGRES_USER}
      - POSTGRES_DB=\${POSTGRES_DB}
      - POSTGRES_PASSWORD=\${POSTGRES_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \${POSTGRES_USER} -d \${POSTGRES_DB}"]
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
      - \${DATA_DIR}/traefik/traefik.yml:/etc/traefik/traefik.yml:ro
      - \${DATA_DIR}/traefik/dynamic:/etc/traefik/dynamic:ro
      - \${DATA_DIR}/traefik/acme:/etc/traefik/acme

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
    local traefik_config="$data_dir/traefik/traefik.yml"

    log INFO "Setting up Traefik configuration..."

    mkdir -p "$data_dir/traefik/dynamic"
    mkdir -p "$data_dir/traefik/acme"

    # Check for existing file
    if ! handle_existing_file "$traefik_config" "Traefik configuration file"; then
        log INFO "Using existing Traefik configuration."
        return 0
    fi

    cat > "$traefik_config" << 'EOF'
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
}

# =============================================================================
# Docker Compose/Stack Wrapper
# =============================================================================

# Get deploy mode from .env file
get_deploy_mode() {
    local data_dir="${DOKPLOY_DATA_DIR:-$DEFAULT_DATA_DIR}"
    local env_file="$data_dir/.env"

    if [[ -f "$env_file" ]]; then
        grep -E "^DEPLOY_MODE=" "$env_file" 2>/dev/null | cut -d= -f2 || echo "$DEFAULT_DEPLOY_MODE"
    else
        echo "$DEFAULT_DEPLOY_MODE"
    fi
}

# Wrapper for docker-compose commands (standalone mode)
compose_cmd() {
    local data_dir="${DOKPLOY_DATA_DIR:-$DEFAULT_DATA_DIR}"

    if docker compose version &>/dev/null; then
        docker compose -f "$data_dir/docker-compose.yml" --env-file "$data_dir/.env" "$@"
    else
        docker-compose -f "$data_dir/docker-compose.yml" --env-file "$data_dir/.env" "$@"
    fi
}

# Deploy using docker stack (swarm mode)
stack_deploy() {
    local data_dir="${DOKPLOY_DATA_DIR:-$DEFAULT_DATA_DIR}"
    local env_file="$data_dir/.env"
    local compose_file="$data_dir/docker-compose.yml"
    local rendered_file="$data_dir/docker-compose.rendered.yml"

    # Check if compose file exists
    if [[ ! -f "$compose_file" ]]; then
        die "docker-compose.yml not found at $compose_file"
    fi

    # Source the env file to export variables for rendering
    if [[ -f "$env_file" ]]; then
        set -a
        # shellcheck source=/dev/null
        source "$env_file"
        set +a
    fi

    # Render the compose file using docker compose config
    # This expands all environment variables and validates the file
    log INFO "Rendering docker-compose.yml for swarm deployment..."
    if docker compose version &>/dev/null; then
        docker compose -f "$compose_file" --env-file "$env_file" config > "$rendered_file" 2>/dev/null || {
            log WARN "Failed to render with docker compose, using original file"
            cp "$compose_file" "$rendered_file"
        }
    else
        # Fallback: just copy the file and let docker stack handle variable expansion
        cp "$compose_file" "$rendered_file"
    fi

    # Post-process the rendered file for swarm compatibility
    if command_exists sed; then
        # Remove root-level 'name' property - added by docker compose config but not supported by docker stack
        sed -i '/^name:/d' "$rendered_file" 2>/dev/null || true
        # Remove 'profiles' sections as they're not supported by docker stack
        sed -i '/^\s*profiles:/,/^\s*[^-]/{ /^\s*profiles:/d; /^\s*-/d; }' "$rendered_file" 2>/dev/null || true
        # Remove 'container_name' as it's ignored in swarm
        sed -i '/^\s*container_name:/d' "$rendered_file" 2>/dev/null || true
        # Fix port format: convert published: "3000" to published: 3000 (remove quotes around numbers)
        sed -i 's/published: "\([0-9]*\)"/published: \1/g' "$rendered_file" 2>/dev/null || true
        # Also fix short-form ports if any
        sed -i 's/- "\([0-9]*:[0-9]*\)"/- \1/g' "$rendered_file" 2>/dev/null || true
    fi

    # Remove 'depends_on' sections - not supported in swarm mode (swarm ignores service dependencies
    # and manages orchestration differently). docker compose config converts simple list format to
    # long format with conditions, which causes "must be a list" errors with docker stack deploy.
    if command_exists awk; then
        awk '
        /^[[:space:]]*depends_on:[[:space:]]*$/ {
            # Store the indentation level of depends_on
            match($0, /^[[:space:]]*/)
            base_indent = RLENGTH
            in_depends_on = 1
            next
        }
        in_depends_on {
            # Check current line indentation
            if ($0 ~ /^[[:space:]]*$/) next  # Skip empty lines
            match($0, /^[[:space:]]*/)
            current_indent = RLENGTH
            # Exit depends_on block when we hit same or lesser indentation
            if (current_indent <= base_indent) {
                in_depends_on = 0
                print
                next
            }
            # Skip lines that are part of depends_on block
            next
        }
        { print }
        ' "$rendered_file" > "${rendered_file}.tmp" && mv "${rendered_file}.tmp" "$rendered_file"
    fi

    # Deploy the stack
    log INFO "Deploying stack '$STACK_NAME'..."
    if ! docker stack deploy -c "$rendered_file" "$STACK_NAME" --with-registry-auth; then
        die "Failed to deploy stack. Check the logs above for details."
    fi

    log SUCCESS "Stack '$STACK_NAME' deployed successfully."
}

# Remove the stack (swarm mode)
stack_remove() {
    docker stack rm "$STACK_NAME"
}

# Get stack/compose status based on deploy mode
services_status() {
    local deploy_mode
    deploy_mode=$(get_deploy_mode)

    if [[ "$deploy_mode" == "swarm" ]]; then
        docker stack services "$STACK_NAME" 2>/dev/null || echo "Stack not deployed"
    else
        compose_cmd ps
    fi
}

# Start services based on deploy mode
services_up() {
    local deploy_mode
    deploy_mode=$(get_deploy_mode)
    local skip_traefik="${SKIP_TRAEFIK:-false}"

    if [[ "$deploy_mode" == "swarm" ]]; then
        if [[ "$skip_traefik" == "true" ]]; then
            log WARN "SKIP_TRAEFIK is not fully supported in swarm mode. Traefik will be deployed but can be scaled to 0."
        fi
        stack_deploy
    else
        log INFO "Starting services with docker-compose..."
        if [[ "$skip_traefik" == "true" ]]; then
            compose_cmd up -d
        else
            compose_cmd --profile traefik up -d
        fi
    fi
}

# Stop services based on deploy mode
services_down() {
    local deploy_mode
    deploy_mode=$(get_deploy_mode)

    if [[ "$deploy_mode" == "swarm" ]]; then
        log INFO "Removing stack from Docker Swarm..."
        stack_remove
    else
        log INFO "Stopping docker-compose services..."
        compose_cmd --profile traefik down
    fi
}

# Stop services without removing (compose only)
services_stop() {
    local deploy_mode
    deploy_mode=$(get_deploy_mode)

    if [[ "$deploy_mode" == "swarm" ]]; then
        log WARN "Swarm mode does not support stop. Use 'uninstall' to remove the stack."
        log INFO "To scale down, you can use: docker service scale ${STACK_NAME}_dokploy=0"
    else
        compose_cmd stop
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

    # Select deployment mode
    local deploy_mode
    deploy_mode=$(select_deploy_mode)
    log INFO "Deployment mode: $deploy_mode"

    # Install Docker and Docker Compose
    install_docker
    install_docker_compose

    # Initialize Swarm (required for overlay network, even in standalone mode)
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
    generate_env_file "$data_dir" "$advertise_addr" "$pg_password" "$deploy_mode"
    generate_docker_compose "$data_dir"
    generate_traefik_config "$data_dir"

    # Start services using the appropriate method for deploy mode
    services_up

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
    local deploy_mode
    deploy_mode=$(get_deploy_mode)

    if [[ ! -f "$data_dir/docker-compose.yml" ]]; then
        die "docker-compose.yml not found. Please run install first."
    fi

    if [[ "$deploy_mode" == "swarm" ]]; then
        log INFO "Updating swarm stack..."
        # Pull images first
        docker pull "${DOKPLOY_REGISTRY:-$DEFAULT_REGISTRY}/${DOKPLOY_IMAGE:-$DEFAULT_IMAGE}:${DOKPLOY_VERSION:-$DEFAULT_VERSION}"
        docker pull "postgres:${POSTGRES_VERSION}"
        docker pull "redis:${REDIS_VERSION}"
        docker pull "traefik:${TRAEFIK_VERSION}"
        # Redeploy stack
        stack_deploy
    else
        log INFO "Pulling latest images..."
        compose_cmd pull
        log INFO "Recreating containers with new images..."
        services_up
    fi

    log SUCCESS "Dokploy Enhanced updated successfully!"
}

cmd_stop() {
    log INFO "Stopping Dokploy Enhanced services..."
    check_root

    services_stop

    log SUCCESS "Services stopped."
}

cmd_start() {
    log INFO "Starting Dokploy Enhanced services..."
    check_root

    services_up

    log SUCCESS "Services started."
}

cmd_restart() {
    log INFO "Restarting Dokploy Enhanced services..."
    check_root

    local deploy_mode
    deploy_mode=$(get_deploy_mode)

    if [[ "$deploy_mode" == "swarm" ]]; then
        log INFO "Redeploying swarm stack..."
        stack_deploy
    else
        compose_cmd restart
    fi

    log SUCCESS "Services restarted."
}

cmd_status() {
    local data_dir="${DOKPLOY_DATA_DIR:-$DEFAULT_DATA_DIR}"
    local deploy_mode
    deploy_mode=$(get_deploy_mode)

    echo ""
    printf "${CYAN}=== Dokploy Enhanced Status ===${NC}\n"
    echo ""

    printf "${BOLD}Deploy Mode:${NC} $deploy_mode\n"
    echo ""

    printf "${BOLD}Services:${NC}\n"
    services_status
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
        grep -v "PASSWORD" "$data_dir/.env" | grep -v "DATABASE_URL" | grep -v "^#" | grep -v "^$" | head -20
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
    local deploy_mode
    deploy_mode=$(get_deploy_mode)

    if [[ "$deploy_mode" == "swarm" ]]; then
        # Swarm mode: use docker service logs
        if [[ -n "$service" && "$service" != "-f" ]]; then
            local svc_name="${STACK_NAME}_${service}"
            if [[ "$follow" == "-f" ]]; then
                docker service logs -f "$svc_name" 2>/dev/null || docker service logs -f "$service"
            else
                docker service logs --tail 100 "$svc_name" 2>/dev/null || docker service logs --tail 100 "$service"
            fi
        else
            # Show all stack services logs
            log INFO "Showing logs for all stack services..."
            if [[ "$service" == "-f" || "$follow" == "-f" ]]; then
                docker service logs -f "${STACK_NAME}_dokploy"
            else
                for svc in dokploy postgres redis; do
                    printf "\n${CYAN}=== ${svc} ===${NC}\n"
                    docker service logs --tail 50 "${STACK_NAME}_${svc}" 2>/dev/null || true
                done
            fi
        fi
    else
        # Standalone mode: use docker-compose logs
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
    local deploy_mode
    deploy_mode=$(get_deploy_mode)

    log INFO "Stopping and removing services..."
    if [[ "$deploy_mode" == "swarm" ]]; then
        docker stack rm "$STACK_NAME" 2>/dev/null || true
        sleep 5
    else
        compose_cmd --profile traefik down 2>/dev/null || true
    fi

    if confirm "Remove Docker volumes (this will delete all data)?"; then
        log INFO "Removing Docker volumes..."
        if [[ "$deploy_mode" != "swarm" ]]; then
            compose_cmd --profile traefik down -v 2>/dev/null || true
        fi
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

cmd_nuke() {
    log WARN "============================================"
    log WARN "  NUCLEAR OPTION - COMPLETE DESTRUCTION    "
    log WARN "============================================"
    log WARN ""
    log WARN "This will COMPLETELY REMOVE:"
    log WARN "  - All Dokploy containers and services"
    log WARN "  - All Docker volumes (PostgreSQL, Redis data)"
    log WARN "  - The dokploy-network"
    log WARN "  - Leave Docker Swarm"
    log WARN "  - Delete /etc/dokploy directory"
    log WARN "  - All backups in /var/backups/dokploy"
    log WARN ""
    log WARN "This action is IRREVERSIBLE!"
    log WARN ""

    if ! confirm "Type 'y' to confirm COMPLETE DESTRUCTION"; then
        log INFO "Nuke cancelled. Your data is safe."
        exit 0
    fi

    # Double confirm for safety
    echo "" >&2
    printf "${RED}Are you ABSOLUTELY SURE? This cannot be undone!${NC}\n" >&2
    printf "Type 'NUKE' to confirm: " >&2
    local confirmation
    read -r confirmation < /dev/tty || confirmation=""

    if [[ "$confirmation" != "NUKE" ]]; then
        log INFO "Nuke cancelled. Your data is safe."
        exit 0
    fi

    check_root

    local data_dir="${DOKPLOY_DATA_DIR:-$DEFAULT_DATA_DIR}"

    log INFO "Starting nuclear cleanup..."

    # Stop and remove swarm stack
    log INFO "Removing Docker stack..."
    docker stack rm "$STACK_NAME" 2>/dev/null || true
    sleep 3

    # Stop and remove compose services
    log INFO "Removing docker-compose services..."
    compose_cmd --profile traefik down -v 2>/dev/null || true

    # Remove any remaining dokploy containers
    log INFO "Removing any remaining containers..."
    docker ps -a --filter "name=dokploy" -q | xargs -r docker rm -f 2>/dev/null || true

    # Remove Docker swarm services
    log INFO "Removing Docker swarm services..."
    docker service rm dokploy dokploy-postgres dokploy-redis 2>/dev/null || true

    # Remove all dokploy volumes
    log INFO "Removing Docker volumes..."
    docker volume rm dokploy-docker dokploy-postgres dokploy-redis 2>/dev/null || true
    docker volume ls --filter "name=dokploy" -q | xargs -r docker volume rm 2>/dev/null || true

    # Remove network
    log INFO "Removing Docker network..."
    docker network rm "$NETWORK_NAME" 2>/dev/null || true

    # Leave swarm
    log INFO "Leaving Docker Swarm..."
    docker swarm leave --force 2>/dev/null || true

    # Remove data directory
    log INFO "Removing data directory..."
    rm -rf "$data_dir"

    # Remove backups
    log INFO "Removing backups..."
    rm -rf /var/backups/dokploy

    echo ""
    printf "${GREEN}============================================${NC}\n"
    printf "${GREEN}  Nuclear cleanup complete!                 ${NC}\n"
    printf "${GREEN}============================================${NC}\n"
    echo ""
    log SUCCESS "All Dokploy Enhanced data has been removed."
    log INFO "You can now run 'install' for a fresh start."
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
    migrate     Migrate from official Dokploy to Dokploy Enhanced
    uninstall   Remove Dokploy Enhanced and optionally all data
    nuke        Complete destruction - remove everything and start fresh
    help        Show this help message

${CYAN}Deployment Modes:${NC}
    standalone  Uses docker-compose (recommended for single node)
    swarm       Uses docker stack deploy (for multi-node clusters)

${CYAN}Environment Variables:${NC}
    DEPLOY_MODE              Deployment mode: standalone or swarm (default: standalone)
    DOKPLOY_VERSION          Docker image tag (default: latest)
    DOKPLOY_PORT             Web interface port (default: 3000)
    DOKPLOY_REGISTRY         Docker registry (default: ghcr.io/amirhmoradi)
    DOKPLOY_IMAGE            Docker image name (default: dokploy-enhanced)
    DOKPLOY_DATA_DIR         Data directory (default: /etc/dokploy)
    ADVERTISE_ADDR           Docker Swarm advertise address
    SKIP_DOCKER_INSTALL      Skip Docker installation (true/false)
    SKIP_TRAEFIK             Skip Traefik installation (true/false)
    POSTGRES_PASSWORD        Custom PostgreSQL password
    FORCE                    Skip all prompts, use defaults (true/false)
    DEBUG                    Enable debug output (true/false)

${CYAN}Configuration Files:${NC}
    After installation, configuration is stored in:
    - ${DEFAULT_DATA_DIR}/.env              - Environment variables
    - ${DEFAULT_DATA_DIR}/docker-compose.yml - Docker Compose configuration
    - ${DEFAULT_DATA_DIR}/traefik/          - Traefik configuration

${CYAN}Examples:${NC}
    # Basic installation (interactive mode selection)
    curl -sSL <url> | bash

    # Install with swarm mode
    DEPLOY_MODE=swarm curl -sSL <url> | bash

    # Install with standalone mode (no prompts)
    FORCE=true DEPLOY_MODE=standalone curl -sSL <url> | bash

    # Install specific version
    DOKPLOY_VERSION=20241216 curl -sSL <url> | bash

    # Install with custom port
    DOKPLOY_PORT=8080 curl -sSL <url> | bash

    # Migrate from official Dokploy
    $0 migrate

    # Update to latest
    $0 update

    # View logs
    $0 logs -f

    # Complete reset (nuclear option)
    $0 nuke

${CYAN}More Information:${NC}
    GitHub: https://github.com/amirhmoradi/dokploy-enhanced
    Docs:   https://github.com/amirhmoradi/dokploy-enhanced#readme

EOF
}

# =============================================================================
# Migration from Official Dokploy
# =============================================================================

detect_official_dokploy() {
    # Check if official Dokploy Docker Swarm services exist
    if docker service ls 2>/dev/null | grep -q "dokploy"; then
        return 0
    fi
    return 1
}

get_service_env() {
    local service_name="$1"
    local env_name="$2"
    docker service inspect "$service_name" 2>/dev/null | \
        grep -oP "(?<=\"${env_name}=)[^\"]*" | head -1
}

get_postgres_password_from_service() {
    # Try to get password from dokploy-postgres service
    local password
    password=$(docker service inspect dokploy-postgres 2>/dev/null | \
        grep -oP '(?<="POSTGRES_PASSWORD=)[^"]*' | head -1)

    if [[ -z "$password" ]]; then
        # Try to get from dokploy service DATABASE_URL
        local db_url
        db_url=$(docker service inspect dokploy 2>/dev/null | \
            grep -oP '(?<="DATABASE_URL=)[^"]*' | head -1)
        if [[ -n "$db_url" ]]; then
            # Extract password from postgresql://user:password@host/db
            password=$(echo "$db_url" | grep -oP '(?<=:)[^:@]+(?=@)')
        fi
    fi

    echo "$password"
}

get_advertise_addr_from_swarm() {
    docker info 2>/dev/null | grep -oP '(?<=Advertise Address: )[^\s]+' | head -1
}

cmd_migrate() {
    log INFO "Starting migration from official Dokploy to Dokploy Enhanced..."
    log INFO "Script version: $SCRIPT_VERSION"

    check_root

    # Check if official Dokploy is installed
    if ! detect_official_dokploy; then
        log ERROR "No official Dokploy installation detected."
        log INFO "This command migrates an existing official Dokploy installation"
        log INFO "to the Dokploy Enhanced docker-compose based setup."
        log INFO ""
        log INFO "If you want a fresh install, use: $0 install"
        exit 1
    fi

    log SUCCESS "Official Dokploy installation detected."

    # Show current state
    echo ""
    printf "${CYAN}Current Docker Swarm Services:${NC}\n"
    docker service ls 2>/dev/null | grep -E "dokploy|REPLICAS"
    echo ""

    printf "${CYAN}Current Docker Containers:${NC}\n"
    docker ps --filter "name=dokploy" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null
    echo ""

    printf "${CYAN}Current Docker Volumes:${NC}\n"
    docker volume ls --filter "name=dokploy" 2>/dev/null
    echo ""

    # Confirm migration
    log WARN "This will migrate your official Dokploy installation to Dokploy Enhanced."
    log WARN "The migration will:"
    log WARN "  1. Extract configuration from existing services"
    log WARN "  2. Create a backup of current state"
    log WARN "  3. Stop and remove Docker Swarm services"
    log WARN "  4. Generate docker-compose.yml and .env files"
    log WARN "  5. Start services using docker-compose"
    log WARN ""
    log WARN "Your data (PostgreSQL, Redis, /etc/dokploy) will be PRESERVED."
    echo ""

    if ! confirm "Do you want to proceed with the migration?"; then
        log INFO "Migration cancelled."
        exit 0
    fi

    local data_dir="${DOKPLOY_DATA_DIR:-$DEFAULT_DATA_DIR}"

    # Extract configuration from existing installation
    log INFO "Extracting configuration from existing installation..."

    # Get advertise address
    local advertise_addr
    advertise_addr=$(get_advertise_addr_from_swarm)
    if [[ -z "$advertise_addr" ]]; then
        advertise_addr=$(get_private_ip)
    fi
    log INFO "Advertise address: $advertise_addr"

    # Get PostgreSQL password
    local pg_password
    pg_password=$(get_postgres_password_from_service)
    if [[ -z "$pg_password" ]]; then
        log WARN "Could not extract PostgreSQL password from existing service."
        log WARN "A new password will be generated. You may need to reset the database."
        pg_password=$(generate_password)
    else
        log SUCCESS "PostgreSQL password extracted from existing service."
    fi

    # Get port from existing service
    local port="${DOKPLOY_PORT:-$DEFAULT_PORT}"
    local existing_port
    existing_port=$(docker service inspect dokploy 2>/dev/null | \
        grep -oP '(?<="PublishedPort":)\d+' | head -1)
    if [[ -n "$existing_port" ]]; then
        port="$existing_port"
        log INFO "Using existing port: $port"
    fi

    # Create backup before migration
    log INFO "Creating backup before migration..."
    local backup_dir="/var/backups/dokploy"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$backup_dir/pre_migration_$timestamp"
    mkdir -p "$backup_path"

    # Backup configuration
    if [[ -d "$data_dir" ]]; then
        cp -r "$data_dir" "$backup_path/config" 2>/dev/null || true
    fi

    # Save service configurations
    docker service inspect dokploy > "$backup_path/dokploy-service.json" 2>/dev/null || true
    docker service inspect dokploy-postgres > "$backup_path/dokploy-postgres-service.json" 2>/dev/null || true
    docker service inspect dokploy-redis > "$backup_path/dokploy-redis-service.json" 2>/dev/null || true

    # Save current state
    cat > "$backup_path/migration-info.json" << EOF
{
    "migrated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "from": "official-dokploy",
    "to": "dokploy-enhanced",
    "script_version": "$SCRIPT_VERSION",
    "advertise_addr": "$advertise_addr",
    "port": "$port"
}
EOF

    log SUCCESS "Backup created at: $backup_path"

    # Stop and remove old services
    log INFO "Stopping Docker Swarm services..."

    # Stop dokploy service first (depends on postgres and redis)
    docker service rm dokploy 2>/dev/null || true
    sleep 2

    # Stop postgres and redis
    docker service rm dokploy-postgres 2>/dev/null || true
    docker service rm dokploy-redis 2>/dev/null || true

    # Stop traefik container
    docker rm -f dokploy-traefik 2>/dev/null || true

    log SUCCESS "Old services stopped."

    # Ensure network exists (don't remove it, just make sure it's there)
    log INFO "Ensuring network exists..."
    if ! docker network ls | grep -q "$NETWORK_NAME"; then
        docker network create --driver overlay --attachable "$NETWORK_NAME"
    fi

    # Ensure data directory exists
    mkdir -p "$data_dir"
    chmod 755 "$data_dir"

    # Generate new configuration files
    log INFO "Generating docker-compose configuration..."

    # Override port and password for generate functions
    DOKPLOY_PORT="$port"

    # Migration uses standalone mode by default (can be changed after migration)
    local deploy_mode="${DEPLOY_MODE:-standalone}"
    generate_env_file "$data_dir" "$advertise_addr" "$pg_password" "$deploy_mode"
    generate_docker_compose "$data_dir"
    generate_traefik_config "$data_dir"

    # Start services
    services_up

    # Wait for services to start
    log INFO "Waiting for services to initialize..."
    sleep 10

    # Verify migration
    log INFO "Verifying migration..."
    local success=true

    if ! docker ps | grep -q "dokploy"; then
        log ERROR "Dokploy container is not running!"
        success=false
    fi

    if ! docker ps | grep -q "dokploy-postgres"; then
        log ERROR "PostgreSQL container is not running!"
        success=false
    fi

    if ! docker ps | grep -q "dokploy-redis"; then
        log ERROR "Redis container is not running!"
        success=false
    fi

    if [[ "$success" == "true" ]]; then
        # Save installation info
        cat > "$data_dir/install-info.json" << EOF
{
    "installed_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "migrated_from": "official-dokploy",
    "script_version": "$SCRIPT_VERSION",
    "docker_version": "$(docker --version 2>/dev/null)",
    "advertise_addr": "$advertise_addr",
    "port": "$port",
    "registry": "${DOKPLOY_REGISTRY:-$DEFAULT_REGISTRY}",
    "image": "${DOKPLOY_IMAGE:-$DEFAULT_IMAGE}",
    "version": "${DOKPLOY_VERSION:-$DEFAULT_VERSION}"
}
EOF

        local public_ip
        public_ip="${ADVERTISE_ADDR:-$(get_public_ip)}" || public_ip="$advertise_addr"
        local formatted_addr
        formatted_addr=$(format_ip_for_url "$public_ip")

        echo ""
        printf "${GREEN}============================================${NC}\n"
        printf "${GREEN}  Migration Completed Successfully!         ${NC}\n"
        printf "${GREEN}============================================${NC}\n"
        echo ""
        printf "${CYAN}Access your Dokploy instance at:${NC}\n"
        printf "${YELLOW}  http://${formatted_addr}:${port}${NC}\n"
        echo ""
        printf "${CYAN}Your data has been preserved:${NC}\n"
        printf "  - PostgreSQL data (dokploy-postgres volume)\n"
        printf "  - Redis data (dokploy-redis volume)\n"
        printf "  - Configuration (/etc/dokploy)\n"
        echo ""
        printf "${CYAN}Configuration files:${NC}\n"
        printf "  .env file:           ${YELLOW}${data_dir}/.env${NC}\n"
        printf "  docker-compose.yml:  ${YELLOW}${data_dir}/docker-compose.yml${NC}\n"
        echo ""
        printf "${CYAN}Pre-migration backup:${NC}\n"
        printf "  ${YELLOW}${backup_path}${NC}\n"
        echo ""
        printf "${CYAN}Useful commands:${NC}\n"
        printf "  View status:    ${YELLOW}$0 status${NC}\n"
        printf "  View logs:      ${YELLOW}$0 logs -f${NC}\n"
        printf "  Restart:        ${YELLOW}$0 restart${NC}\n"
        echo ""

        log SUCCESS "Migration completed successfully!"
    else
        log ERROR "Migration verification failed!"
        log ERROR "Check the logs with: $0 logs"
        log INFO "Pre-migration backup is available at: $backup_path"
        log INFO "You may need to restore from backup or troubleshoot manually."
        exit 1
    fi
}

# =============================================================================
# Main Entry Point
# =============================================================================

show_main_menu() {
    # All display output goes to stderr so only the command result goes to stdout
    {
        echo ""
        printf "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}\n"
        printf "${BOLD}${CYAN}║${NC}       ${BOLD}Dokploy Enhanced Installer v${SCRIPT_VERSION}${NC}              ${BOLD}${CYAN}║${NC}\n"
        printf "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}\n"
        echo ""
        printf "${CYAN}What would you like to do?${NC}\n"
        echo ""
        printf "  ${GREEN}1)${NC}  Install       - Fresh installation of Dokploy Enhanced\n"
        printf "  ${GREEN}2)${NC}  Update        - Update to the latest version\n"
        printf "  ${GREEN}3)${NC}  Start         - Start all services\n"
        printf "  ${GREEN}4)${NC}  Stop          - Stop all services\n"
        printf "  ${GREEN}5)${NC}  Restart       - Restart all services\n"
        printf "  ${GREEN}6)${NC}  Status        - Show current status\n"
        printf "  ${GREEN}7)${NC}  Logs          - View service logs\n"
        printf "  ${GREEN}8)${NC}  Backup        - Create a backup\n"
        printf "  ${GREEN}9)${NC}  Migrate       - Migrate from official Dokploy\n"
        printf "  ${YELLOW}10)${NC} Uninstall     - Remove Dokploy Enhanced\n"
        printf "  ${RED}11)${NC} Nuke          - Complete destruction (reset everything)\n"
        printf "  ${BLUE}12)${NC} Help          - Show detailed help\n"
        printf "  ${BLUE}0)${NC}  Exit          - Exit without doing anything\n"
        echo ""
        printf "Enter your choice [0-12]: "
    } >&2

    local choice
    read -r choice < /dev/tty || choice=""

    case "$choice" in
        1|install)    echo "install" ;;
        2|update)     echo "update" ;;
        3|start)      echo "start" ;;
        4|stop)       echo "stop" ;;
        5|restart)    echo "restart" ;;
        6|status)     echo "status" ;;
        7|logs)       echo "logs" ;;
        8|backup)     echo "backup" ;;
        9|migrate)    echo "migrate" ;;
        10|uninstall) echo "uninstall" ;;
        11|nuke)      echo "nuke" ;;
        12|help)      echo "help" ;;
        0|exit|q)     echo "exit" ;;
        *)
            log ERROR "Invalid choice: $choice"
            echo "invalid"
            ;;
    esac
}

main() {
    local command="${1:-}"

    # If no command provided and not in FORCE mode, show interactive menu
    if [[ -z "$command" && "${FORCE:-false}" != "true" ]]; then
        command=$(show_main_menu)
        if [[ "$command" == "exit" ]]; then
            log INFO "Exiting. Goodbye!"
            exit 0
        elif [[ "$command" == "invalid" ]]; then
            exit 1
        fi
    fi

    # Default to install if still empty (FORCE mode with no args)
    command="${command:-install}"

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
        migrate)
            cmd_migrate
            ;;
        uninstall|remove)
            cmd_uninstall
            ;;
        nuke)
            cmd_nuke
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
