#!/bin/bash

set -e
set -o pipefail

echo ""
echo "######################################################"
echo "###        Install all the prerequisits            ###"
echo "######################################################"
echo ""

echo "Install "

# Use a separate sudo command for apt install
if ! command -v code &> /dev/null
then
    echo "VS Code is not installed. Please wait, installing VS Code first..."
    sudo apt install ./code_1.83.1-1696982739_arm64.deb
else
    echo "VS Code already installed!!"
    echo ""
    echo ""
fi

# Use the 'runuser' command to execute the 'code' commands as the original user
# who called the script, not as root.
USER_TO_RUN=${SUDO_USER:-$USER}

echo "Installing VS Code extensions as user: $USER_TO_RUN"

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
    runuser -l "$USER_TO_RUN" -c "code --install-extension $extension"
done

echo "All extensions installed successfully!"
