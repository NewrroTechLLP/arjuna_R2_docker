#! /bin/bash

set -e
set -o pipefail

echo "=== Arjuna Docker Build Script with Jetson Fixes ==="

echo ""
echo "#####################################"
echo "#    Install Docker (if missing)    #"
echo "#####################################"

if ! command -v docker &> /dev/null; then
  echo "=== Installing Docker ==="
  sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository \
     "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/ubuntu \
     $(lsb_release -cs) stable"
  sudo apt-get update -y
  sudo apt-get install -y docker-ce
  sudo systemctl enable docker
  sudo systemctl start docker
else
  echo "=== Docker already installed ==="
fi

echo "############################################################"
echo "### Part2: Starting FULL NVIDIA Docker + ROS2 Foxy Setup ###"
echo "############################################################"

echo ""
echo ""

# --- Step 0: Purge old Docker & NVIDIA container toolkit/runtime ---

echo "[Step 0] Removing old Docker and NVIDIA toolkit/runtime if any..."
echo ""
echo ""
sudo apt-get purge -y docker docker-engine docker.io containerd runc || true
sudo apt-get purge -y nvidia-container-toolkit nvidia-container-runtime || true
sudo rm -f /etc/apt/sources.list.d/docker.list
sudo rm -f /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo rm -f /etc/apt/sources.list.d/nvidia-container-runtime.list
sudo rm -f /etc/docker/daemon.json

echo ""
echo ""

echo "Cleaning leftover Docker files..."
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd

# --- Step 1: Install Docker Engine ---

echo ""
echo ""

echo "[Step 1] Installing Docker Engine..."
echo ""
echo ""
sudo apt-get update
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common \
    gnupg-agent \
    lsb-release

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

USER_TO_ADD=${SUDO_USER:-$USER}
echo "Adding user ($USER_TO_ADD) to docker group..."
sudo usermod -aG docker $USER_TO_ADD


echo ""
echo ""
# --- Step 2: Install NVIDIA Container Toolkit ---

echo "[Step 2] Installing NVIDIA Container Toolkit..."
echo ""
echo "=== Configuring NVIDIA container repositories ==="
echo ""
echo ""

# Detect distribution (e.g. ubuntu18.04) and architecture (arm64 for Jetson)
distribution=$(. /etc/os-release; echo ${ID}${VERSION_ID})
arch=$(dpkg --print-architecture)

# Create keyrings directory
sudo mkdir -p /usr/share/keyrings

# Download NVIDIA GPG key
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
    sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit.gpg

# Add NVIDIA libnvidia-container repo with signed-by + arch substitution
curl -s -L https://nvidia.github.io/libnvidia-container/${distribution}/libnvidia-container.list | \
    sed "s#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit.gpg] https://#g" | \
    sed "s#\$ARCH#${arch}#g" | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null

# Update and install
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit nvidia-container-runtime

echo ""
echo ""

echo "=== NVIDIA container runtime setup complete ==="

# --- Step 3: Configure Docker daemon for NVIDIA runtime ---

echo ""
echo ""

echo "[Step 3] Configuring Docker daemon to use NVIDIA runtime by default..."

sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "default-runtime": "nvidia",
  "runtimes": {
    "nvidia": {
      "path": "nvidia-container-runtime",
      "runtimeArgs": []
    }
  }
}
EOF

echo "Restarting Docker daemon..."
sudo systemctl daemon-reload
sudo systemctl restart docker

echo ""
echo ""

# --- Step (Optional): NVIDIA NGC login ---

#NGC_API_KEY="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"
#echo "$NGC_API_KEY" | sudo docker login nvcr.io --username '$oauthtoken' --password-stdin

# --- Step 4: Create folder arjuna and Dockerfile ---

echo "[Step 4] Creating directory ~/arjuna and Dockerfile..."

mkdir -p ~/arjuna_R2_docker/Arjuna

# This Dockerfile starts from a proper Ubuntu 20.04-based L4T image
# and avoids the problematic do-release-upgrade command.
cat <<'EOF' > ~/arjuna_R2_docker/Arjuna/Dockerfile
# Dockerfile
FROM arm64v8/ubuntu:20.04

LABEL maintainer="support@newrro.in"

ENV DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all

SHELL ["/bin/bash", "-c"]

# Install essential packages
RUN apt-get update -o Acquire::Retries=5 && apt-get install -y \
    lsb-release \
    gnupg2 \
    curl \
    wget \
    git \
    sudo \
    locales \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Set locale
RUN locale-gen en_US en_US.UTF-8 && \
    update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

# ROS 2 Foxy setup
RUN apt-get update -o Acquire::Retries=5 && apt-get install -y curl gnupg2 lsb-release

RUN curl -sSL http://repo.ros2.org/repos.key | apt-key add - && \
    add-apt-repository universe && \
    echo "deb [arch=arm64] http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" > /etc/apt/sources.list.d/ros2-latest.list

RUN apt-get update -o Acquire::Retries=5 && apt-get install -y \
    ros-foxy-desktop \
    python3-colcon-common-extensions \
    python3-pip \
    python3-argcomplete \
    && rm -rf /var/lib/apt/lists/*

# Extra Python tools for ROS 2
RUN pip3 install -U \
    pyserial \
    serial \
    argcomplete \
    flake8 \
    flake8-blind-except \
    flake8-builtins \
    flake8-class-newline \
    flake8-comprehensions \
    flake8-deprecated \
    flake8-docstrings \
    flake8-import-order \
    flake8-quotes \
    mypy \
    pep8 \
    pydocstyle \
    pyflakes \
    pytest-repeat \
    pytest-rerunfailures \
    pytest \
    setuptools \
    opencv-python \
    zbar \


RUN pip3 install \
    opencv-python \
    numpy \
    pyzbar \
    pillow \
    scikit-image \
    matplotlib \
    imutils \
    pyyaml \
    tqdm \
    requests \
    torch torchvision torchaudio \
    tensorflow



RUN python3 -m pip install --upgrade pip
RUN pip3 install --upgrade importlib-metadata
RUN pip3 install setuptools==58.2.0
RUN apt update && \
    apt install -y nano && \
    apt clean
RUN apt install -y i2c-tools

# 👇 Source ROS automatically when container starts
RUN echo "source /opt/ros/foxy/setup.bash" >> /root/.bashrc

WORKDIR /root/ 

# Add ros2arjuna_setup function to .bashrc
###############################################################################
# DOCKERFILE - ONLY SYSTEM PACKAGES (NO ROS, NO PYTHON LIBS VIA PIP)
###############################################################################

# System packages ONLY - bare essentials
RUN apt-get update -o Acquire::Retries=5 && apt-get install -y \
    libopencv-dev \
    libzbar0 \
    libzbar-dev \
    minicom \
    setserial \
    libi2c-dev \
    portaudio19-dev \
    alsa-utils \
    pulseaudio \
    espeak \
    flac \
    nginx \
    net-tools \
    iputils-ping \
    wireless-tools \
    vim \
    cmake \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

###############################################################################
# ENHANCED ros2arjuna_setup FUNCTION - INSTALLS EVERYTHING
###############################################################################

RUN echo "ros2arjuna_setup() {" >> /root/.bashrc && \
    echo "  echo '==========================================='" >> /root/.bashrc && \
    echo "  echo '  ARJUNA SETUP - INSTALLING ALL DEPENDENCIES'" >> /root/.bashrc && \
    echo "  echo '==========================================='" >> /root/.bashrc && \
    echo "" >> /root/.bashrc && \
    \
    echo "  # ============ ROS 2 PACKAGES ============" >> /root/.bashrc && \
    echo "  echo 'Installing ROS 2 packages...'" >> /root/.bashrc && \
    echo "  sudo apt update" >> /root/.bashrc && \
    echo "  sudo apt install -y \\" >> /root/.bashrc && \
    echo "    ros-foxy-nav2-bringup \\" >> /root/.bashrc && \
    echo "    ros-foxy-nav2-lifecycle-manager \\" >> /root/.bashrc && \
    echo "    ros-foxy-nav2-map-server \\" >> /root/.bashrc && \
    echo "    ros-foxy-navigation2 \\" >> /root/.bashrc && \
    echo "    ros-foxy-nav2-common \\" >> /root/.bashrc && \
    echo "    ros-foxy-slam-toolbox \\" >> /root/.bashrc && \
    echo "    ros-foxy-cartographer \\" >> /root/.bashrc && \
    echo "    ros-foxy-cartographer-ros \\" >> /root/.bashrc && \
    echo "    ros-foxy-robot-localization \\" >> /root/.bashrc && \
    echo "    ros-foxy-tf2-ros \\" >> /root/.bashrc && \
    echo "    ros-foxy-tf2-geometry-msgs \\" >> /root/.bashrc && \
    echo "    ros-foxy-tf2-tools \\" >> /root/.bashrc && \
    echo "    ros-foxy-robot-state-publisher \\" >> /root/.bashrc && \
    echo "    ros-foxy-teleop-twist-keyboard \\" >> /root/.bashrc && \
    echo "    ros-foxy-teleop-twist-joy \\" >> /root/.bashrc && \
    echo "    ros-foxy-rviz2 \\" >> /root/.bashrc && \
    echo "    ros-foxy-rviz-default-plugins \\" >> /root/.bashrc && \
    echo "    ros-foxy-rqt \\" >> /root/.bashrc && \
    echo "    ros-foxy-rqt-common-plugins \\" >> /root/.bashrc && \
    echo "    ros-foxy-cv-bridge \\" >> /root/.bashrc && \
    echo "    ros-foxy-vision-opencv \\" >> /root/.bashrc && \
    echo "    ros-foxy-image-transport \\" >> /root/.bashrc && \
    echo "    ros-foxy-compressed-image-transport \\" >> /root/.bashrc && \
    echo "    ros-foxy-joint-state-publisher \\" >> /root/.bashrc && \
    echo "    ros-foxy-xacro" >> /root/.bashrc && \
    echo "" >> /root/.bashrc && \
    \
    echo "  # ============ PYTHON PACKAGES VIA APT ============" >> /root/.bashrc && \
    echo "  echo 'Installing Python packages via apt...'" >> /root/.bashrc && \
    echo "  sudo apt install -y \\" >> /root/.bashrc && \
    echo "    python3-opencv \\" >> /root/.bashrc && \
    echo "    python3-numpy \\" >> /root/.bashrc && \
    echo "    python3-scipy \\" >> /root/.bashrc && \
    echo "    python3-matplotlib \\" >> /root/.bashrc && \
    echo "    python3-pil \\" >> /root/.bashrc && \
    echo "    python3-flask \\" >> /root/.bashrc && \
    echo "    python3-flask-cors \\" >> /root/.bashrc && \
    echo "    python3-requests \\" >> /root/.bashrc && \
    echo "    python3-yaml \\" >> /root/.bashrc && \
    echo "    python3-psutil \\" >> /root/.bashrc && \
    echo "    python3-pytest \\" >> /root/.bashrc && \
    echo "    python3-skimage" >> /root/.bashrc && \
    echo "" >> /root/.bashrc && \
    \
    echo "  # ============ PYTHON PACKAGES VIA PIP (NOT IN APT) ============" >> /root/.bashrc && \
    echo "  echo 'Installing Python packages via pip3...'" >> /root/.bashrc && \
    echo "  pip3 install --break-system-packages \\" >> /root/.bashrc && \
    echo "    pyzbar \\" >> /root/.bashrc && \
    echo "    qrcode \\" >> /root/.bashrc && \
    echo "    transforms3d \\" >> /root/.bashrc && \
    echo "    pyquaternion \\" >> /root/.bashrc && \
    echo "    RPi.GPIO \\" >> /root/.bashrc && \
    echo "    gpiozero \\" >> /root/.bashrc && \
    echo "    SpeechRecognition \\" >> /root/.bashrc && \
    echo "    pyttsx3 \\" >> /root/.bashrc && \
    echo "    playsound \\" >> /root/.bashrc && \
    echo "    flask-socketio \\" >> /root/.bashrc && \
    echo "    python-socketio \\" >> /root/.bashrc && \
    echo "    simple-pid \\" >> /root/.bashrc && \
    echo "    imutils \\" >> /root/.bashrc && \
    echo "    tqdm" >> /root/.bashrc && \
    echo "" >> /root/.bashrc && \
    \
    echo "  # ============ CLONE WORKSPACE ============" >> /root/.bashrc && \
    echo "  echo 'Cloning Arjuna workspace...'" >> /root/.bashrc && \
    echo "  cd /root/arjuna_ros2 && sudo rm -rf /root/arjuna2_ws/{*,.??*}" >> /root/.bashrc && \
    echo "  git clone --recurse-submodules https://github.com/samartha-s-in/arjuna2_ws.git" >> /root/.bashrc && \
    echo "" >> /root/.bashrc && \
    \
    echo "  # ============ CLONE HARDWARE DRIVERS ============" >> /root/.bashrc && \
    echo "  echo 'Cloning hardware drivers...'" >> /root/.bashrc && \
    echo "  cd /root/arjuna_ros2/arjuna2_ws/src" >> /root/.bashrc && \
    echo "  if [ ! -d 'sllidar_ros2' ]; then" >> /root/.bashrc && \
    echo "    git clone https://github.com/Slamtec/sllidar_ros2.git" >> /root/.bashrc && \
    echo "  fi" >> /root/.bashrc && \
    echo "  if [ ! -d 'bno055' ]; then" >> /root/.bashrc && \
    echo "    git clone https://github.com/flynneva/bno055.git" >> /root/.bashrc && \
    echo "  fi" >> /root/.bashrc && \
    echo "" >> /root/.bashrc && \
    \
    echo "  # ============ BUILD WORKSPACE ============" >> /root/.bashrc && \
    echo "  echo 'Building workspace...'" >> /root/.bashrc && \
    echo "  cd /root/arjuna_ros2/arjuna2_ws" >> /root/.bashrc && \
    echo "  source /opt/ros/foxy/setup.bash" >> /root/.bashrc && \
    echo "  colcon build --symlink-install" >> /root/.bashrc && \
    echo "  source /root/arjuna_ros2/arjuna2_ws/install/setup.bash" >> /root/.bashrc && \
    echo "" >> /root/.bashrc && \
    \
    echo "  # ============ VERIFY INSTALLATION ============" >> /root/.bashrc && \
    echo "  echo '==========================================='" >> /root/.bashrc && \
    echo "  echo '  CHECKING DEPENDENCIES'" >> /root/.bashrc && \
    echo "  echo '==========================================='" >> /root/.bashrc && \
    echo "  python3 -c 'import cv2; print(\"✓ OpenCV:\", cv2.__version__)' 2>/dev/null || echo '✗ OpenCV'" >> /root/.bashrc && \
    echo "  python3 -c 'import pyzbar; print(\"✓ pyzbar\")' 2>/dev/null || echo '✗ pyzbar'" >> /root/.bashrc && \
    echo "  python3 -c 'import transforms3d; print(\"✓ transforms3d\")' 2>/dev/null || echo '✗ transforms3d'" >> /root/.bashrc && \
    echo "  python3 -c 'import serial; print(\"✓ pyserial\")' 2>/dev/null || echo '✗ pyserial'" >> /root/.bashrc && \
    echo "  python3 -c 'import speech_recognition; print(\"✓ SpeechRecognition\")' 2>/dev/null || echo '✗ SpeechRecognition'" >> /root/.bashrc && \
    echo "  python3 -c 'import flask; print(\"✓ Flask\")' 2>/dev/null || echo '✗ Flask'" >> /root/.bashrc && \
    echo "  python3 -c 'import numpy; print(\"✓ NumPy:\", numpy.__version__)' 2>/dev/null || echo '✗ NumPy'" >> /root/.bashrc && \
    echo "  python3 -c 'import psutil; print(\"✓ psutil\")' 2>/dev/null || echo '✗ psutil'" >> /root/.bashrc && \
    echo "  echo '==========================================='" >> /root/.bashrc && \
    echo "  ros2 pkg list | grep -q slam_toolbox && echo '✓ SLAM Toolbox' || echo '✗ SLAM Toolbox'" >> /root/.bashrc && \
    echo "  ros2 pkg list | grep -q robot_localization && echo '✓ Robot Localization' || echo '✗ Robot Localization'" >> /root/.bashrc && \
    echo "  ros2 pkg list | grep -q nav2 && echo '✓ Nav2' || echo '✗ Nav2'" >> /root/.bashrc && \
    echo "  echo '==========================================='" >> /root/.bashrc && \
    echo "" >> /root/.bashrc && \
    \
    echo "  echo '==========================================='" >> /root/.bashrc && \
    echo "  echo '  ✓ ARJUNA SETUP COMPLETE'" >> /root/.bashrc && \
    echo "  echo '==========================================='" >> /root/.bashrc && \
    echo "  cd /root/" >> /root/.bashrc && \
    echo "}" >> /root/.bashrc && \
    echo "" >> /root/.bashrc

RUN echo "ros2arjuna_open() {" >> /root/.bashrc && \
    echo "    cd /root/arjuna_ros2/arjuna2_ws" >> /root/.bashrc && \
    echo "    code . --no-sandbox --user-data-dir="/root/.vscode"" >> /root/.bashrc && \
    echo "}" >> /root/.bashrc && \
    echo "" >> /root/.bashrc && \
    echo "save_map(){" >> /root/.bashrc && \
    echo "    ros2 run nav2_map_server map_saver_cli -f /root/arjuna_ros2/arjuna2_ws/src/arjuna/arjuna/maps/my_map" >> /root/.bashrc && \
    echo "}" >> /root/.bashrc

RUN echo "source /root/arjuna_ros2/arjuna2_ws/install/setup.bash " >> /root/.bashrc && \


# Final shell
CMD ["/bin/bash"]

EOF

echo ""
echo ""

# --- Step 5: Build Docker image ---

cd ~/arjuna_R2_docker/Arjuna

echo "[Step 5] Building Docker image 'arjuna_v2' from ~/arjuna (this might take a while)..."
# Image name
IMAGE_NAME=arjuna_v2

echo ""
echo ""

# Build the Docker image
echo "[INFO] Building Docker image: $IMAGE_NAME"
sudo docker build --network=host -t $IMAGE_NAME .

sudo bash ~/arjuna_R2_docker/arjuna_docker_alias.sh

echo ""
echo ""

echo "[INFO] Sourcing the ~/.bashrc"
source ~/.bashrc \

sudo rm -rf ~/arjuna_R2_docker/

echo ""

echo ""
echo "########################################################"
echo "### SUCCESS! Docker image '$IMAGE_NAME' is ready.    ###"
echo "### Run your ROS2 Foxy container                     ###"
echo "### Command:                                         ###"
echo "###              ros2arjuna                          ###"
echo "########################################################"
echo ""
echo "NOTE: You might need to log out and log back in for docker group changes to apply."

sudo rm -r ~/Arjuna_2_Docker.sh
