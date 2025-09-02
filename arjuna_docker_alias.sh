#!/bin/bash

set -e
set -o pipefail

echo "[INFO] Adding docker run alias to the bash...."

echo ""
echo ""

# --- Check if Docker daemon is running ---
if ! systemctl is-active --quiet docker; then
  echo "Docker daemon is not running. Starting docker..."
  sudo systemctl start docker
  if ! systemctl is-active --quiet docker; then
    echo "Failed to start Docker daemon. Please start it manually."
    exit 1
  fi
fi

# --- Add alias and function to shell rc file ---
SHELL_RC="$HOME/.bashrc"  # change to ~/.zshrc if using Zsh

echo ""
echo ""

# Define the alias/function block
read -r -d '' DOCKER_ALIAS_BLOCK <<'EOF'

ros2arjuna() {
  if ! sudo docker ps -a --format '{{.Names}}' | grep -q '^arjuna_dev$'; then
    echo "Container 'arjuna_dev' not found. Creating it..."
    sudo docker run -it --name arjuna_dev \
      --runtime nvidia \
      --network host \
      --env NVIDIA_VISIBLE_DEVICES=all \
      --env NVIDIA_DRIVER_CAPABILITIES=all \
      --volume /usr/local/cuda:/usr/local/cuda \
      --volume "$HOME/ros2_ws:/root/ros2_ws" \
      arjuna_v2
  else
    echo "Starting existing container 'arjuna_dev'..."
    sudo docker start -ai arjuna_dev
  fi
}

ros2arjuna_ext() {
  sudo docker exec -it arjuna_dev bash
}

ros2arjuna_commit() {
  echo "Stopping container arjuna_dev (if running)..."
  sudo docker stop arjuna_dev 2>/dev/null || true

  echo "Committing changes from container 'arjuna_dev' to image 'arjuna_v2'..."
  sudo docker commit arjuna_dev arjuna_v2

  echo "Removing old container..."
  sudo docker rm arjuna_dev 2>/dev/null || true

  echo "Done ✅. Next time you run 'ros2arjuna', it will use the updated image."
}


EOF

# Check if the alias/function is already defined in rc file
if grep -q "ros2arjuna()" "$SHELL_RC"; then
  echo "Alias/function 'ros2arjuna' already exists in $SHELL_RC"
else
  echo "Adding alias/function 'ros2arjuna' to $SHELL_RC"
  echo "$DOCKER_ALIAS_BLOCK" >> "$SHELL_RC"
  echo "Please run 'source $SHELL_RC' or restart your shell to enable the alias."
fi
