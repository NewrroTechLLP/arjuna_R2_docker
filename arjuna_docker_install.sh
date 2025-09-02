#!/bin/bash
set -e

# The SUDO_PASSWORD variable is now expected to be passed from the parent script

echo "[WRAPPER] Running VS Code setup as user..."
echo "$SUDO_PASSWORD" | sudo -S bash ~/arjuna_R2_docker/arjuna_docker_prereq.sh

echo "[WRAPPER] Running docker+GPU setup as root..."
echo "$SUDO_PASSWORD" | sudo -S bash ~/arjuna_R2_docker/arjuna_docker_build.sh

echo "[WRAPPER] All done ✅"
