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

# Alias to run ROS2 Foxy container named "arjuna_v2"
ros2arjuna() {
  # Run container with GPU, volumes, network
  # Start container interactively
  # Save changes on exit by committing container to image

  # Generate a random container name to avoid conflicts
  local container_name="arjuna_temp_$(date +%s)"

  sudo docker run -it --name "$container_name" --runtime nvidia --network host --env NVIDIA_VISIBLE_DEVICES=all --env NVIDIA_DRIVER_CAPABILITIES=all --volume /usr/local/cuda:/usr/local/cuda --volume "$HOME/ros2_ws:/root/ros2_ws" arjuna_v2

  # After container exits, commit changes back to image
  echo "Committing container changes to image 'arjuna_v2'..."
  sudo docker commit "$container_name" arjuna_v2
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
