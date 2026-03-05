#!/usr/bin/bash

# --- CONFIGURATION ---
container_name="isaac_sim_ws"
ros_distro=humble

# Dependencies for Isaac Sim (Vulkan, Audio, UI) + Standard tools
isaac_dependencies="libnss3 libatk-bridge2.0-0 libasound2 libxt6 libxft2 libsndfile1 libvulkan1 vulkan-tools libgomp1 libxcursor1 libxinerama1 libxrandr2 libxi6 libglu1-mesa libsm6 libice6 libxrender1 libfontconfig1 libgl1-mesa-glx build-essential cmake gdb"
additional_packages="iputils-ping nano vim alsa-utils alsa pulseaudio git git-man python3 python-is-python3 python3-pip usbutils wget unzip $isaac_dependencies"

if [[ $ros_distro != "humble" ]]; then
    additional_packages="$additional_packages unminimize"
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
ws_dir="$(cd "$script_dir/.." && pwd)"
distrobox_home="$ws_dir/.distrobox"

# --- PRE-CHECKS ---

# Install flatpak if missing
if ! command -v flatpak &> /dev/null; then
    echo "Installing flatpak..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y flatpak
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm flatpak
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y flatpak
    else
        echo "Unsupported platform. Please install flatpak manually."
        exit 1
    fi
fi

# Check if THIS specific container already exists
if [[ ! -d $distrobox_home ]]; then
    if [[ $(distrobox list --no-color | tr -s ' ' | cut -d ' ' -f 3 | grep "^$container_name$" | wc -l) -ne 0 ]]; then
        echo "The container '$container_name' exists, but its home directory ($distrobox_home) is missing."
        echo "This usually means a broken configuration."
        read -p "Do you want to delete '$container_name' and start over? (Y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
        distrobox stop --yes $container_name
        distrobox rm --force $container_name
    fi

    echo "Creating NEW Distrobox instance: $container_name ..."
    echo "Location: $distrobox_home"
    
    mkdir -p "$distrobox_home"
    touch "$distrobox_home/.sudo_as_admin_successful"

    # Link Git and SSH from host
    if [[ -f $HOME/.gitconfig ]]; then ln -s $HOME/.gitconfig "$distrobox_home/.gitconfig"; fi
    if [[ -d $HOME/.ssh ]]; then ln -s $HOME/.ssh "$distrobox_home/.ssh"; fi

    # NVIDIA Configuration
    additional_flags="--mount type=bind,source=/dev/bus/usb,target=/dev/bus/usb"
    
    if [[ $(lspci | grep -i nvidia | wc -l) -ne 0 ]]; then
        nvidia="--nvidia"
        # Enable Ray Tracing support for Isaac Sim
        additional_flags="$additional_flags --env NVIDIA_VISIBLE_DEVICES=all --env NVIDIA_DRIVER_CAPABILITIES=all"
    else
        echo "WARNING: No NVIDIA GPU detected. Isaac Sim will likely fail."
        nvidia=""
    fi

    # Create the Distrobox
    distrobox create --image docker.io/osrf/ros:$ros_distro-desktop-full \
        --yes \
        --name $container_name \
        --home "$distrobox_home" \
        --additional-packages "$additional_packages" \
        --absolutely-disable-root-password-i-am-really-positively-sure \
        --init-hooks "chsh -s /usr/bin/bash $USER && (yes | sudo unminimize)" \
        $nvidia \
        --no-entry \
        --additional-flags "$additional_flags"

    if [[ $? -ne 0 ]]; then
        echo "Failed to create Distrobox instance."
        # Clean up the directory if creation failed
        rm -r "$distrobox_home"
        exit 1
    fi

    # Setup .bashrc
    if [[ -f "$script_dir/distrobox-template.bashrc" ]]; then
        cp "$script_dir/distrobox-template.bashrc" "$distrobox_home/.bashrc"
        sed -i "s/\"<<<ROS_DISTRO_TEMPLATE_SUBSTITUTION>>>\"/$ros_distro/g" "$distrobox_home/.bashrc"
    else
        echo "source /opt/ros/$ros_distro/setup.bash" > "$distrobox_home/.bashrc"
    fi

    # Add Isaac Sim specific environment variables
    {
        echo ""
        echo "# --- Isaac Sim ---"
        echo "export ISAAC_SIM_PATH=\$HOME/isaac-sim"
        echo "alias run_isaac='\$ISAAC_SIM_PATH/isaac-sim.sh'"
    } >> "$distrobox_home/.bashrc"

    echo "--------------------------------------------------------"
    echo "Container '$container_name' created!"
    echo "Location: $distrobox_home"
    echo "--------------------------------------------------------"
fi

# Enter the new container
distrobox enter $container_name
