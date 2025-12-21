#!/bin/bash
set -euo pipefail

# =============================
# Enhanced Multi-VM Manager v7.0 (Direct Terminal Boot)
# Features: 35+ Latest OS, Direct console access, VM editing
# No SSH waiting - Boot directly to terminal!
# =============================

VERSION="7.0"
KVM_AVAILABLE=true
QEMU_CMD=()

# Color codes
readonly C_RESET='\033[0m'
readonly C_RED='\033[1;31m'
readonly C_GREEN='\033[1;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_BLUE='\033[1;34m'
readonly C_MAGENTA='\033[1;35m'
readonly C_CYAN='\033[1;36m'
readonly C_WHITE='\033[1;37m'

# Environment detection
GITHUB_CODESPACES=false
IDX_ENV=false
[[ "${CODESPACES:-}" == "true" ]] && GITHUB_CODESPACES=true
[[ -f /etc/os-release ]] && grep -q "IDX GNU/Linux" /etc/os-release 2>/dev/null && IDX_ENV=true

# System resource detection
TOTAL_CPUS=$(nproc 2>/dev/null || echo 2)
TOTAL_MEM=$(awk '/MemTotal/{printf "%.0f", $2/1024}' /proc/meminfo 2>/dev/null || echo 2048)

# Optimized defaults based on environment
if [[ "$GITHUB_CODESPACES" == "true" ]]; then
    DEFAULT_MEMORY=1024
    DEFAULT_CPUS=2
    DEFAULT_DISK="10G"
    CACHE_MODE="unsafe"
elif [[ "$IDX_ENV" == "true" ]]; then
    DEFAULT_MEMORY=$((TOTAL_MEM > 8192 ? 4096 : TOTAL_MEM / 4))
    DEFAULT_CPUS=$((TOTAL_CPUS > 2 ? 2 : 1))
    DEFAULT_DISK="15G"
    CACHE_MODE="unsafe"
else
    DEFAULT_MEMORY=$((TOTAL_MEM / 3))
    DEFAULT_CPUS=$((TOTAL_CPUS > 1 ? TOTAL_CPUS - 1 : 1))
    DEFAULT_DISK="30G"
    CACHE_MODE="writeback"
fi

# Ensure reasonable minimums
[[ $DEFAULT_MEMORY -lt 512 ]] && DEFAULT_MEMORY=512
[[ $DEFAULT_CPUS -lt 1 ]] && DEFAULT_CPUS=1

# Initialize paths
VM_DIR="${VM_DIR:-$HOME/vms}"
BASE_IMG_DIR="$VM_DIR/.base-images"
DOWNLOAD_CACHE="$VM_DIR/.cache"
BACKUP_DIR="$VM_DIR/.backups"
SHARED_DIR="$VM_DIR/.shared"

# Ensure directories exist
mkdir -p "$VM_DIR" "$BASE_IMG_DIR" "$DOWNLOAD_CACHE" "$BACKUP_DIR" "$SHARED_DIR" 2>/dev/null || true

# ============================================
# Utility Functions
# ============================================

print_status() {
    local type="$1"
    local msg="$2"
    case "$type" in
        INFO)    printf "${C_BLUE}[INFO]${C_RESET} %s\n" "$msg" ;;
        WARN)    printf "${C_YELLOW}[WARN]${C_RESET} %s\n" "$msg" ;;
        ERROR)   printf "${C_RED}[ERROR]${C_RESET} %s\n" "$msg" ;;
        SUCCESS) printf "${C_GREEN}[SUCCESS]${C_RESET} %s\n" "$msg" ;;
        INPUT)   printf "${C_CYAN}[INPUT]${C_RESET} %s" "$msg" ;;
        DEBUG)   printf "${C_MAGENTA}[DEBUG]${C_RESET} %s\n" "$msg" ;;
        *)       printf "[%s] %s\n" "$type" "$msg" ;;
    esac
}

display_header() {
    clear
    cat << "EOF"
========================================================================
     __      ____  __   __  __         _____ ___
     \ \    / /  \/  | |  \/  |       |___  / _ \
      \ \  / /| |\/| | | |\/| |  _   _   / / | | |
       \ \/ / | |  | | | |  | | | | | | / /| |_| |
        \__/  |_|  |_| |_|  |_| |_| |_|/_(_)\___/

            DIRECT TERMINAL BOOT - NO SSH NEEDED!
========================================================================
EOF
    printf "              VM Manager v%s [%s Mode]\n" "$VERSION" \
        "$([[ "$GITHUB_CODESPACES" == "true" ]] && echo "GitHub" || [[ "$IDX_ENV" == "true" ]] && echo "IDX" || echo "Standard")"
    printf "         CPUs: %s | RAM: %sMB | Disk: %s\n" "$DEFAULT_CPUS" "$DEFAULT_MEMORY" "$DEFAULT_DISK"
    echo "========================================================================"
    echo
}

validate_input() {
    local type="$1"
    local value="$2"
    case "$type" in
        number)
            [[ "$value" =~ ^[0-9]+$ ]] && [[ "$value" -gt 0 ]] && return 0
            print_status "ERROR" "Must be a positive number"
            return 1
            ;;
        size)
            [[ "$value" =~ ^[0-9]+[GgMm]$ ]] && return 0
            print_status "ERROR" "Must be size with unit (e.g., 10G, 512M)"
            return 1
            ;;
        name)
            [[ "$value" =~ ^[a-zA-Z0-9_-]+$ ]] && [[ ${#value} -le 64 ]] && return 0
            print_status "ERROR" "Invalid name (use letters, numbers, hyphens, underscores)"
            return 1
            ;;
        username)
            [[ "$value" =~ ^[a-z][a-z0-9_-]*$ ]] && [[ ${#value} -le 32 ]] && return 0
            print_status "ERROR" "Invalid username"
            return 1
            ;;
        password)
            [[ ${#value} -ge 1 ]] && return 0
            print_status "ERROR" "Password cannot be empty"
            return 1
            ;;
    esac
    return 1
}

check_kvm() {
    if [[ -e /dev/kvm ]] && [[ -r /dev/kvm ]] && [[ -w /dev/kvm ]]; then
        KVM_AVAILABLE=true
        print_status "SUCCESS" "KVM acceleration available"
    else
        KVM_AVAILABLE=false
        print_status "WARN" "KVM not available - VMs will run slower"
    fi
}

check_dependencies() {
    local missing=()
    local deps=(qemu-system-x86_64 wget qemu-img)

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -ne 0 ]]; then
        print_status "ERROR" "Missing dependencies: ${missing[*]}"
        echo "Install with: sudo apt install -y qemu-system-x86 qemu-utils wget cloud-utils"
        exit 1
    fi
    print_status "SUCCESS" "All dependencies found"

    if [[ "$GITHUB_CODESPACES" == "true" ]]; then
        print_status "INFO" "GitHub Codespaces optimizations enabled"
    elif [[ "$IDX_ENV" == "true" ]]; then
        print_status "INFO" "IDX optimizations enabled"
    fi
}

get_vm_list() {
    local vms=()
    if [[ -d "$VM_DIR" ]]; then
        for f in "$VM_DIR"/*.conf; do
            [[ -f "$f" ]] && vms+=("$(basename "${f%.conf}")")
        done
    fi
    printf '%s\n' "${vms[@]}" 2>/dev/null | sort
}

load_vm_config() {
    local config_file="$VM_DIR/$1.conf"
    if [[ ! -f "$config_file" ]]; then
        print_status "ERROR" "VM '$1' not found"
        return 1
    fi

    unset VM_NAME OS_TYPE OS_VERSION CODENAME IMG_URL HOSTNAME USERNAME PASSWORD
    unset DISK_SIZE MEMORY CPUS SSH_PORT PORT_FORWARDS IMG_FILE SEED_FILE CREATED
    unset SHARED_FOLDERS NETWORK_MODE

    source "$config_file"
    return 0
}

save_vm_config() {
    cat > "$VM_DIR/$VM_NAME.conf" << EOF
VM_NAME="$VM_NAME"
OS_TYPE="$OS_TYPE"
OS_VERSION="$OS_VERSION"
CODENAME="$CODENAME"
IMG_URL="$IMG_URL"
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
DISK_SIZE="$DISK_SIZE"
MEMORY="$MEMORY"
CPUS="$CPUS"
SSH_PORT="${SSH_PORT:-2222}"
PORT_FORWARDS="${PORT_FORWARDS:-}"
IMG_FILE="$IMG_FILE"
SEED_FILE="$SEED_FILE"
CREATED="$CREATED"
SHARED_FOLDERS="${SHARED_FOLDERS:-}"
NETWORK_MODE="${NETWORK_MODE:-user}"
EOF
    chmod 600 "$VM_DIR/$VM_NAME.conf"
}

cleanup() {
    rm -f user-data meta-data network-config 2>/dev/null || true
}
trap cleanup EXIT

# ============================================
# Download Functions
# ============================================

decompress_if_needed() {
    local file="$1"
    local output="$2"

    case "$file" in
        *.xz)
            print_status "INFO" "Decompressing XZ archive..."
            if command -v xz &>/dev/null; then
                xz -dkf "$file" 2>/dev/null && mv "${file%.xz}" "$output"
            elif command -v unxz &>/dev/null; then
                unxz -k "$file" 2>/dev/null && mv "${file%.xz}" "$output"
            else
                print_status "ERROR" "xz tool not found"
                return 1
            fi
            rm -f "$file"
            ;;
        *.gz)
            print_status "INFO" "Decompressing GZ archive..."
            gunzip -c "$file" > "$output" && rm -f "$file"
            ;;
        *.bz2)
            print_status "INFO" "Decompressing BZ2 archive..."
            bunzip2 -c "$file" > "$output" && rm -f "$file"
            ;;
        *)
            [[ "$file" != "$output" ]] && mv "$file" "$output"
            ;;
    esac
    return 0
}

download_image() {
    local url="$1"
    local output="$2"
    local tmp_file="${output}.tmp"

    print_status "INFO" "Downloading: $(basename "$url")"

    case "$url" in
        *.xz|*.gz|*.bz2)
            tmp_file="${output}.${url##*.}"
            ;;
    esac

    if command -v curl &>/dev/null; then
        if ! curl -fL --progress-bar --retry 3 --retry-delay 5 -C - -o "$tmp_file" "$url"; then
            rm -f "$tmp_file"
            print_status "ERROR" "Download failed"
            return 1
        fi
    else
        if ! wget --progress=bar:force:noscroll --timeout=60 --tries=3 -c -O "$tmp_file" "$url" 2>&1; then
            rm -f "$tmp_file"
            print_status "ERROR" "Download failed"
            return 1
        fi
    fi

    decompress_if_needed "$tmp_file" "$output" || return 1
    print_status "SUCCESS" "Download completed"
    return 0
}

detect_image_format() {
    local img="$1"
    local format
    format=$(qemu-img info "$img" 2>/dev/null | awk '/file format:/{print $3}')
    echo "${format:-qcow2}"
}

# ============================================
# Password Hash Generation
# ============================================

generate_password_hash() {
    local password="$1"
    local hash=""

    if command -v openssl &>/dev/null; then
        local salt
        salt=$(openssl rand -base64 12 2>/dev/null | tr -dc 'a-zA-Z0-9' | head -c 16)
        hash=$(openssl passwd -6 -salt "$salt" "$password" 2>/dev/null)
        if [[ -n "$hash" ]] && [[ "$hash" == "\$6\$"* ]]; then
            echo "$hash"
            return 0
        fi
    fi

    if command -v mkpasswd &>/dev/null; then
        hash=$(mkpasswd -m sha-512 "$password" 2>/dev/null)
        if [[ -n "$hash" ]] && [[ "$hash" == "\$6\$"* ]]; then
            echo "$hash"
            return 0
        fi
    fi

    if command -v python3 &>/dev/null; then
        hash=$(python3 -c "
import crypt
import secrets
salt = crypt.mksalt(crypt.METHOD_SHA512)
print(crypt.crypt('$password', salt))
" 2>/dev/null)
        if [[ -n "$hash" ]] && [[ "$hash" == "\$6\$"* ]]; then
            echo "$hash"
            return 0
        fi
    fi

    echo ""
}

create_cloud_init_iso() {
    local user_data="$1"
    local meta_data="$2"
    local output="$3"

    if command -v cloud-localds &>/dev/null; then
        if cloud-localds "$output" "$user_data" "$meta_data" 2>/dev/null; then
            return 0
        fi
    fi

    local tools=(genisoimage mkisofs xorriso)
    for tool in "${tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            case "$tool" in
                genisoimage|mkisofs)
                    "$tool" -output "$output" -volid cidata -joliet -rock "$user_data" "$meta_data" 2>/dev/null && return 0
                    ;;
                xorriso)
                    xorriso -as mkisofs -o "$output" -V cidata -J -r "$user_data" "$meta_data" 2>/dev/null && return 0
                    ;;
            esac
        fi
    done

    print_status "ERROR" "No ISO creation tool available"
    return 1
}

# ============================================
# VM Image Setup
# ============================================

setup_vm_image() {
    print_status "INFO" "Setting up VM image..."

    local base_img="$BASE_IMG_DIR/${OS_TYPE}-${CODENAME}.img"

    if [[ ! -f "$base_img" ]]; then
        download_image "$IMG_URL" "$base_img" || return 1
    else
        print_status "INFO" "Using cached base image"
    fi

    local img_format
    img_format=$(detect_image_format "$base_img")

    rm -f "$IMG_FILE" 2>/dev/null

    if qemu-img create -f qcow2 -F "$img_format" -b "$base_img" "$IMG_FILE" "$DISK_SIZE" 2>/dev/null; then
        print_status "SUCCESS" "Created overlay disk"
    else
        print_status "INFO" "Creating full copy..."
        cp "$base_img" "$IMG_FILE"
        if [[ "$img_format" != "qcow2" ]]; then
            qemu-img convert -f "$img_format" -O qcow2 "$IMG_FILE" "${IMG_FILE}.tmp" 2>/dev/null
            mv "${IMG_FILE}.tmp" "$IMG_FILE"
        fi
        qemu-img resize "$IMG_FILE" "$DISK_SIZE" 2>/dev/null || true
    fi

    local password_hash
    password_hash=$(generate_password_hash "$PASSWORD")

    # Detect appropriate shell based on OS type
    local SHELL_PATH="/bin/bash"
    [[ "$OS_TYPE" == "alpine" ]] && SHELL_PATH="/bin/ash"

    cat > user-data << EOF
#cloud-config
hostname: $HOSTNAME
manage_etc_hosts: true
fqdn: ${HOSTNAME}.local

users:
  - name: $USERNAME
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: [sudo, adm, wheel, users]
    shell: $SHELL_PATH
    lock_passwd: false
EOF

    if [[ -n "$password_hash" ]]; then
        cat >> user-data << EOF
    hashed_passwd: '$password_hash'
EOF
    fi

    cat >> user-data << EOF

chpasswd:
  expire: false
  list:
    - root:$PASSWORD
    - $USERNAME:$PASSWORD

ssh_pwauth: true
disable_root: false

write_files:
  - path: /etc/ssh/sshd_config.d/99-custom.conf
    content: |
      PasswordAuthentication yes
      PermitRootLogin yes
      UsePAM yes

runcmd:
  - echo "$USERNAME:$PASSWORD" | chpasswd
  - echo "root:$PASSWORD" | chpasswd
  - sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
  - sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
  - systemctl restart sshd || systemctl restart ssh || service ssh restart || true
  - systemctl disable cloud-init || true

final_message: "VM Ready! User: $USERNAME | Password: $PASSWORD"
EOF

    cat > meta-data << EOF
instance-id: iid-${VM_NAME}-$(date +%s)
local-hostname: $HOSTNAME
EOF

    if ! create_cloud_init_iso "user-data" "meta-data" "$SEED_FILE"; then
        return 1
    fi

    cleanup
    print_status "SUCCESS" "VM image ready"
    return 0
}

# ============================================
# QEMU Command Builders - DIRECT CONSOLE
# ============================================

build_qemu_console() {
    local name="$1"
    QEMU_CMD=(qemu-system-x86_64)

    # Machine type with KVM acceleration
    if $KVM_AVAILABLE; then
        QEMU_CMD+=(-machine type=q35,accel=kvm)
        QEMU_CMD+=(-enable-kvm)
        QEMU_CMD+=(-cpu host)
    else
        QEMU_CMD+=(-machine type=q35,accel=tcg)
        QEMU_CMD+=(-cpu qemu64)
    fi

    QEMU_CMD+=(-name "$name")
    QEMU_CMD+=(-m "$MEMORY")
    QEMU_CMD+=(-smp "$CPUS",cores="$CPUS",threads=1)

    # Main disk with optimized caching
    QEMU_CMD+=(-drive "file=$IMG_FILE,format=qcow2,if=virtio,cache=$CACHE_MODE,discard=unmap")

    # Cloud-init seed ISO
    if [[ -f "$SEED_FILE" ]]; then
        QEMU_CMD+=(-drive "file=$SEED_FILE,format=raw,if=virtio,readonly=on")
    fi

    # Boot order
    QEMU_CMD+=(-boot order=c)

    # Network - simple user mode (no SSH needed!)
    QEMU_CMD+=(-device virtio-net-pci,netdev=net0)
    QEMU_CMD+=(-netdev user,id=net0)

    # Performance devices
    QEMU_CMD+=(-device virtio-balloon-pci)
    QEMU_CMD+=(-object rng-random,filename=/dev/urandom,id=rng0)
    QEMU_CMD+=(-device virtio-rng-pci,rng=rng0)

    # DIRECT CONSOLE - No display, use current terminal!
    QEMU_CMD+=(-nographic)

    # Shared folders if specified
    if [[ -n "${SHARED_FOLDERS:-}" ]]; then
        IFS=',' read -ra folders <<< "$SHARED_FOLDERS"
        for folder in "${folders[@]}"; do
            if [[ "$folder" =~ ^(.+):(.+)$ ]]; then
                local host_path="${BASH_REMATCH[1]}"
                local mount_tag="${BASH_REMATCH[2]}"
                if [[ -d "$host_path" ]]; then
                    QEMU_CMD+=(-virtfs "local,path=$host_path,mount_tag=$mount_tag,security_model=passthrough,id=fs-$mount_tag")
                fi
            fi
        done
    fi
}

# ============================================
# VM Management Functions
# ============================================

is_vm_running() {
    pgrep -f "qemu-system-x86_64.*-name $1( |\$)" &>/dev/null
}

get_vm_pid() {
    pgrep -f "qemu-system-x86_64.*-name $1( |\$)" 2>/dev/null | head -1
}

start_vm() {
    local vm_name="$1"

    if ! load_vm_config "$vm_name"; then
        return 1
    fi

    if is_vm_running "$vm_name"; then
        print_status "WARN" "VM '$vm_name' is already running"
        return 1
    fi

    if [[ ! -f "$IMG_FILE" ]]; then
        print_status "ERROR" "Image file not found: $IMG_FILE"
        return 1
    fi

    echo
    print_status "INFO" "Starting VM: $vm_name (Direct Terminal Boot)"
    echo "════════════════════════════════════════════════════════"
    echo "  OS:       $OS_TYPE $OS_VERSION"
    echo "  User:     $USERNAME"
    echo "  Password: $PASSWORD"
    echo "  RAM:      ${MEMORY}MB | CPUs: $CPUS"
    echo "════════════════════════════════════════════════════════"
    print_status "INFO" "VM will boot directly in this terminal"
    print_status "INFO" "Press Ctrl+A then X to exit console"
    echo
    read -p "Press Enter to start..."

    build_qemu_console "$vm_name"

    # Execute QEMU in foreground with direct console
    "${QEMU_CMD[@]}" || {
        print_status "ERROR" "VM failed to start"
        return 1
    }

    print_status "INFO" "VM exited"
}

stop_vm() {
    local vm_name="$1"

    if ! load_vm_config "$vm_name"; then
        return 1
    fi

    if ! is_vm_running "$vm_name"; then
        print_status "INFO" "VM '$vm_name' is not running"
        return 0
    fi

    local pid
    pid=$(get_vm_pid "$vm_name")

    print_status "INFO" "Stopping VM '$vm_name'..."
    kill -TERM "$pid" 2>/dev/null || true

    local i=0
    while is_vm_running "$vm_name" && [[ $i -lt 10 ]]; do
        sleep 1
        ((i++))
        printf "."
    done
    echo

    if is_vm_running "$vm_name"; then
        kill -9 "$pid" 2>/dev/null || true
    fi

    print_status "SUCCESS" "VM '$vm_name' stopped"
}

delete_vm() {
    local vm_name="$1"

    if ! load_vm_config "$vm_name"; then
        return 1
    fi

    if is_vm_running "$vm_name"; then
        print_status "ERROR" "Please stop the VM first"
        return 1
    fi

    print_status "WARN" "This will permanently delete VM '$vm_name'"
    read -p "Type 'DELETE' to confirm: " confirm

    if [[ "$confirm" == "DELETE" ]]; then
        rm -f "$IMG_FILE" "$SEED_FILE" "$VM_DIR/$vm_name.conf"
        print_status "SUCCESS" "VM '$vm_name' deleted"
    else
        print_status "INFO" "Deletion cancelled"
    fi
}

show_vm_info() {
    local vm_name="$1"

    if ! load_vm_config "$vm_name"; then
        return 1
    fi

    local status="Stopped"
    local color="$C_RED"
    if is_vm_running "$vm_name"; then
        status="Running"
        color="$C_GREEN"
    fi

    echo
    printf "VM: ${C_WHITE}%s${C_RESET} [${color}%s${C_RESET}]\n" "$VM_NAME" "$status"
    echo "────────────────────────────────────────────────────"
    printf "  OS:       %s %s (%s)\n" "$OS_TYPE" "$OS_VERSION" "$CODENAME"
    printf "  Hostname: %s\n" "$HOSTNAME"
    printf "  User:     %s\n" "$USERNAME"
    printf "  Password: %s\n" "$PASSWORD"
    printf "  RAM:      %sMB\n" "$MEMORY"
    printf "  CPUs:     %s\n" "$CPUS"
    printf "  Disk:     %s\n" "$DISK_SIZE"
    printf "  Created:  %s\n" "$CREATED"
    echo "────────────────────────────────────────────────────"

    if [[ -f "$IMG_FILE" ]]; then
        echo "  Disk Info:"
        qemu-img info "$IMG_FILE" 2>/dev/null | grep -E "virtual size|disk size" | sed 's/^/    /' || true
    fi

    if is_vm_running "$vm_name"; then
        local pid
        pid=$(get_vm_pid "$vm_name")
        echo "  Process:"
        printf "    PID: %s\n" "$pid"
        if [[ -f "/proc/$pid/status" ]]; then
            local mem_kb
            mem_kb=$(grep VmRSS /proc/$pid/status 2>/dev/null | awk '{print $2}' || echo "0")
            printf "    Memory: %d MB\n" "$((mem_kb / 1024))"
        fi
    fi
    echo
}

# ============================================
# VM Edit Function
# ============================================

edit_vm() {
    local vm_name="$1"

    if ! load_vm_config "$vm_name"; then
        return 1
    fi

    if is_vm_running "$vm_name"; then
        print_status "WARN" "VM is running. Stop it to modify disk/credentials."
    fi

    while true; do
        echo
        print_status "INFO" "Edit VM: $vm_name"
        echo "════════════════════════════════════════════════════════"
        echo "  1) Memory (Current: ${MEMORY}MB)"
        echo "  2) CPUs (Current: ${CPUS})"
        echo "  3) Disk Size (Current: ${DISK_SIZE}) [VM must be stopped]"
        echo "  4) Username (Current: ${USERNAME}) [VM must be stopped]"
        echo "  5) Password (Current: ${PASSWORD}) [VM must be stopped]"
        echo "  6) Hostname (Current: ${HOSTNAME}) [VM must be stopped]"
        echo "  7) Shared Folders (Current: ${SHARED_FOLDERS:-none})"
        echo "  0) Save and Exit"
        echo "════════════════════════════════════════════════════════"

        read -p "$(print_status "INPUT" "Select option: ")" choice

        case "$choice" in
            1)
                read -p "$(print_status "INPUT" "New memory (MB) [$MEMORY]: ")" new_mem
                if [[ -n "$new_mem" ]] && validate_input "number" "$new_mem"; then
                    MEMORY="$new_mem"
                    print_status "SUCCESS" "Memory updated"
                fi
                ;;
            2)
                read -p "$(print_status "INPUT" "New CPU count [$CPUS]: ")" new_cpu
                if [[ -n "$new_cpu" ]] && validate_input "number" "$new_cpu"; then
                    CPUS="$new_cpu"
                    print_status "SUCCESS" "CPUs updated"
                fi
                ;;
            3)
                if is_vm_running "$vm_name"; then
                    print_status "ERROR" "Stop VM before resizing disk"
                else
                    read -p "$(print_status "INPUT" "New disk size (e.g., 50G) [$DISK_SIZE]: ")" new_size
                    if [[ -n "$new_size" ]] && validate_input "size" "$new_size"; then
                        if qemu-img resize "$IMG_FILE" "$new_size" 2>/dev/null; then
                            DISK_SIZE="$new_size"
                            print_status "SUCCESS" "Disk resized (run resize2fs in VM)"
                        else
                            print_status "ERROR" "Failed to resize disk"
                        fi
                    fi
                fi
                ;;
            4)
                if is_vm_running "$vm_name"; then
                    print_status "ERROR" "Stop VM before changing username"
                else
                    read -p "$(print_status "INPUT" "New username [$USERNAME]: ")" new_user
                    if [[ -n "$new_user" ]] && validate_input "username" "$new_user"; then
                        USERNAME="$new_user"
                        setup_vm_image
                        print_status "SUCCESS" "Username updated (cloud-init regenerated)"
                    fi
                fi
                ;;
            5)
                if is_vm_running "$vm_name"; then
                    print_status "ERROR" "Stop VM before changing password"
                else
                    read -s -p "$(print_status "INPUT" "New password: ")" new_pass
                    echo
                    if [[ -n "$new_pass" ]]; then
                        PASSWORD="$new_pass"
                        setup_vm_image
                        print_status "SUCCESS" "Password updated (cloud-init regenerated)"
                    fi
                fi
                ;;
            6)
                if is_vm_running "$vm_name"; then
                    print_status "ERROR" "Stop VM before changing hostname"
                else
                    read -p "$(print_status "INPUT" "New hostname [$HOSTNAME]: ")" new_host
                    if [[ -n "$new_host" ]]; then
                        HOSTNAME="$new_host"
                        setup_vm_image
                        print_status "SUCCESS" "Hostname updated (cloud-init regenerated)"
                    fi
                fi
                ;;
            7)
                read -p "$(print_status "INPUT" "Shared folders (host_path:mount_tag) [$SHARED_FOLDERS]: ")" new_shared
                SHARED_FOLDERS="$new_shared"
                print_status "SUCCESS" "Shared folders updated"
                print_status "INFO" "Mount in VM: mount -t 9p -o trans=virtio mount_tag /mnt"
                ;;
            0)
                save_vm_config
                print_status "SUCCESS" "Configuration saved"
                return 0
                ;;
            *)
                print_status "ERROR" "Invalid option"
                ;;
        esac
    done
}

# ============================================
# Quick Create VM
# ============================================

quick_create_vm() {
    local os_choice="$1"
    local vm_name="${2:-}"

    local os_data="${OS_OPTIONS[$os_choice]:-}"
    if [[ -z "$os_data" ]]; then
        print_status "ERROR" "Unknown OS: $os_choice"
        echo "Available options:"
        printf '%s\n' "${!OS_OPTIONS[@]}" | sort | sed 's/^/  /'
        return 1
    fi

    IFS='|' read -r OS_TYPE OS_VERSION CODENAME IMG_URL DEFAULT_HOSTNAME DEFAULT_USERNAME DEFAULT_PASSWORD <<< "$os_data"

    VM_NAME="${vm_name:-$DEFAULT_HOSTNAME}"
    HOSTNAME="$VM_NAME"
    USERNAME="$DEFAULT_USERNAME"
    PASSWORD="$DEFAULT_PASSWORD"
    DISK_SIZE="$DEFAULT_DISK"
    MEMORY="$DEFAULT_MEMORY"
    CPUS="$DEFAULT_CPUS"
    SSH_PORT=2222
    PORT_FORWARDS=""
    SHARED_FOLDERS=""
    NETWORK_MODE="user"
    IMG_FILE="$VM_DIR/$VM_NAME.qcow2"
    SEED_FILE="$VM_DIR/$VM_NAME-seed.iso"
    CREATED="$(date '+%Y-%m-%d %H:%M:%S')"

    if [[ -f "$VM_DIR/$VM_NAME.conf" ]]; then
        print_status "ERROR" "VM '$VM_NAME' already exists"
        return 1
    fi

    print_status "INFO" "Quick creating: $VM_NAME ($OS_TYPE $OS_VERSION)"

    if ! setup_vm_image; then
        return 1
    fi

    save_vm_config

    echo
    print_status "SUCCESS" "VM '$VM_NAME' created!"
    echo "  Start:    ./vm.sh start $VM_NAME"
    echo "  User:     $USERNAME"
    echo "  Password: $PASSWORD"
    echo
    print_status "INFO" "VM will boot directly in your terminal (no SSH needed!)"
}

# ============================================
# Interactive Create VM
# ============================================

create_new_vm() {
    print_status "INFO" "Select Operating System:"
    echo

    local os_keys=()
    local i=1
    while IFS= read -r os; do
        os_keys+=("$os")
        printf "  ${C_CYAN}%2d)${C_RESET} %s\n" "$i" "$os"
        ((i++))
    done < <(printf '%s\n' "${!OS_OPTIONS[@]}" | sort)
    echo

    local os_count=${#os_keys[@]}
    local choice
    while true; do
        read -p "$(print_status "INPUT" "Select OS (1-$os_count): ")" choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "$os_count" ]]; then
            break
        fi
        print_status "ERROR" "Invalid selection"
    done

    local os="${os_keys[$((choice-1))]}"
    IFS='|' read -r OS_TYPE OS_VERSION CODENAME IMG_URL DEFAULT_HOSTNAME DEFAULT_USERNAME DEFAULT_PASSWORD <<< "${OS_OPTIONS[$os]}"
    print_status "SUCCESS" "Selected: $os"
    echo

    while true; do
        read -p "$(print_status "INPUT" "VM name [$DEFAULT_HOSTNAME]: ")" VM_NAME
        VM_NAME="${VM_NAME:-$DEFAULT_HOSTNAME}"
        if validate_input "name" "$VM_NAME"; then
            if [[ ! -f "$VM_DIR/$VM_NAME.conf" ]]; then
                break
            fi
            print_status "ERROR" "VM '$VM_NAME' already exists"
        fi
    done

    read -p "$(print_status "INPUT" "Hostname [$VM_NAME]: ")" HOSTNAME
    HOSTNAME="${HOSTNAME:-$VM_NAME}"

    read -p "$(print_status "INPUT" "Username [$DEFAULT_USERNAME]: ")" USERNAME
    USERNAME="${USERNAME:-$DEFAULT_USERNAME}"

    read -s -p "$(print_status "INPUT" "Password [$DEFAULT_PASSWORD]: ")" PASSWORD
    echo
    PASSWORD="${PASSWORD:-$DEFAULT_PASSWORD}"

    read -p "$(print_status "INPUT" "Disk size [$DEFAULT_DISK]: ")" DISK_SIZE
    DISK_SIZE="${DISK_SIZE:-$DEFAULT_DISK}"

    read -p "$(print_status "INPUT" "RAM in MB [$DEFAULT_MEMORY]: ")" MEMORY
    MEMORY="${MEMORY:-$DEFAULT_MEMORY}"

    read -p "$(print_status "INPUT" "CPU cores [$DEFAULT_CPUS]: ")" CPUS
    CPUS="${CPUS:-$DEFAULT_CPUS}"

    SSH_PORT=2222
    PORT_FORWARDS=""
    SHARED_FOLDERS=""
    NETWORK_MODE="user"
    IMG_FILE="$VM_DIR/$VM_NAME.qcow2"
    SEED_FILE="$VM_DIR/$VM_NAME-seed.iso"
    CREATED="$(date '+%Y-%m-%d %H:%M:%S')"

    echo
    print_status "INFO" "Summary:"
    echo "  Name: $VM_NAME | OS: $OS_TYPE $OS_VERSION"
    echo "  RAM: ${MEMORY}MB | CPUs: $CPUS | Disk: $DISK_SIZE"
    echo "  User: $USERNAME"
    echo

    read -p "$(print_status "INPUT" "Create VM? [Y/n]: ")" confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_status "INFO" "Cancelled"
        return 1
    fi

    if ! setup_vm_image; then
        return 1
    fi

    save_vm_config

    echo
    print_status "SUCCESS" "VM '$VM_NAME' created!"
    print_status "INFO" "Start with: ./vm.sh start $VM_NAME"
}

# ============================================
# CLI Functions
# ============================================

cli_usage() {
    cat << EOF
Usage: $0 [command] [args]

Commands:
  list                    List all VMs
  create                  Interactive VM creation
  quick <os> [name]       Quick create VM
  start <vm>              Start VM (direct terminal boot)
  stop <vm>               Stop VM
  delete <vm>             Delete VM
  info <vm>               Show VM info
  edit <vm>               Edit VM configuration
  system                  System information
  oses                    List available OSes
  help                    Show this help

Examples:
  $0 quick "Ubuntu 24.04 LTS (Noble)" myserver
  $0 start myserver
  $0 edit myserver
  $0 info myserver

EOF
}

list_available_oses() {
    echo
    print_status "INFO" "Available Operating Systems (${#OS_OPTIONS[@]} total):"
    echo
    printf '%s\n' "${!OS_OPTIONS[@]}" | sort | while read -r os; do
        printf "  - %s\n" "$os"
    done
    echo
}

show_system_info() {
    echo
    print_status "INFO" "System Information"
    echo "════════════════════════════════════════════════════════"
    printf "  Hostname:    %s\n" "$(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo 'unknown')"
    printf "  Kernel:      %s\n" "$(uname -r)"
    printf "  Total CPUs:  %s\n" "$TOTAL_CPUS"
    printf "  Total RAM:   %sMB\n" "$TOTAL_MEM"
    printf "  Free RAM:    %s\n" "$(free -h 2>/dev/null | awk '/Mem:/{print $4}' || echo 'N/A')"
    printf "  KVM:         %s\n" "$KVM_AVAILABLE"
    printf "  QEMU:        %s\n" "$(qemu-system-x86_64 --version 2>/dev/null | head -1 | awk '{print $4}' || echo 'N/A')"
    printf "  VM Dir:      %s\n" "$VM_DIR"
    [[ "$GITHUB_CODESPACES" == "true" ]] && printf "  Environment: GitHub Codespaces\n"
    [[ "$IDX_ENV" == "true" ]] && printf "  Environment: IDX\n"
    echo "════════════════════════════════════════════════════════"
    echo
}

# ============================================
# Main Menu
# ============================================

main_menu() {
    while true; do
        display_header

        local vms=()
        while IFS= read -r vm; do
            [[ -n "$vm" ]] && vms+=("$vm")
        done < <(get_vm_list)

        local count=${#vms[@]}

        if [[ $count -gt 0 ]]; then
            print_status "INFO" "Virtual Machines ($count):"
            for i in "${!vms[@]}"; do
                local st="○" col="$C_RED"
                if is_vm_running "${vms[$i]}"; then
                    st="●"
                    col="$C_GREEN"
                fi
                printf "  ${C_CYAN}%2d)${C_RESET} %-30s ${col}%s${C_RESET}\n" "$((i+1))" "${vms[$i]}" "$st"
            done
            echo
        fi

        echo "╔═════════════════════════════════════════════════════════╗"
        echo "║              Main Menu v7.0 - Direct Boot               ║"
        echo "╠═════════════════════════════════════════════════════════╣"
        echo "║  1) Create VM          2) Start VM (Terminal)           ║"
        echo "║  3) Stop VM            4) VM Info                       ║"
        echo "║  5) Edit VM            6) Delete VM                     ║"
        echo "║  s) System Info        o) List OSes                     ║"
        echo "║  0) Exit                                                ║"
        echo "╚═════════════════════════════════════════════════════════╝"

        read -p "$(print_status "INPUT" "Choice: ")" choice

        case "$choice" in
            1)
                create_new_vm
                ;;
            2)
                if [[ $count -gt 0 ]]; then
                    read -p "$(print_status "INPUT" "VM number (1-$count): ")" num
                    if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 ]] && [[ "$num" -le "$count" ]]; then
                        start_vm "${vms[$((num-1))]}"
                    fi
                else
                    print_status "ERROR" "No VMs available"
                fi
                ;;
            3)
                if [[ $count -gt 0 ]]; then
                    read -p "$(print_status "INPUT" "VM number (1-$count): ")" num
                    if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 ]] && [[ "$num" -le "$count" ]]; then
                        stop_vm "${vms[$((num-1))]}"
                    fi
                else
                    print_status "ERROR" "No VMs available"
                fi
                ;;
            4)
                if [[ $count -gt 0 ]]; then
                    read -p "$(print_status "INPUT" "VM number (1-$count): ")" num
                    if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 ]] && [[ "$num" -le "$count" ]]; then
                        show_vm_info "${vms[$((num-1))]}"
                    fi
                else
                    print_status "ERROR" "No VMs available"
                fi
                ;;
            5)
                if [[ $count -gt 0 ]]; then
                    read -p "$(print_status "INPUT" "VM number (1-$count): ")" num
                    if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 ]] && [[ "$num" -le "$count" ]]; then
                        edit_vm "${vms[$((num-1))]}"
                    fi
                else
                    print_status "ERROR" "No VMs available"
                fi
                ;;
            6)
                if [[ $count -gt 0 ]]; then
                    read -p "$(print_status "INPUT" "VM number (1-$count): ")" num
                    if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 ]] && [[ "$num" -le "$count" ]]; then
                        delete_vm "${vms[$((num-1))]}"
                    fi
                else
                    print_status "ERROR" "No VMs available"
                fi
                ;;
            s|S)
                show_system_info
                ;;
            o|O)
                list_available_oses
                ;;
            0|q|Q)
                print_status "INFO" "Goodbye!"
                exit 0
                ;;
            *)
                print_status "ERROR" "Invalid option"
                ;;
        esac

        echo
        read -p "Press Enter to continue..."
    done
}

# ============================================
# OS Options - ALL LATEST VERSIONS (35+)
# ============================================

declare -A OS_OPTIONS=(
    # Ubuntu - All LTS and Latest
    ["Ubuntu 18.04 LTS (Bionic)"]="ubuntu|18.04|bionic|https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img|ubuntu18|ubuntu|ubuntu"
    ["Ubuntu 20.04 LTS (Focal)"]="ubuntu|20.04|focal|https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img|ubuntu20|ubuntu|ubuntu"
    ["Ubuntu 22.04 LTS (Jammy)"]="ubuntu|22.04|jammy|https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img|ubuntu22|ubuntu|ubuntu"
    ["Ubuntu 24.04 LTS (Noble)"]="ubuntu|24.04|noble|https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img|ubuntu24|ubuntu|ubuntu"
    ["Ubuntu 25.04 (Plucky)"]="ubuntu|25.04|plucky|https://cloud-images.ubuntu.com/plucky/current/plucky-server-cloudimg-amd64.img|ubuntu25|ubuntu|ubuntu"

    # Debian - All Stable & Testing
    ["Debian 10 (Buster)"]="debian|10|buster|https://cloud.debian.org/images/cloud/buster/latest/debian-10-generic-amd64.qcow2|debian10|debian|debian"
    ["Debian 11 (Bullseye)"]="debian|11|bullseye|https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2|debian11|debian|debian"
    ["Debian 12 (Bookworm)"]="debian|12|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|debian12|debian|debian"
    ["Debian 13 (Trixie)"]="debian|13|trixie|https://cloud.debian.org/images/cloud/trixie/daily/latest/debian-13-generic-amd64-daily.qcow2|debian13|debian|debian"
    ["Debian Sid (Unstable)"]="debian|sid|sid|https://cloud.debian.org/images/cloud/sid/daily/latest/debian-sid-generic-amd64-daily.qcow2|debiansid|debian|debian"

    # Debian-based Distributions (Using base Debian/Ubuntu cloud images - can be customized after boot)
    ["Kali Linux (Debian-based)"]="kali|2024|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|kali2024|kali|kali"
    ["Parrot OS (Debian-based)"]="parrot|6.2|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|parrot62|parrot|parrot"
    ["MX Linux (Debian-based)"]="mxlinux|23|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|mxlinux23|debian|debian"
    ["Deepin (Debian-based)"]="deepin|23|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|deepin23|debian|debian"
    ["Devuan 5 (Debian fork)"]="devuan|5|daedalus|https://pkgmaster.devuan.org/devuan_daedalus/installer-iso/20230607/devuan_daedalus_5.0.0_amd64_netinstall.iso|devuan5|root|devuan"
    ["antiX 23 (Debian-based)"]="antix|23|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|antix23|debian|debian"
    ["SparkyLinux 7 (Debian-based)"]="sparky|7|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|sparky7|debian|debian"
    ["Peppermint OS (Debian-based)"]="peppermint|2024|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|peppermint|debian|debian"
    ["Raspberry Pi OS (Debian)"]="raspios|12|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|raspios12|pi|raspberry"
    ["LMDE 6 (Linux Mint Debian)"]="lmde|6|faye|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|lmde6|debian|debian"

    # Fedora - Latest Releases
    ["Fedora 39"]="fedora|39|39|https://download.fedoraproject.org/pub/fedora/linux/releases/39/Cloud/x86_64/images/Fedora-Cloud-Base-39-1.5.x86_64.qcow2|fedora39|fedora|fedora"
    ["Fedora 40"]="fedora|40|40|https://download.fedoraproject.org/pub/fedora/linux/releases/40/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-40-1.14.x86_64.qcow2|fedora40|fedora|fedora"
    ["Fedora 41"]="fedora|41|41|https://download.fedoraproject.org/pub/fedora/linux/releases/41/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-41-1.4.x86_64.qcow2|fedora41|fedora|fedora"

    # CentOS Stream
    ["CentOS Stream 9"]="centos|stream9|stream9|https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2|centos9|cloud-user|centos"

    # AlmaLinux - RHEL Alternative
    ["AlmaLinux 8"]="almalinux|8|8|https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2|alma8|almalinux|almalinux"
    ["AlmaLinux 9"]="almalinux|9|9|https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2|alma9|almalinux|almalinux"

    # Rocky Linux - RHEL Alternative
    ["Rocky Linux 8"]="rocky|8|8|https://download.rockylinux.org/pub/rocky/8/images/x86_64/Rocky-8-GenericCloud.latest.x86_64.qcow2|rocky8|rocky|rocky"
    ["Rocky Linux 9"]="rocky|9|9|https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2|rocky9|rocky|rocky"

    # Oracle Linux
    ["Oracle Linux 8"]="oracle|8|ol8|https://yum.oracle.com/templates/OracleLinux/OL8/u10/x86_64/OL8U10_x86_64-kvm-b234.qcow2|oracle8|opc|oracle"
    ["Oracle Linux 9"]="oracle|9|ol9|https://yum.oracle.com/templates/OracleLinux/OL9/u5/x86_64/OL9U5_x86_64-kvm-b253.qcow2|oracle9|opc|oracle"

    # Arch Linux - Rolling Release
    ["Arch Linux"]="arch|rolling|latest|https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2|archlinux|arch|arch"

    # Alpine Linux - Ultra Lightweight
    ["Alpine Linux 3.18"]="alpine|3.18|v3.18|https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/cloud/nocloud_alpine-3.18.9-x86_64-bios-cloudinit-r0.qcow2|alpine318|alpine|alpine"
    ["Alpine Linux 3.19"]="alpine|3.19|v3.19|https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/cloud/nocloud_alpine-3.19.4-x86_64-bios-cloudinit-r0.qcow2|alpine319|alpine|alpine"
    ["Alpine Linux 3.20"]="alpine|3.20|v3.20|https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/cloud/nocloud_alpine-3.20.3-x86_64-bios-cloudinit-r0.qcow2|alpine320|alpine|alpine"
    ["Alpine Linux 3.21"]="alpine|3.21|v3.21|https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/cloud/nocloud_alpine-3.21.0-x86_64-bios-cloudinit-r0.qcow2|alpine321|alpine|alpine"

    # openSUSE
    ["openSUSE Leap 15.5"]="opensuse|15.5|leap155|https://download.opensuse.org/distribution/leap/15.5/appliances/openSUSE-Leap-15.5-Minimal-VM.x86_64-Cloud.qcow2|opensuse155|opensuse|opensuse"
    ["openSUSE Leap 15.6"]="opensuse|15.6|leap156|https://download.opensuse.org/distribution/leap/15.6/appliances/openSUSE-Leap-15.6-Minimal-VM.x86_64-Cloud.qcow2|opensuse156|opensuse|opensuse"
    ["openSUSE Tumbleweed"]="opensuse|tumbleweed|tumbleweed|https://download.opensuse.org/tumbleweed/appliances/openSUSE-Tumbleweed-Minimal-VM.x86_64-Cloud.qcow2|opensusetw|opensuse|opensuse"

    # Amazon Linux
    ["Amazon Linux 2"]="amazonlinux|2|al2|https://cdn.amazonlinux.com/os-images/latest/kvm/amzn2-kvm-2.0.20241010.0-x86_64.xfs.gpt.qcow2|amazonlinux2|ec2-user|amazon"
    ["Amazon Linux 2023"]="amazonlinux|2023|al2023|https://cdn.amazonlinux.com/al2023/os-images/2023.6.20241121.0/kvm/al2023-kvm-2023.6.20241121.0-kernel-6.1-x86_64.xfs.gpt.qcow2|amazonlinux|ec2-user|amazon"

    # Kali Linux - REMOVED (URLs frequently change, use official Kali site)

    # FreeBSD
    ["FreeBSD 13"]="freebsd|13|13|https://download.freebsd.org/releases/VM-IMAGES/13.4-RELEASE/amd64/Latest/FreeBSD-13.4-RELEASE-amd64.qcow2.xz|freebsd13|freebsd|freebsd"
    ["FreeBSD 14"]="freebsd|14|14|https://download.freebsd.org/releases/VM-IMAGES/14.2-RELEASE/amd64/Latest/FreeBSD-14.2-RELEASE-amd64.qcow2.xz|freebsd14|freebsd|freebsd"

    # OpenBSD - FIXED URL
    ["OpenBSD 7.6"]="openbsd|7.6|76|https://ftp.openbsd.org/pub/OpenBSD/7.6/amd64/install76.img|openbsd76|root|openbsd"
)

# ============================================
# Entry Point
# ============================================

if [[ $# -gt 0 ]]; then
    case "$1" in
        list)
            get_vm_list
            ;;
        create)
            display_header
            check_dependencies
            check_kvm
            create_new_vm
            ;;
        quick)
            shift
            if [[ $# -lt 1 ]]; then
                print_status "ERROR" "Usage: $0 quick <os> [name]"
                list_available_oses
                exit 1
            fi
            check_dependencies
            check_kvm
            quick_create_vm "$@"
            ;;
        start)
            shift
            [[ -z "${1:-}" ]] && { print_status "ERROR" "VM name required"; exit 1; }
            check_kvm
            start_vm "$1"
            ;;
        stop)
            shift
            [[ -z "${1:-}" ]] && { print_status "ERROR" "VM name required"; exit 1; }
            stop_vm "$1"
            ;;
        delete)
            shift
            [[ -z "${1:-}" ]] && { print_status "ERROR" "VM name required"; exit 1; }
            delete_vm "$1"
            ;;
        info)
            shift
            [[ -z "${1:-}" ]] && { print_status "ERROR" "VM name required"; exit 1; }
            show_vm_info "$1"
            ;;
        edit)
            shift
            [[ -z "${1:-}" ]] && { print_status "ERROR" "VM name required"; exit 1; }
            edit_vm "$1"
            ;;
        system)
            check_kvm
            show_system_info
            ;;
        oses)
            list_available_oses
            ;;
        help|--help|-h)
            cli_usage
            ;;
        *)
            print_status "ERROR" "Unknown command: $1"
            cli_usage
            exit 1
            ;;
    esac
    exit 0
fi

# Interactive mode
display_header
print_status "INFO" "Initializing..."
check_dependencies
check_kvm
echo
main_menu
