#!/bin/bash

set -e
set -o pipefail

echo "######################################################"
echo "###        Install all the prerequisits            ###"
echo "######################################################"
echo ""

echo "Install "

# Check if VS Code is installed
if ! command -v code &> /dev/null
then
    echo "VS Code is not installed. Please install VS Code first."
    exit 1
else
    sudo apt install ./code_1.83.1-1696982739_arm64.deb
fi

# List of extensions to install
extensions=(
    "ms-python.python"
    "ms-vscode.cpptools"
    "ms-azuretools.vscode-docker"
    "ms-iot.vscode-ros"
    "ms-vscode.cmake-tools"
    "ms-vscode-remote.remote-containers"
)

# Install each extension
for extension in "${extensions[@]}"
do
    echo "Installing extension: $extension"
    code --install-extension $extension
done

echo "All extensions installed successfully!"



