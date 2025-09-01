#!/bin/bash
set -e

# Prompt for the user's sudo password at the start
read -s -p "Enter your password: " SUDO_PASSWORD
echo

echo "[WRAPPER] Running VS Code setup as user..."
./arjuna_docker_prereq.sh

echo "[WRAPPER] Running docker+GPU setup as root..."
echo "$SUDO_PASSWORD" | sudo -S ./arjuna_docker_build.sh

echo "[WRAPPER] All done ✅"

