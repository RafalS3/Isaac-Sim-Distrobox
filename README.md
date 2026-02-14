# Isaac-Sim-Distrobox
A hassle-free environment for running **NVIDIA Isaac Sim** and **ROS 2 Humble** on Linux distributions that aren't natively supported.

## Features
* Runs Ubuntu 22.04 
* Pre-configured environment variables to prevent Python crashes.
* Custom launch scripts to run Isaac Sim 
* Ready for WebRTC or Native Streaming.

## Prerequisites
* `distrobox` & `docker` (or `podman`)
* **NVIDIA Isaac Sim** (Linux .zip version) downloaded from [NVIDIA Omniverse](https://developer.nvidia.com/isaac-sim)

## Setup
1. To Setup Distrobox with ROS 2 Humble
Run `isaac_distrobox_init.sh`  script to create the container with all necessary dependencies and GPU drivers.


2. Configure Your Shell
Copy this function into your ~/.bashrc inside the container.
```bash
run_isaac() {  
    #Points to the internal library provided by Isaac Sim

   Unset system ROS variables that confuse Isaac Sim
    unset ROS_DISTRO
    unset ROS_VERSION
    unset ROS_PYTHON_VERSION
    unset AMENT_PREFIX_PATH
    unset CMAKE_PREFIX_PATH
    unset PYTHONPATH
    BRIDGE_LIB_PATH="$HOME/isaac-sim/exts/isaacsim.ros2.bridge/humble/lib"
    
    #Reset LD_LIBRARY_PATH
    export LD_LIBRARY_PATH="/usr/lib:/usr/local/lib:$BRIDGE_LIB_PATH"

    #Set the Middleware
    export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

    #Launch
    echo "Launching Isaac Sim..."
    "$HOME/isaac-sim/isaac-sim.sh" "$@"
}
```
## Usage
```bash
distrobox enter isaac_sim_ws
```
To run Issac sim use 
```bash
run_isaac
```
