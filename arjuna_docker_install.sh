#!/bin/bash
set -e


echo "[WRAPPER] Running VS Code setup as user..."
sudo bash ~/arjuna_R2_docker/arjuna_docker_prereq.sh

echo "[WRAPPER] Running docker+GPU setup as root..."
sudo bash ~/arjuna_R2_docker/arjuna_docker_build.sh

echo "[WRAPPER] All done ✅"
