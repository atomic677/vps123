#!/bin/bash
set -euo pipefail

# =============================
# Enhanced Multi-VM Manager
# =============================

# Function to display header
display_header() {
    clear
    cat << "EOF"
========================================================================
  __  __ ______ _    _ _____            ______
 |  \/  |  ____| |  | |  __ \     /\   |___  /
 | \  / | |__  | |__| | |__) |   /  \     / /
 | |\/| |  __| |  __  |  _  /   / /\ \   / /
 | |  | | |____| |  | | | \ \  / ____ \ / /__
 |_|  |_|______|_|  |_|_|  \_\/_/    \_\_____|

                       MEHRAZ
========================================================================
EOF
    echo
}

# Function to display colored output
print_status() {
    local type=$1
    local message=$2

    case $type in
        "INFO") echo -e "\033[1;34m[INFO]\033[0m $message" ;;
        "WARN") echo -e "\033[1;33m[WARN]\033[0m $message" ;;
        "ERROR") echo -e "\033[1;31m[ERROR]\033[0m $message" ;;
        "SUCCESS") echo -e "\033[1;32m[SUCCESS]\033[0m $message" ;;
        "INPUT") echo -e "\033[1;36m[INPUT]\033[0m $message" ;;
        *) echo "[$type] $message" ;;
    esac
}

# Function to validate input
validate_input() {
    local type=$1
    local value=$2

    case $type in
        "number")
            if ! [[ "$value" =~ ^[0-9]+$ ]]; then
                print_status "ERROR" "Must be a number"
                return 1
            fi
            ;;
        "size")
            if ! [[ "$value" =~ ^[0-9]+[GgMm]$ ]]; then
                print_status "ERROR" "Must be a size with unit (e.g., 100G, 512M)"
                return 1
            fi
            ;;
        "port")
            if ! [[ "$value" =~ ^[0-9]+$ ]] || [ "$value" -lt 23 ] || [ "$value" -gt 65535 ]; then
                print_status "ERROR" "Must be a valid port number (23-65535)"
                return 1
            fi
            ;;
        "name")
            if ! [[ "$value" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                print_status "ERROR" "VM name can only contain letters, numbers, hyphens, and underscores"
                return 1
            fi
            ;;
        "username")
            if ! [[ "$value" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
                print_status "ERROR" "Username must start with a letter or underscore, and contain only letters, numbers, hyphens, and underscores"
                return 1
            fi
            ;;
    esac
    return 0
}

# Function to check dependencies
check_dependencies() {
    local deps=("qemu-system-x86_64" "wget" "cloud-localds" "qemu-img")
    local missing_deps=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_status "ERROR" "Missing dependencies: ${missing_deps[*]}"
        print_status "INFO" "On Ubuntu/Debian, try: sudo apt install qemu-system cloud-image-utils wget"
        exit 1
    fi

    # Check for Docker if needed
    if ! command -v docker &> /dev/null; then
        print_status "WARN" "Docker not found. Windows VMs require Docker to be installed."
    fi
}

# Function to cleanup temporary files
cleanup() {
    if [ -f "user-data" ]; then rm -f "user-data"; fi
    if [ -f "meta-data" ]; then rm -f "meta-data"; fi
}

# Function to get all VM configurations
get_vm_list() {
    find "$VM_DIR" -name "*.conf" -exec basename {} .conf \; 2>/dev/null | sort
}

# Function to load VM configuration
load_vm_config() {
    local vm_name=$1
    local config_file="$VM_DIR/$vm_name.conf"

    if [[ -f "$config_file" ]]; then
        # Clear previous variables
        unset VM_NAME OS_TYPE CODENAME IMG_URL HOSTNAME USERNAME PASSWORD
        unset DISK_SIZE MEMORY CPUS SSH_PORT GUI_MODE PORT_FORWARDS IMG_FILE SEED_FILE CREATED KVM_ENABLED

        source "$config_file"
        return 0
    else
        print_status "ERROR" "Configuration for VM '$vm_name' not found"
        return 1
    fi
}

# Function to save VM configuration
save_vm_config() {
    local config_file="$VM_DIR/$VM_NAME.conf"

    cat > "$config_file" <<EOF
VM_NAME="$VM_NAME"
OS_TYPE="$OS_TYPE"
CODENAME="$CODENAME"
IMG_URL="$IMG_URL"
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
DISK_SIZE="$DISK_SIZE"
MEMORY="$MEMORY"
CPUS="$CPUS"
SSH_PORT="$SSH_PORT"
GUI_MODE="$GUI_MODE"
PORT_FORWARDS="$PORT_FORWARDS"
IMG_FILE="$IMG_FILE"
SEED_FILE="$SEED_FILE"
CREATED="$CREATED"
KVM_ENABLED="$KVM_ENABLED"
BACKGROUND_MODE="${BACKGROUND_MODE:-false}"
EOF

    print_status "SUCCESS" "Configuration saved to $config_file"
}

# Function to convert ISO to qcow2
convert_iso_to_qcow2() {
    print_status "INFO" "ISO to QCOW2 Converter"
    echo

    # Get ISO file path
    while true; do
        read -p "$(print_status "INPUT" "Enter path to ISO file: ")" iso_path
        if [[ -z "$iso_path" ]]; then
            print_status "ERROR" "ISO path cannot be empty"
            continue
        fi

        # Expand tilde and resolve path
        iso_path="${iso_path/#\~/$HOME}"

        if [[ ! -f "$iso_path" ]]; then
            print_status "ERROR" "File not found: $iso_path"
            continue
        fi

        if [[ ! "$iso_path" =~ \.(iso|ISO)$ ]]; then
            print_status "WARN" "File doesn't have .iso extension. Continue anyway? (y/n)"
            read -p "$(print_status "INPUT" "Continue? ")" continue_anyway
            if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
                continue
            fi
        fi
        break
    done

    # Get output file path
    local default_output="${iso_path%.*}.qcow2"
    read -p "$(print_status "INPUT" "Enter output qcow2 file path (default: $default_output): ")" output_path
    output_path="${output_path:-$default_output}"

    # Check if output file already exists
    if [[ -f "$output_path" ]]; then
        print_status "WARN" "Output file already exists: $output_path"
        read -p "$(print_status "INPUT" "Overwrite? (y/N): ")" overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            print_status "INFO" "Conversion cancelled"
            return 0
        fi
        rm -f "$output_path"
    fi

    # Get disk size for qcow2
    while true; do
        read -p "$(print_status "INPUT" "Enter disk size for qcow2 (e.g., 20G, 50G, default: auto): ")" disk_size
        disk_size="${disk_size:-auto}"

        if [[ "$disk_size" == "auto" ]]; then
            break
        elif validate_input "size" "$disk_size"; then
            break
        fi
    done

    # Show conversion details
    echo
    print_status "INFO" "Conversion Details:"
    echo "  Source ISO: $iso_path"
    echo "  Output file: $output_path"
    echo "  Disk size: $disk_size"
    echo

    read -p "$(print_status "INPUT" "Proceed with conversion? (y/N): ")" proceed
    if [[ ! "$proceed" =~ ^[Yy]$ ]]; then
        print_status "INFO" "Conversion cancelled"
        return 0
    fi

    # Perform conversion
    print_status "INFO" "Converting ISO to QCOW2..."
    print_status "INFO" "This may take a few minutes depending on ISO size..."

    if [[ "$disk_size" == "auto" ]]; then
        # Convert without specifying size (creates minimal qcow2)
        if qemu-img convert -f raw -O qcow2 "$iso_path" "$output_path"; then
            print_status "SUCCESS" "Conversion completed successfully!"
            echo
            print_status "INFO" "Output file: $output_path"

            # Show file info
            local output_size=$(du -h "$output_path" | cut -f1)
            print_status "INFO" "Output size: $output_size"

            # Show qcow2 info
            print_status "INFO" "Image information:"
            qemu-img info "$output_path"
        else
            print_status "ERROR" "Conversion failed!"
            return 1
        fi
    else
        # Convert and resize to specified size
        if qemu-img convert -f raw -O qcow2 "$iso_path" "$output_path"; then
            print_status "INFO" "Resizing image to $disk_size..."
            if qemu-img resize "$output_path" "$disk_size"; then
                print_status "SUCCESS" "Conversion and resize completed successfully!"
                echo
                print_status "INFO" "Output file: $output_path"

                # Show file info
                local output_size=$(du -h "$output_path" | cut -f1)
                print_status "INFO" "Physical size: $output_size"

                # Show qcow2 info
                print_status "INFO" "Image information:"
                qemu-img info "$output_path"
            else
                print_status "WARN" "Conversion succeeded but resize failed"
                print_status "INFO" "Output file: $output_path"
            fi
        else
            print_status "ERROR" "Conversion failed!"
            return 1
        fi
    fi

    echo
}

# Function to create new VM
create_new_vm() {
    print_status "INFO" "Creating a new VM"

    # OS Selection
    print_status "INFO" "Select an OS to set up:"
    local os_options=()
    local i=1
    for os in "${!OS_OPTIONS[@]}"; do
        echo "  $i) $os"
        os_options[$i]="$os"
        ((i++))
    done

    while true; do
        read -p "$(print_status "INPUT" "Enter your choice (1-${#OS_OPTIONS[@]}): ")" choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#OS_OPTIONS[@]} ]; then
            local os="${os_options[$choice]}"
            IFS='|' read -r OS_TYPE CODENAME IMG_URL DEFAULT_HOSTNAME DEFAULT_USERNAME DEFAULT_PASSWORD <<< "${OS_OPTIONS[$os]}"
            break
        else
            print_status "ERROR" "Invalid selection. Try again."
        fi
    done

    # Custom Inputs with validation
    while true; do
        read -p "$(print_status "INPUT" "Enter VM name (default: $DEFAULT_HOSTNAME): ")" VM_NAME
        VM_NAME="${VM_NAME:-$DEFAULT_HOSTNAME}"
        if validate_input "name" "$VM_NAME"; then
            # Check if VM name already exists
            if [[ -f "$VM_DIR/$VM_NAME.conf" ]]; then
                print_status "ERROR" "VM with name '$VM_NAME' already exists"
            else
                break
            fi
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "Enter hostname (default: $VM_NAME): ")" HOSTNAME
        HOSTNAME="${HOSTNAME:-$VM_NAME}"
        if validate_input "name" "$HOSTNAME"; then
            break
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "Enter username (default: $DEFAULT_USERNAME): ")" USERNAME
        USERNAME="${USERNAME:-$DEFAULT_USERNAME}"
        if validate_input "username" "$USERNAME"; then
            break
        fi
    done

    while true; do
        read -s -p "$(print_status "INPUT" "Enter password (default: $DEFAULT_PASSWORD): ")" PASSWORD
        PASSWORD="${PASSWORD:-$DEFAULT_PASSWORD}"
        echo
        if [ -n "$PASSWORD" ]; then
            break
        else
            print_status "ERROR" "Password cannot be empty"
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "Disk size (default: 20G): ")" DISK_SIZE
        DISK_SIZE="${DISK_SIZE:-20G}"
        if validate_input "size" "$DISK_SIZE"; then
            break
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "Memory in MB (default: 2048): ")" MEMORY
        MEMORY="${MEMORY:-2048}"
        if validate_input "number" "$MEMORY"; then
            break
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "Number of CPUs (default: 2): ")" CPUS
        CPUS="${CPUS:-2}"
        if validate_input "number" "$CPUS"; then
            break
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "SSH Port (default: 2222): ")" SSH_PORT
        SSH_PORT="${SSH_PORT:-2222}"
        if validate_input "port" "$SSH_PORT"; then
            # Check if port is already in use
            if ss -tln 2>/dev/null | grep -q ":$SSH_PORT "; then
                print_status "ERROR" "Port $SSH_PORT is already in use"
            else
                break
            fi
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "Enable GUI mode? (y/n, default: n): ")" gui_input
        GUI_MODE=false
        gui_input="${gui_input:-n}"
        if [[ "$gui_input" =~ ^[Yy]$ ]]; then
            GUI_MODE=true
            break
        elif [[ "$gui_input" =~ ^[Nn]$ ]]; then
            break
        else
            print_status "ERROR" "Please answer y or n"
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "Enable KVM acceleration for this virtual machine? (yes/no): ")" kvm_input
        KVM_ENABLED=false
        if [[ "$kvm_input" =~ ^[Yy][Ee][Ss]$ ]] || [[ "$kvm_input" =~ ^[Yy]$ ]]; then
            KVM_ENABLED=true
            break
        elif [[ "$kvm_input" =~ ^[Nn][Oo]$ ]] || [[ "$kvm_input" =~ ^[Nn]$ ]]; then
            break
        else
            print_status "ERROR" "Please answer yes or no"
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "Run VM in background for long-term operation? (y/n, default: n): ")" bg_input
        BACKGROUND_MODE=false
        bg_input="${bg_input:-n}"
        if [[ "$bg_input" =~ ^[Yy]$ ]]; then
            BACKGROUND_MODE=true
            break
        elif [[ "$bg_input" =~ ^[Nn]$ ]]; then
            break
        else
            print_status "ERROR" "Please answer y or n"
        fi
    done

    # Additional network options
    read -p "$(print_status "INPUT" "Additional port forwards (e.g., 8080:80, press Enter for none): ")" PORT_FORWARDS

    IMG_FILE="$VM_DIR/$VM_NAME.img"
    SEED_FILE="$VM_DIR/$VM_NAME-seed.iso"
    CREATED="$(date)"

    # Download and setup VM image
    setup_vm_image

    # Save configuration
    save_vm_config
}

# Function to setup VM image
setup_vm_image() {
    # Skip image setup for Windows VMs (Docker handles this)
    if [[ "$OS_TYPE" == "windows" ]]; then
        print_status "INFO" "Windows VM will be managed by Docker"
        print_status "INFO" "Image will be downloaded automatically on first start"
        return 0
    fi

    print_status "INFO" "Downloading and preparing image..."

    # Create VM directory if it doesn't exist
    mkdir -p "$VM_DIR"

    # Check if image already exists
    if [[ -f "$IMG_FILE" ]]; then
        print_status "INFO" "Image file already exists. Skipping download."
    else
        print_status "INFO" "Downloading image from $IMG_URL..."

        # Check if the image is a tar archive
        if [[ "$IMG_URL" =~ \.tar\.(xz|gz|bz2)$ ]]; then
            local temp_archive="$IMG_FILE.archive"
            if ! wget --progress=bar:force "$IMG_URL" -O "$temp_archive"; then
                print_status "ERROR" "Failed to download image from $IMG_URL"
                exit 1
            fi

            print_status "INFO" "Extracting tar archive..."
            local extract_dir="$VM_DIR/extract_$$"
            mkdir -p "$extract_dir"

            if tar -xf "$temp_archive" -C "$extract_dir" 2>/dev/null; then
                # Find the first qcow2, img, raw, or vmdk file
                local extracted_file=$(find "$extract_dir" -type f \( -name "*.qcow2" -o -name "*.img" -o -name "*.raw" -o -name "*.vmdk" \) | head -1)

                if [[ -n "$extracted_file" ]]; then
                    print_status "INFO" "Found disk image: $(basename "$extracted_file")"

                    # Check if it's already qcow2
                    local img_format=$(qemu-img info "$extracted_file" 2>/dev/null | grep "file format:" | awk '{print $3}')

                    if [[ "$img_format" == "qcow2" ]]; then
                        print_status "INFO" "Image is already in qcow2 format"
                        mv "$extracted_file" "$IMG_FILE.tmp"
                    else
                        print_status "INFO" "Converting $img_format to qcow2 format..."
                        if qemu-img convert -f "$img_format" -O qcow2 -p "$extracted_file" "$IMG_FILE.tmp"; then
                            print_status "SUCCESS" "Conversion to qcow2 completed"
                        else
                            print_status "ERROR" "Failed to convert image to qcow2"
                            rm -rf "$extract_dir" "$temp_archive"
                            exit 1
                        fi
                    fi
                else
                    print_status "ERROR" "No disk image found in archive"
                    rm -rf "$extract_dir" "$temp_archive"
                    exit 1
                fi
            else
                print_status "ERROR" "Failed to extract tar archive"
                rm -rf "$extract_dir" "$temp_archive"
                exit 1
            fi

            rm -rf "$extract_dir" "$temp_archive"
        # Check if the image is compressed (non-tar)
        elif [[ "$IMG_URL" =~ \.(xz|gz|bz2|zip)$ ]]; then
            local temp_compressed="$IMG_FILE.compressed"
            if ! wget --progress=bar:force "$IMG_URL" -O "$temp_compressed"; then
                print_status "ERROR" "Failed to download image from $IMG_URL"
                exit 1
            fi

            print_status "INFO" "Extracting compressed image..."
            if [[ "$IMG_URL" =~ \.xz$ ]]; then
                xz -d -c "$temp_compressed" > "$IMG_FILE.extracted"
            elif [[ "$IMG_URL" =~ \.gz$ ]]; then
                gunzip -c "$temp_compressed" > "$IMG_FILE.extracted"
            elif [[ "$IMG_URL" =~ \.bz2$ ]]; then
                bunzip2 -c "$temp_compressed" > "$IMG_FILE.extracted"
            fi
            rm -f "$temp_compressed"

            # Check format and convert if needed
            local img_format=$(qemu-img info "$IMG_FILE.extracted" 2>/dev/null | grep "file format:" | awk '{print $3}')

            if [[ -z "$img_format" ]]; then
                print_status "WARN" "Could not detect image format, assuming raw"
                img_format="raw"
            fi

            if [[ "$img_format" == "qcow2" ]]; then
                print_status "INFO" "Image is already in qcow2 format"
                mv "$IMG_FILE.extracted" "$IMG_FILE.tmp"
            else
                print_status "INFO" "Converting $img_format to qcow2 format..."
                if qemu-img convert -f "$img_format" -O qcow2 -p "$IMG_FILE.extracted" "$IMG_FILE.tmp"; then
                    print_status "SUCCESS" "Conversion to qcow2 completed"
                    rm -f "$IMG_FILE.extracted"
                else
                    print_status "ERROR" "Failed to convert image to qcow2"
                    rm -f "$IMG_FILE.extracted"
                    exit 1
                fi
            fi
        else
            if ! wget --progress=bar:force "$IMG_URL" -O "$IMG_FILE.downloaded"; then
                print_status "ERROR" "Failed to download image from $IMG_URL"
                exit 1
            fi

            # Check format and convert if needed
            local img_format=$(qemu-img info "$IMG_FILE.downloaded" 2>/dev/null | grep "file format:" | awk '{print $3}')

            if [[ -z "$img_format" ]]; then
                print_status "WARN" "Could not detect image format, assuming raw"
                img_format="raw"
            fi

            if [[ "$img_format" == "qcow2" ]]; then
                print_status "INFO" "Image is already in qcow2 format"
                mv "$IMG_FILE.downloaded" "$IMG_FILE.tmp"
            else
                print_status "INFO" "Converting $img_format to qcow2 format..."
                if qemu-img convert -f "$img_format" -O qcow2 -p "$IMG_FILE.downloaded" "$IMG_FILE.tmp"; then
                    print_status "SUCCESS" "Conversion to qcow2 completed"
                    rm -f "$IMG_FILE.downloaded"
                else
                    print_status "ERROR" "Failed to convert image to qcow2"
                    rm -f "$IMG_FILE.downloaded"
                    exit 1
                fi
            fi
        fi
        mv "$IMG_FILE.tmp" "$IMG_FILE"
    fi

    # Resize the disk image if needed
    if ! qemu-img resize "$IMG_FILE" "$DISK_SIZE" 2>/dev/null; then
        print_status "WARN" "Failed to resize disk image. Will try to expand..."
        # Get current virtual size
        local current_size=$(qemu-img info "$IMG_FILE" | grep "virtual size" | awk '{print $3}')
        print_status "INFO" "Current size: $current_size, Requested: $DISK_SIZE"
    fi

    # Check if OS requires cloud-init or not
    if [[ "$CODENAME" == "nocloudinit" ]]; then
        print_status "INFO" "This OS does not use cloud-init. VM will boot with default credentials."
        print_status "INFO" "Default credentials - Username: $USERNAME, Password: $PASSWORD"
        print_status "SUCCESS" "VM '$VM_NAME' created successfully."
        # Create an empty seed file to avoid errors
        touch "$SEED_FILE"
        return 0
    fi

    # cloud-init configuration
    cat > user-data <<EOF
#cloud-config
hostname: $HOSTNAME
ssh_pwauth: true
disable_root: false
users:
  - name: $USERNAME
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    password: $(openssl passwd -6 "$PASSWORD" | tr -d '\n')
chpasswd:
  list: |
    root:$PASSWORD
    $USERNAME:$PASSWORD
  expire: false
EOF

    cat > meta-data <<EOF
instance-id: iid-$VM_NAME
local-hostname: $HOSTNAME
EOF

    if ! cloud-localds "$SEED_FILE" user-data meta-data; then
        print_status "ERROR" "Failed to create cloud-init seed image"
        exit 1
    fi

    print_status "SUCCESS" "VM '$VM_NAME' created successfully."
}

# Function to start Windows VM via Docker
start_windows_vm() {
    local vm_name=$1

    if ! command -v docker &> /dev/null; then
        print_status "ERROR" "Docker is required to run Windows VMs"
        print_status "INFO" "Install Docker: curl -fsSL https://get.docker.com | sh"
        return 1
    fi

    print_status "INFO" "Starting Windows VM: $vm_name"
    print_status "INFO" "RDP: localhost:$SSH_PORT (use Remote Desktop)"
    print_status "INFO" "Web Interface: http://localhost:8006"

    # Prepare Docker command
    local docker_cmd=(
        docker run -it --rm
        --name "$vm_name"
        -p "$SSH_PORT:3389"
        -p 8006:8006
        --device=/dev/kvm
        --cap-add NET_ADMIN
        --stop-timeout 120
    )

    # Add memory configuration
    if [[ -n "$MEMORY" ]]; then
        docker_cmd+=(-e "RAM_SIZE=${MEMORY}M")
    fi

    # Add CPU configuration
    if [[ -n "$CPUS" ]]; then
        docker_cmd+=(-e "CPU_CORES=$CPUS")
    fi

    # Add disk size configuration
    if [[ -n "$DISK_SIZE" ]]; then
        docker_cmd+=(-e "DISK_SIZE=$DISK_SIZE")
    fi

    # Set Windows version
    if [[ "$CODENAME" == "win11" ]]; then
        docker_cmd+=(-e "VERSION=win11")
    elif [[ "$CODENAME" == "win10" ]]; then
        docker_cmd+=(-e "VERSION=win10")
    fi

    # Mount storage directory
    local storage_dir="$VM_DIR/$vm_name-storage"
    mkdir -p "$storage_dir"
    docker_cmd+=(-v "$storage_dir:/storage")

    # Add the image
    docker_cmd+=(dockurr/windows)

    print_status "INFO" "Starting Docker container..."
    print_status "INFO" "This may take a while on first run (downloading Windows image)"
    "${docker_cmd[@]}"

    print_status "INFO" "Windows VM $vm_name has been shut down"
}

# Function to start a VM
start_vm() {
    local vm_name=$1

    if load_vm_config "$vm_name"; then
        # Check if this is a Windows VM
        if [[ "$OS_TYPE" == "windows" ]]; then
            start_windows_vm "$vm_name"
            return $?
        fi

        print_status "INFO" "Starting VM: $vm_name"
        print_status "INFO" "SSH: ssh -p $SSH_PORT $USERNAME@localhost"
        print_status "INFO" "Password: $PASSWORD"

        # Check if image file exists
        if [[ ! -f "$IMG_FILE" ]]; then
            print_status "ERROR" "VM image file not found: $IMG_FILE"
            return 1
        fi

        # Check if seed file exists
        if [[ ! -f "$SEED_FILE" ]]; then
            print_status "WARN" "Seed file not found, recreating..."
            setup_vm_image
        fi

        # Base QEMU command with performance optimizations
        local qemu_cmd=(
            qemu-system-x86_64
            -m "$MEMORY"
            -smp "$CPUS,sockets=1,cores=$CPUS,threads=1"
            -drive "file=$IMG_FILE,format=qcow2,if=virtio,cache=writeback,aio=threads,discard=unmap"
            -drive "file=$SEED_FILE,format=raw,if=virtio,cache=writeback"
            -boot order=c
            -device virtio-net-pci,netdev=n0,mrg_rxbuf=on
            -netdev "user,id=n0,hostfwd=tcp::$SSH_PORT-:22"
        )

        # Add KVM acceleration if enabled
        if [[ "${KVM_ENABLED:-false}" == true ]]; then
            if [ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
                qemu_cmd+=(-enable-kvm -cpu host,+x2apic,+pdpe1gb)
                # Enable memory overcommit protection
                qemu_cmd+=(-overcommit mem-lock=off)
                print_status "INFO" "KVM acceleration enabled with optimized CPU features"
            else
                qemu_cmd+=(-cpu qemu64,+ssse3,+sse4.1,+sse4.2)
                print_status "WARN" "KVM requested but not available, using emulation mode with qemu64 CPU"
            fi
        else
            qemu_cmd+=(-cpu qemu64,+ssse3,+sse4.1,+sse4.2)
            print_status "INFO" "Running without KVM acceleration (emulation mode)"
        fi

        # Add port forwards if specified
        if [[ -n "$PORT_FORWARDS" ]]; then
            IFS=',' read -ra forwards <<< "$PORT_FORWARDS"
            for forward in "${forwards[@]}"; do
                IFS=':' read -r host_port guest_port <<< "$forward"
                qemu_cmd+=(-device "virtio-net-pci,netdev=n${#qemu_cmd[@]}")
                qemu_cmd+=(-netdev "user,id=n${#qemu_cmd[@]},hostfwd=tcp::$host_port-:$guest_port")
            done
        fi

        # Add performance enhancements for long-running stability
        qemu_cmd+=(
            # Memory balloon for dynamic memory management
            -device virtio-balloon-pci,deflate-on-oom=on
            # Fast random number generation
            -object rng-random,filename=/dev/urandom,id=rng0
            -device virtio-rng-pci,rng=rng0,max-bytes=1024,period=1000
            # Reduce timer overhead for better CPU efficiency
            -global kvm-pit.lost_tick_policy=delay
            # Optimize real-time clock
            -rtc base=utc,clock=host,driftfix=slew
            # Machine type optimization
            -machine type=q35,accel=tcg,smm=off
            # Disable unnecessary USB for better performance
            -usb
            -device usb-tablet
        )

        # Override machine type if KVM is enabled
        if [[ "${KVM_ENABLED:-false}" == true ]] && [ -e /dev/kvm ]; then
            # Remove the tcg machine and add KVM-optimized one
            qemu_cmd+=(-machine type=q35,accel=kvm,smm=off)
        fi

        # Check if background mode is enabled
        if [[ "${BACKGROUND_MODE:-false}" == true ]]; then
            # Add pidfile and daemonize options for background running
            local pid_file="$VM_DIR/$vm_name.pid"
            local log_file="$VM_DIR/$vm_name.log"

            # For background mode: use VNC display instead of nographic
            qemu_cmd+=(-display none)
            qemu_cmd+=(-serial "file:$log_file")
            qemu_cmd+=(-monitor "unix:$VM_DIR/$vm_name.sock,server,nowait")
            qemu_cmd+=(-daemonize -pidfile "$pid_file")

            print_status "INFO" "Starting QEMU in background mode..."
            print_status "INFO" "Log file: $log_file"
            print_status "INFO" "PID file: $pid_file"

            if "${qemu_cmd[@]}"; then
                sleep 1
                if [[ -f "$pid_file" ]]; then
                    local pid=$(cat "$pid_file")
                    print_status "SUCCESS" "VM $vm_name started in background (PID: $pid)"
                    print_status "INFO" "SSH: ssh -p $SSH_PORT $USERNAME@localhost"
                    print_status "INFO" "To stop: Select 'Stop a VM' from menu or kill -TERM $pid"
                else
                    print_status "SUCCESS" "VM $vm_name started in background"
                fi
            else
                print_status "ERROR" "Failed to start VM in background"
            fi
        else
            # Add GUI or console mode for foreground operation
            if [[ "$GUI_MODE" == true ]]; then
                qemu_cmd+=(-vga virtio -display gtk,gl=on)
            else
                qemu_cmd+=(-nographic -serial mon:stdio)
            fi

            print_status "INFO" "Starting QEMU..."
            "${qemu_cmd[@]}"
            print_status "INFO" "VM $vm_name has been shut down"
        fi
    fi
}

# Function to delete a VM
delete_vm() {
    local vm_name=$1

    print_status "WARN" "This will permanently delete VM '$vm_name' and all its data!"
    read -p "$(print_status "INPUT" "Are you sure? (y/N): ")" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if load_vm_config "$vm_name"; then
            rm -f "$IMG_FILE" "$SEED_FILE" "$VM_DIR/$vm_name.conf"
            print_status "SUCCESS" "VM '$vm_name' has been deleted"
        fi
    else
        print_status "INFO" "Deletion cancelled"
    fi
}

# Function to show VM info
show_vm_info() {
    local vm_name=$1

    if load_vm_config "$vm_name"; then
        echo
        print_status "INFO" "VM Information: $vm_name"
        echo "=========================================="
        echo "OS: $OS_TYPE"
        echo "Hostname: $HOSTNAME"
        echo "Username: $USERNAME"
        echo "Password: $PASSWORD"
        echo "SSH Port: $SSH_PORT"
        echo "Memory: $MEMORY MB"
        echo "CPUs: $CPUS"
        echo "Disk: $DISK_SIZE"
        echo "GUI Mode: $GUI_MODE"
        echo "KVM Enabled: ${KVM_ENABLED:-false}"
        echo "Background Mode: ${BACKGROUND_MODE:-false}"
        echo "Port Forwards: ${PORT_FORWARDS:-None}"
        echo "Created: $CREATED"
        echo "Image File: $IMG_FILE"
        echo "Seed File: $SEED_FILE"
        echo "=========================================="
        echo
        read -p "$(print_status "INPUT" "Press Enter to continue...")"
    fi
}

# Function to check if VM is running
is_vm_running() {
    local vm_name=$1

    # Check if it's a Windows VM running in Docker
    if load_vm_config "$vm_name" 2>/dev/null; then
        if [[ "$OS_TYPE" == "windows" ]]; then
            if docker ps --format '{{.Names}}' | grep -q "^${vm_name}$"; then
                return 0
            else
                return 1
            fi
        fi
    fi

    # Check QEMU process for Linux VMs
    if pgrep -f "qemu-system-x86_64.*$vm_name" >/dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to stop a running VM
stop_vm() {
    local vm_name=$1

    if load_vm_config "$vm_name"; then
        # Check if this is a Windows VM
        if [[ "$OS_TYPE" == "windows" ]]; then
            if docker ps --format '{{.Names}}' | grep -q "^${vm_name}$"; then
                print_status "INFO" "Stopping Windows VM: $vm_name"
                docker stop "$vm_name"
                print_status "SUCCESS" "VM $vm_name stopped"
            else
                print_status "INFO" "VM $vm_name is not running"
            fi
            return 0
        fi

        if is_vm_running "$vm_name"; then
            print_status "INFO" "Stopping VM: $vm_name"

            # Try graceful shutdown via monitor socket first
            local sock_file="$VM_DIR/$vm_name.sock"
            if [[ -S "$sock_file" ]]; then
                print_status "INFO" "Sending graceful shutdown command..."
                echo "system_powerdown" | socat - "UNIX-CONNECT:$sock_file" 2>/dev/null
                sleep 5
            fi

            # If still running, use SIGTERM
            if is_vm_running "$vm_name"; then
                pkill -TERM -f "qemu-system-x86_64.*$IMG_FILE"
                sleep 3
            fi

            # Force kill if necessary
            if is_vm_running "$vm_name"; then
                print_status "WARN" "VM did not stop gracefully, forcing termination..."
                pkill -9 -f "qemu-system-x86_64.*$IMG_FILE"
            fi

            # Cleanup PID and socket files
            rm -f "$VM_DIR/$vm_name.pid" "$VM_DIR/$vm_name.sock"

            print_status "SUCCESS" "VM $vm_name stopped"
        else
            print_status "INFO" "VM $vm_name is not running"
            # Cleanup stale files
            rm -f "$VM_DIR/$vm_name.pid" "$VM_DIR/$vm_name.sock"
        fi
    fi
}

# Function to edit VM configuration
edit_vm_config() {
    local vm_name=$1

    if load_vm_config "$vm_name"; then
        print_status "INFO" "Editing VM: $vm_name"

        while true; do
            echo "What would you like to edit?"
            echo "  1) Hostname"
            echo "  2) Username"
            echo "  3) Password"
            echo "  4) SSH Port"
            echo "  5) GUI Mode"
            echo "  6) Port Forwards"
            echo "  7) Memory (RAM)"
            echo "  8) CPU Count"
            echo "  9) Disk Size"
            echo " 10) KVM Acceleration"
            echo " 11) Background Mode"
            echo "  0) Back to main menu"

            read -p "$(print_status "INPUT" "Enter your choice: ")" edit_choice

            case $edit_choice in
                1)
                    while true; do
                        read -p "$(print_status "INPUT" "Enter new hostname (current: $HOSTNAME): ")" new_hostname
                        new_hostname="${new_hostname:-$HOSTNAME}"
                        if validate_input "name" "$new_hostname"; then
                            HOSTNAME="$new_hostname"
                            break
                        fi
                    done
                    ;;
                2)
                    while true; do
                        read -p "$(print_status "INPUT" "Enter new username (current: $USERNAME): ")" new_username
                        new_username="${new_username:-$USERNAME}"
                        if validate_input "username" "$new_username"; then
                            USERNAME="$new_username"
                            break
                        fi
                    done
                    ;;
                3)
                    while true; do
                        read -s -p "$(print_status "INPUT" "Enter new password (current: ****): ")" new_password
                        new_password="${new_password:-$PASSWORD}"
                        echo
                        if [ -n "$new_password" ]; then
                            PASSWORD="$new_password"
                            break
                        else
                            print_status "ERROR" "Password cannot be empty"
                        fi
                    done
                    ;;
                4)
                    while true; do
                        read -p "$(print_status "INPUT" "Enter new SSH port (current: $SSH_PORT): ")" new_ssh_port
                        new_ssh_port="${new_ssh_port:-$SSH_PORT}"
                        if validate_input "port" "$new_ssh_port"; then
                            # Check if port is already in use
                            if [ "$new_ssh_port" != "$SSH_PORT" ] && ss -tln 2>/dev/null | grep -q ":$new_ssh_port "; then
                                print_status "ERROR" "Port $new_ssh_port is already in use"
                            else
                                SSH_PORT="$new_ssh_port"
                                break
                            fi
                        fi
                    done
                    ;;
                5)
                    while true; do
                        read -p "$(print_status "INPUT" "Enable GUI mode? (y/n, current: $GUI_MODE): ")" gui_input
                        gui_input="${gui_input:-}"
                        if [[ "$gui_input" =~ ^[Yy]$ ]]; then
                            GUI_MODE=true
                            break
                        elif [[ "$gui_input" =~ ^[Nn]$ ]]; then
                            GUI_MODE=false
                            break
                        elif [ -z "$gui_input" ]; then
                            # Keep current value if user just pressed Enter
                            break
                        else
                            print_status "ERROR" "Please answer y or n"
                        fi
                    done
                    ;;
                6)
                    read -p "$(print_status "INPUT" "Additional port forwards (current: ${PORT_FORWARDS:-None}): ")" new_port_forwards
                    PORT_FORWARDS="${new_port_forwards:-$PORT_FORWARDS}"
                    ;;
                7)
                    while true; do
                        read -p "$(print_status "INPUT" "Enter new memory in MB (current: $MEMORY): ")" new_memory
                        new_memory="${new_memory:-$MEMORY}"
                        if validate_input "number" "$new_memory"; then
                            MEMORY="$new_memory"
                            break
                        fi
                    done
                    ;;
                8)
                    while true; do
                        read -p "$(print_status "INPUT" "Enter new CPU count (current: $CPUS): ")" new_cpus
                        new_cpus="${new_cpus:-$CPUS}"
                        if validate_input "number" "$new_cpus"; then
                            CPUS="$new_cpus"
                            break
                        fi
                    done
                    ;;
                9)
                    while true; do
                        read -p "$(print_status "INPUT" "Enter new disk size (current: $DISK_SIZE): ")" new_disk_size
                        new_disk_size="${new_disk_size:-$DISK_SIZE}"
                        if validate_input "size" "$new_disk_size"; then
                            DISK_SIZE="$new_disk_size"
                            break
                        fi
                    done
                    ;;
                10)
                    while true; do
                        read -p "$(print_status "INPUT" "Enable KVM acceleration? (y/n, current: ${KVM_ENABLED:-false}): ")" kvm_input
                        kvm_input="${kvm_input:-}"
                        if [[ "$kvm_input" =~ ^[Yy]$ ]]; then
                            KVM_ENABLED=true
                            break
                        elif [[ "$kvm_input" =~ ^[Nn]$ ]]; then
                            KVM_ENABLED=false
                            break
                        elif [ -z "$kvm_input" ]; then
                            break
                        else
                            print_status "ERROR" "Please answer y or n"
                        fi
                    done
                    ;;
                11)
                    while true; do
                        read -p "$(print_status "INPUT" "Run VM in background for long-term operation? (y/n, current: ${BACKGROUND_MODE:-false}): ")" bg_input
                        bg_input="${bg_input:-}"
                        if [[ "$bg_input" =~ ^[Yy]$ ]]; then
                            BACKGROUND_MODE=true
                            break
                        elif [[ "$bg_input" =~ ^[Nn]$ ]]; then
                            BACKGROUND_MODE=false
                            break
                        elif [ -z "$bg_input" ]; then
                            break
                        else
                            print_status "ERROR" "Please answer y or n"
                        fi
                    done
                    ;;
                0)
                    return 0
                    ;;
                *)
                    print_status "ERROR" "Invalid selection"
                    continue
                    ;;
            esac

            # Recreate seed image with new configuration if user/password/hostname changed
            if [[ "$edit_choice" -eq 1 || "$edit_choice" -eq 2 || "$edit_choice" -eq 3 ]]; then
                print_status "INFO" "Updating cloud-init configuration..."
                setup_vm_image
            fi

            # Save configuration
            save_vm_config

            read -p "$(print_status "INPUT" "Continue editing? (y/N): ")" continue_editing
            if [[ ! "$continue_editing" =~ ^[Yy]$ ]]; then
                break
            fi
        done
    fi
}

# Function to convert VM image to qcow2 format
convert_vm_to_qcow2() {
    local vm_name=$1

    if load_vm_config "$vm_name"; then
        # Check if image file exists
        if [[ ! -f "$IMG_FILE" ]]; then
            print_status "ERROR" "VM image file not found: $IMG_FILE"
            return 1
        fi

        # Detect current image format
        print_status "INFO" "Detecting current image format..."
        local img_info=$(qemu-img info "$IMG_FILE" 2>/dev/null)
        local current_format=$(echo "$img_info" | grep "file format:" | awk '{print $3}')

        if [[ -z "$current_format" ]]; then
            print_status "ERROR" "Could not detect image format"
            return 1
        fi

        print_status "INFO" "Current format: $current_format"

        # Check if already qcow2
        if [[ "$current_format" == "qcow2" ]]; then
            print_status "INFO" "VM image is already in qcow2 format"
            echo
            echo "$img_info"
            echo
            read -p "$(print_status "INPUT" "Press Enter to continue...")"
            return 0
        fi

        # Show current image info
        echo
        print_status "INFO" "Current image information:"
        echo "$img_info"
        echo

        # Confirm conversion
        print_status "WARN" "This will convert the VM image from $current_format to qcow2 format"
        print_status "WARN" "The original image will be backed up with .backup extension"
        echo
        read -p "$(print_status "INPUT" "Proceed with conversion? (y/N): ")" proceed

        if [[ ! "$proceed" =~ ^[Yy]$ ]]; then
            print_status "INFO" "Conversion cancelled"
            return 0
        fi

        # Backup original file
        local backup_file="${IMG_FILE}.backup"
        print_status "INFO" "Creating backup: $backup_file"

        if ! cp "$IMG_FILE" "$backup_file"; then
            print_status "ERROR" "Failed to create backup"
            return 1
        fi

        # Convert to qcow2
        local temp_file="${IMG_FILE}.converting"
        print_status "INFO" "Converting $current_format to qcow2..."
        print_status "INFO" "This may take several minutes depending on image size..."

        if qemu-img convert -f "$current_format" -O qcow2 -p "$IMG_FILE" "$temp_file"; then
            # Replace original with converted file
            if mv "$temp_file" "$IMG_FILE"; then
                print_status "SUCCESS" "Conversion completed successfully!"
                echo

                # Show new image info
                print_status "INFO" "New image information:"
                qemu-img info "$IMG_FILE"
                echo

                # Ask about backup
                read -p "$(print_status "INPUT" "Keep backup file? (Y/n): ")" keep_backup
                if [[ "$keep_backup" =~ ^[Nn]$ ]]; then
                    rm -f "$backup_file"
                    print_status "INFO" "Backup file removed"
                else
                    print_status "INFO" "Backup saved at: $backup_file"
                fi
            else
                print_status "ERROR" "Failed to replace original file"
                print_status "INFO" "Restoring from backup..."
                rm -f "$IMG_FILE"
                mv "$backup_file" "$IMG_FILE"
                rm -f "$temp_file"
                return 1
            fi
        else
            print_status "ERROR" "Conversion failed!"
            print_status "INFO" "Original image is intact"
            rm -f "$temp_file"
            rm -f "$backup_file"
            return 1
        fi
    fi
}

# Function to resize VM disk
resize_vm_disk() {
    local vm_name=$1

    if load_vm_config "$vm_name"; then
        print_status "INFO" "Current disk size: $DISK_SIZE"

        while true; do
            read -p "$(print_status "INPUT" "Enter new disk size (e.g., 50G): ")" new_disk_size
            if validate_input "size" "$new_disk_size"; then
                if [[ "$new_disk_size" == "$DISK_SIZE" ]]; then
                    print_status "INFO" "New disk size is the same as current size. No changes made."
                    return 0
                fi

                # Check if new size is smaller than current (not recommended)
                local current_size_num=${DISK_SIZE%[GgMm]}
                local new_size_num=${new_disk_size%[GgMm]}
                local current_unit=${DISK_SIZE: -1}
                local new_unit=${new_disk_size: -1}

                # Convert both to MB for comparison
                if [[ "$current_unit" =~ [Gg] ]]; then
                    current_size_num=$((current_size_num * 1024))
                fi
                if [[ "$new_unit" =~ [Gg] ]]; then
                    new_size_num=$((new_size_num * 1024))
                fi

                if [[ $new_size_num -lt $current_size_num ]]; then
                    print_status "WARN" "Shrinking disk size is not recommended and may cause data loss!"
                    read -p "$(print_status "INPUT" "Are you sure you want to continue? (y/N): ")" confirm_shrink
                    if [[ ! "$confirm_shrink" =~ ^[Yy]$ ]]; then
                        print_status "INFO" "Disk resize cancelled."
                        return 0
                    fi
                fi

                # Resize the disk
                print_status "INFO" "Resizing disk to $new_disk_size..."
                if qemu-img resize "$IMG_FILE" "$new_disk_size"; then
                    DISK_SIZE="$new_disk_size"
                    save_vm_config
                    print_status "SUCCESS" "Disk resized successfully to $new_disk_size"
                else
                    print_status "ERROR" "Failed to resize disk"
                    return 1
                fi
                break
            fi
        done
    fi
}

# Function to start VM watchdog (monitors and restarts crashed VMs)
start_vm_watchdog() {
    local vm_name=$1
    local check_interval=${2:-30}  # Default 30 seconds

    if ! load_vm_config "$vm_name"; then
        return 1
    fi

    if [[ "${BACKGROUND_MODE:-false}" != true ]]; then
        print_status "ERROR" "Watchdog only works with VMs configured for background mode"
        print_status "INFO" "Edit the VM and enable 'Background Mode' first"
        return 1
    fi

    local watchdog_pid_file="$VM_DIR/$vm_name.watchdog.pid"

    # Check if watchdog is already running
    if [[ -f "$watchdog_pid_file" ]]; then
        local existing_pid=$(cat "$watchdog_pid_file")
        if kill -0 "$existing_pid" 2>/dev/null; then
            print_status "INFO" "Watchdog for $vm_name is already running (PID: $existing_pid)"
            return 0
        else
            rm -f "$watchdog_pid_file"
        fi
    fi

    print_status "INFO" "Starting watchdog for VM: $vm_name"
    print_status "INFO" "Check interval: ${check_interval}s"

    # Start watchdog in background
    (
        echo $$ > "$watchdog_pid_file"
        local restart_count=0
        local max_restarts=10
        local restart_window=3600  # 1 hour
        local last_restart=0

        while true; do
            sleep "$check_interval"

            # Check if VM is supposed to be running
            if [[ ! -f "$VM_DIR/$vm_name.conf" ]]; then
                # VM was deleted, exit watchdog
                rm -f "$watchdog_pid_file"
                exit 0
            fi

            # Check if VM is running
            if ! is_vm_running "$vm_name"; then
                local current_time=$(date +%s)

                # Reset restart count if outside window
                if (( current_time - last_restart > restart_window )); then
                    restart_count=0
                fi

                if (( restart_count >= max_restarts )); then
                    echo "[$(date)] VM $vm_name exceeded max restarts ($max_restarts in $restart_window seconds). Watchdog stopping." >> "$VM_DIR/$vm_name.watchdog.log"
                    rm -f "$watchdog_pid_file"
                    exit 1
                fi

                echo "[$(date)] VM $vm_name not running, attempting restart..." >> "$VM_DIR/$vm_name.watchdog.log"

                # Reload config and restart
                source "$VM_DIR/$vm_name.conf"
                start_vm "$vm_name" >> "$VM_DIR/$vm_name.watchdog.log" 2>&1

                restart_count=$((restart_count + 1))
                last_restart=$current_time

                echo "[$(date)] Restart attempt $restart_count completed" >> "$VM_DIR/$vm_name.watchdog.log"
            fi
        done
    ) &

    disown

    sleep 1
    if [[ -f "$watchdog_pid_file" ]]; then
        local wpid=$(cat "$watchdog_pid_file")
        print_status "SUCCESS" "Watchdog started (PID: $wpid)"
        print_status "INFO" "Log file: $VM_DIR/$vm_name.watchdog.log"
    else
        print_status "ERROR" "Failed to start watchdog"
        return 1
    fi
}

# Function to stop VM watchdog
stop_vm_watchdog() {
    local vm_name=$1
    local watchdog_pid_file="$VM_DIR/$vm_name.watchdog.pid"

    if [[ -f "$watchdog_pid_file" ]]; then
        local wpid=$(cat "$watchdog_pid_file")
        if kill -0 "$wpid" 2>/dev/null; then
            kill "$wpid" 2>/dev/null
            rm -f "$watchdog_pid_file"
            print_status "SUCCESS" "Watchdog for $vm_name stopped"
        else
            rm -f "$watchdog_pid_file"
            print_status "INFO" "Watchdog was not running"
        fi
    else
        print_status "INFO" "No watchdog running for $vm_name"
    fi
}

# Function to show VM performance metrics
show_vm_performance() {
    local vm_name=$1

    if load_vm_config "$vm_name"; then
        if is_vm_running "$vm_name"; then
            print_status "INFO" "Performance metrics for VM: $vm_name"
            echo "=========================================="

            # Get QEMU process ID
            local qemu_pid=$(pgrep -f "qemu-system-x86_64.*$IMG_FILE")
            if [[ -n "$qemu_pid" ]]; then
                # Show process stats
                echo "QEMU Process Stats:"
                ps -p "$qemu_pid" -o pid,%cpu,%mem,sz,rss,vsz,cmd --no-headers
                echo

                # Show memory usage
                echo "Memory Usage:"
                free -h
                echo

                # Show disk usage
                echo "Disk Usage:"
                df -h "$IMG_FILE" 2>/dev/null || du -h "$IMG_FILE"
            else
                print_status "ERROR" "Could not find QEMU process for VM $vm_name"
            fi
        else
            print_status "INFO" "VM $vm_name is not running"
            echo "Configuration:"
            echo "  Memory: $MEMORY MB"
            echo "  CPUs: $CPUS"
            echo "  Disk: $DISK_SIZE"
        fi
        echo "=========================================="
        read -p "$(print_status "INPUT" "Press Enter to continue...")"
    fi
}

# Main menu function
main_menu() {
    while true; do
        display_header

        local vms=($(get_vm_list))
        local vm_count=${#vms[@]}

        if [ $vm_count -gt 0 ]; then
            print_status "INFO" "Found $vm_count existing VM(s):"
            for i in "${!vms[@]}"; do
                local status="Stopped"
                local watchdog_status=""
                if is_vm_running "${vms[$i]}"; then
                    status="Running"
                fi
                # Check if watchdog is active
                if [[ -f "$VM_DIR/${vms[$i]}.watchdog.pid" ]]; then
                    local wpid=$(cat "$VM_DIR/${vms[$i]}.watchdog.pid" 2>/dev/null)
                    if [[ -n "$wpid" ]] && kill -0 "$wpid" 2>/dev/null; then
                        watchdog_status=" [Watchdog]"
                    fi
                fi
                printf "  %2d) %s (%s%s)\n" $((i+1)) "${vms[$i]}" "$status" "$watchdog_status"
            done
            echo
        fi

        echo "Main Menu:"
        echo "  1) Create a new VM"
        if [ $vm_count -gt 0 ]; then
            echo "  2) Start a VM"
            echo "  3) Stop a VM"
            echo "  4) Show VM info"
            echo "  5) Edit VM configuration"
            echo "  6) Delete a VM"
            echo "  7) Resize VM disk"
            echo "  8) Show VM performance"
            echo "  9) Convert VM to QCOW2"
            echo " 10) Start VM watchdog (auto-restart)"
            echo " 11) Stop VM watchdog"
        fi
        echo " 12) Convert ISO to QCOW2"
        echo "  0) Exit"
        echo

        read -p "$(print_status "INPUT" "Enter your choice: ")" choice

        case $choice in
            1)
                create_new_vm
                ;;
            2)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "Enter VM number to start: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        start_vm "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "Invalid selection"
                    fi
                fi
                ;;
            3)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "Enter VM number to stop: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        stop_vm "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "Invalid selection"
                    fi
                fi
                ;;
            4)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "Enter VM number to show info: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        show_vm_info "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "Invalid selection"
                    fi
                fi
                ;;
            5)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "Enter VM number to edit: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        edit_vm_config "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "Invalid selection"
                    fi
                fi
                ;;
            6)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "Enter VM number to delete: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        delete_vm "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "Invalid selection"
                    fi
                fi
                ;;
            7)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "Enter VM number to resize disk: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        resize_vm_disk "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "Invalid selection"
                    fi
                fi
                ;;
            8)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "Enter VM number to show performance: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        show_vm_performance "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "Invalid selection"
                    fi
                fi
                ;;
            9)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "Enter VM number to convert to QCOW2: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        convert_vm_to_qcow2 "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "Invalid selection"
                    fi
                fi
                ;;
            10)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "Enter VM number to start watchdog: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        read -p "$(print_status "INPUT" "Check interval in seconds (default: 30): ")" interval
                        interval="${interval:-30}"
                        start_vm_watchdog "${vms[$((vm_num-1))]}" "$interval"
                    else
                        print_status "ERROR" "Invalid selection"
                    fi
                fi
                ;;
            11)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "Enter VM number to stop watchdog: ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        stop_vm_watchdog "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "Invalid selection"
                    fi
                fi
                ;;
            12)
                convert_iso_to_qcow2
                ;;
            0)
                print_status "INFO" "Goodbye!"
                exit 0
                ;;
            *)
                print_status "ERROR" "Invalid option"
                ;;
        esac

        read -p "$(print_status "INPUT" "Press Enter to continue...")"
    done
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Check dependencies
check_dependencies

# Initialize paths
VM_DIR="${VM_DIR:-$HOME/vms}"
mkdir -p "$VM_DIR"

# ========================================================================
# SUPPORTED OPERATING SYSTEMS - 36 TOTAL
# ========================================================================
#
# All Available Operating Systems:
#
# === Alpine Linux (4) ===
#   1. Alpine Linux 3.23.2 - Latest version
#   2. Alpine Linux Latest (3.23) - Latest stable
#   3. Alpine Linux 3.21.5
#   4. Alpine Linux 3.20.8
#
# === Ubuntu (5) ===
#   5. Ubuntu 25.04 LTS - Plucky
#   6. Ubuntu 24.04 - Noble
#   7. Ubuntu 22.04 - Jammy
#   8. Ubuntu 20.04 - Focal
#   9. Ubuntu 18.04 - Bionic
#
# === Debian (3) ===
#   10. Debian 13 - Trixie (daily builds)
#   11. Debian 12 - Bookworm
#   12. Debian 11 - Bullseye
#
# === Fedora (4) ===
#   13. Fedora 43
#   14. Fedora 42
#   15. Fedora 41
#   16. Fedora 40
#
# === CentOS (2) ===
#   17. CentOS Stream 10
#   18. CentOS Stream 9
#
# === AlmaLinux (2) ===
#   19. AlmaLinux 9
#   20. AlmaLinux 8
#
# === Rocky Linux (2) ===
#   21. Rocky Linux 9
#   22. Rocky Linux 8
#
# === openSUSE (2) ===
#   23. openSUSE Tumbleweed - Rolling release
#   24. openSUSE Leap 15.6
#
# === Other Linux (5) ===
#   25. Arch Linux - Rolling release
#   26. Kali Linux - Rolling release (2025.4)
#   27. Parrot OS Security 7.0 - Latest security edition
#   28. Parrot OS Home 7.0 - Latest home edition
#   29. Gentoo Linux - OpenStack cloud image
#
# === Oracle Linux (2) ===
#   30. Oracle Linux 9 - ISO format
#   31. Oracle Linux 8 - ISO format
#
# === BSD Systems (3) ===
#   32. FreeBSD 15
#   33. OpenBSD 7.8
#   34. NetBSD 10.1
#
# === Windows (2) ===
#   35. Windows 11 - Docker-based
#   36. Windows 10 - Docker-based
#
# ========================================================================
# Format: ["Display Name"]="os_type|codename|image_url|hostname|username|password"
# ========================================================================
declare -A OS_OPTIONS=(
    # === Alpine Linux ===
    ["Alpine Linux 3.23.2"]="alpine|3.23|https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/cloud/nocloud_alpine-3.23.2-x86_64-bios-cloudinit-r0.qcow2|alpine323|alpine|alpine"
    ["Alpine Linux Latest (3.23)"]="alpine|latest|https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/cloud/nocloud_alpine-3.23.2-x86_64-bios-cloudinit-r0.qcow2|alpine-latest|alpine|alpine"
    ["Alpine Linux 3.21"]="alpine|3.21|https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/cloud/nocloud_alpine-3.21.5-x86_64-bios-cloudinit-r0.qcow2|alpine321|alpine|alpine"
    ["Alpine Linux 3.20"]="alpine|3.20|https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/cloud/nocloud_alpine-3.20.8-x86_64-bios-cloudinit-r0.qcow2|alpine320|alpine|alpine"

    # === Ubuntu ===
    ["Ubuntu 25.04 LTS"]="ubuntu|plucky|https://cloud-images.ubuntu.com/plucky/current/plucky-server-cloudimg-amd64.img|ubuntu25|ubuntu|ubuntu"
    ["Ubuntu 24.04"]="ubuntu|noble|https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img|ubuntu24|ubuntu|ubuntu"
    ["Ubuntu 22.04"]="ubuntu|jammy|https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img|ubuntu22|ubuntu|ubuntu"
    ["Ubuntu 20.04"]="ubuntu|focal|https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img|ubuntu20|ubuntu|ubuntu"
    ["Ubuntu 18.04"]="ubuntu|bionic|https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img|ubuntu18|ubuntu|ubuntu"

    # === Debian ===
    ["Debian 13"]="debian|trixie|https://cloud.debian.org/images/cloud/trixie/daily/latest/debian-13-generic-amd64-daily.qcow2|debian13|debian|debian"
    ["Debian 12"]="debian|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|debian12|debian|debian"
    ["Debian 11"]="debian|bullseye|https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2|debian11|debian|debian"

    # === Fedora ===
    ["Fedora 43"]="fedora|43|https://download.fedoraproject.org/pub/fedora/linux/releases/43/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-43-1.6.x86_64.qcow2|fedora43|fedora|fedora"
    ["Fedora 42"]="fedora|42|https://download.fedoraproject.org/pub/fedora/linux/releases/42/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-42-1.1.x86_64.qcow2|fedora42|fedora|fedora"
    ["Fedora 41"]="fedora|41|https://download.fedoraproject.org/pub/fedora/linux/releases/41/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-41-1.4.x86_64.qcow2|fedora41|fedora|fedora"
    ["Fedora 40"]="fedora|40|https://download.fedoraproject.org/pub/fedora/linux/releases/40/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-40-1.14.x86_64.qcow2|fedora40|fedora|fedora"

    # === CentOS ===
    ["CentOS Stream 10"]="centos|stream10|https://cloud.centos.org/centos/10-stream/x86_64/images/CentOS-Stream-GenericCloud-10-latest.x86_64.qcow2|centos10|centos|centos"
    ["CentOS Stream 9"]="centos|stream9|https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2|centos9|centos|centos"

    # === AlmaLinux ===
    ["AlmaLinux 9"]="almalinux|9|https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2|almalinux9|alma|alma"
    ["AlmaLinux 8"]="almalinux|8|https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2|almalinux8|alma|alma"

    # === Rocky Linux ===
    ["Rocky Linux 9"]="rockylinux|9|https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2|rocky9|rocky|rocky"
    ["Rocky Linux 8"]="rockylinux|8|https://download.rockylinux.org/pub/rocky/8/images/x86_64/Rocky-8-GenericCloud-Base.latest.x86_64.qcow2|rocky8|rocky|rocky"

    # === openSUSE ===
    ["openSUSE Tumbleweed"]="opensuse|tumbleweed|https://download.opensuse.org/tumbleweed/appliances/openSUSE-Tumbleweed-Minimal-VM.x86_64-Cloud.qcow2|opensusetw|opensuse|opensuse"
    ["openSUSE Leap 15.6"]="opensuse|leap156|https://download.opensuse.org/distribution/leap/15.6/appliances/openSUSE-Leap-15.6-Minimal-VM.x86_64-Cloud.qcow2|opensuse156|opensuse|opensuse"

    # === Other Linux ===
    ["Arch Linux"]="arch|rolling|https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2|archlinux|arch|arch"
    ["Kali Linux"]="kali|rolling|https://kali.download/cloud-images/current/kali-linux-2025.4-cloud-genericcloud-amd64.tar.xz|kali|kali|kali"
    ["Parrot OS Security 7.0"]="parrot|7.0|https://deb.parrot.sh/direct/parrot/iso/7.0/Parrot-security-7.0_amd64.qcow2|parrot|parrot|parrot"
    ["Parrot OS Home 7.0"]="parrot|7.0-home|https://deb.parrot.sh/direct/parrot/iso/7.0/Parrot-home-7.0_amd64.qcow2|parrot-home|parrot|parrot"
    ["Gentoo Linux"]="gentoo|openstack|https://distfiles.gentoo.org/releases/amd64/autobuilds/latest-cloud-amd64-openstack.txt|gentoo|gentoo|gentoo"

    # === Oracle Linux ===
    ["Oracle Linux 9"]="oracle|9|https://yum.oracle.com/ISOS/OracleLinux/OL9/u5/x86_64/OracleLinux-R9-U5-x86_64-dvd.iso|oracle9|oracle|oracle"
    ["Oracle Linux 8"]="oracle|8|https://yum.oracle.com/ISOS/OracleLinux/OL8/u10/x86_64/OracleLinux-R8-U10-x86_64-dvd.iso|oracle8|oracle|oracle"

    # === BSD Systems ===
    ["FreeBSD 15"]="freebsd|15|https://download.freebsd.org/releases/VM-IMAGES/15.0-RELEASE/amd64/Latest/FreeBSD-15.0-RELEASE-amd64-BASIC-CLOUDINIT-ufs.qcow2.xz|freebsd15|freebsd|freebsd"
    ["OpenBSD 7.8"]="openbsd|78|https://cdn.openbsd.org/pub/OpenBSD/7.8/amd64/install78.img|openbsd78|openbsd|openbsd"
    ["NetBSD 10.1"]="netbsd|101|https://cdn.netbsd.org/pub/NetBSD/NetBSD-10.1/images/NetBSD-10.1-amd64.img|netbsd101|netbsd|netbsd"

    # === Windows ===
    ["Windows 11"]="windows|win11|docker|windows11|Administrator|password"
    ["Windows 10"]="windows|win10|docker|windows10|Administrator|password"
)

# Start the main menu
main_menu
