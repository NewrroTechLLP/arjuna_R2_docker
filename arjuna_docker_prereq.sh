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
    sudo apt install ~/arjuna_R2_docker/code_1.83.1-1696982739_arm64.deb
else
    echo "VS Code already installed!!"
    echo ""
    echo ""
fi

# Get the original user
USER_TO_RUN=${SUDO_USER:-$USER}

# Create a temporary script to install extensions as the user
EXT_SCRIPT=$(mktemp)

cat > "$EXT_SCRIPT" << EOF
#!/bin/bash
set -e

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
for extension in "\${extensions[@]}"
do
    echo "Installing extension: \$extension"
    code --install-extension "\$extension"
done
EOF

# Make the temporary script executable
chmod +x "$EXT_SCRIPT"

# Execute the temporary script as the intended user
echo "Installing VS Code extensions as user: $USER_TO_RUN"
runuser -l "$USER_TO_RUN" -c "$EXT_SCRIPT"

# Clean up the temporary script
rm "$EXT_SCRIPT"

echo "All extensions installed successfully!"
