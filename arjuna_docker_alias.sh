#!/bin/bash

set -e
set -o pipefail

echo "[INFO] Setting up ros2arjuna Docker helper functions..."

# --- Check if Docker daemon is running ---
if ! systemctl is-active --quiet docker; then
    echo "[INFO] Docker daemon is not running. Starting Docker..."
    sudo systemctl start docker
    if ! systemctl is-active --quiet docker; then
        echo "[ERROR] Failed to start Docker daemon. Please start it manually."
        exit 1
    fi
fi

# --- Determine shell RC file ---
SHELL_RC="$HOME/.bashrc"

# --- Docker helper functions ---
DOCKER_ALIAS_BLOCK=$(cat <<'EOF'

# --- BEGIN ROS2ARJUNA HELPERS ---
ros2arjuna() {
    if ! sudo docker ps -a --format '{{.Names}}' | grep -q '^arjuna_dev$'; then
        echo "[INFO] Container 'arjuna_dev' not found. Creating it..."
        sudo docker run -it --name arjuna_dev \
            --runtime nvidia \
            --network host \
            --env NVIDIA_VISIBLE_DEVICES=all \
            --env NVIDIA_DRIVER_CAPABILITIES=all \
            --volume /usr/local/cuda:/usr/local/cuda \
            --volume "$HOME/arjuna2_ws:/root/arjuna2_ws" \
            arjuna_v2
    else
        echo "[INFO] Starting existing container 'arjuna_dev'..."
        sudo docker start -ai arjuna_dev
    fi
}

ros2arjuna_ext() {
    if sudo docker ps -a --format '{{.Names}}' | grep -q '^arjuna_dev$'; then
        sudo docker exec -it arjuna_dev bash
    else
        echo "[ERROR] Container 'arjuna_dev' does not exist. Run 'ros2arjuna' first."
    fi
}

ros2arjuna_commit() {
    if sudo docker ps -a --format '{{.Names}}' | grep -q '^arjuna_dev$'; then
        echo "[INFO] Stopping container 'arjuna_dev' (if running)..."
        sudo docker stop arjuna_dev 2>/dev/null || true

        echo "[INFO] Committing changes from container 'arjuna_dev' to image 'arjuna_v2'..."
        sudo docker commit arjuna_dev arjuna_v2

        echo "[INFO] Removing old container..."
        sudo docker rm arjuna_dev 2>/dev/null || true

        echo "[INFO] Done ✅. Next time you run 'ros2arjuna', it will use the updated image."
    else
        echo "[ERROR] Container 'arjuna_dev' does not exist. Nothing to commit."
    fi
}
# --- END ROS2ARJUNA HELPERS ---
EOF
)

# --- Append to shell rc file if not already present ---
if grep -q "BEGIN ROS2ARJUNA HELPERS" "$SHELL_RC"; then
    echo "[INFO] Docker helper functions already exist in $SHELL_RC"
else
    echo "$DOCKER_ALIAS_BLOCK" >> "$SHELL_RC"
    echo "[INFO] Docker helper functions added to $SHELL_RC"
    echo "[INFO] Run 'source $SHELL_RC' or restart your shell to activate them."
fi
