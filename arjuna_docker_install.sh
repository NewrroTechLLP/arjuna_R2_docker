#!/bin/bash
set -e

read -s -p "Enter your sudo password: " SUDO_PASSWORD
echo

echo "[WRAPPER] Running VS Code setup as user..."
echo "$SUDO_PASSWORD" | sudo -S ./arjuna_docker_prereq.sh

echo "[WRAPPER] Running docker+GPU setup as root..."
echo "$SUDO_PASSWORD" | sudo -S ./arjuna_docker_build.sh

echo "[WRAPPER] All done ✅"
