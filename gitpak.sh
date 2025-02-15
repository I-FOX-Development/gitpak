#!/bin/bash

GITPAK_DIR="$HOME/.gitpak"
INSTALL_DIR="$GITPAK_DIR/packages"

# Terminal Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_help() {
    echo -e "${BLUE}gitpak - A simple package manager using Git${NC}"
    echo "Commands:"
    echo -e "  ${YELLOW}gitpak help${NC}               Show this help menu"
    echo -e "  ${YELLOW}gitpak i <repo_url>${NC}       Install a package from a Git repository"
    echo -e "  ${YELLOW}gitpak path add <package>${NC} Add package to PATH"
    echo -e "  ${YELLOW}gitpak run < package>${NC}      Run package without adding to PATH"
    echo -e "  ${YELLOW}gitpak project new <name>${NC} Create a new package project"
    echo -e "  ${YELLOW}gitpak update${NC}             Update gitpak to the latest version"
}

install_package() {
    repo_url="$1"
    package_name=$(basename "$repo_url" .git)
    package_path="$INSTALL_DIR/$package_name"
    
    if [ -d "$package_path" ]; then
        echo -e "${RED}Error: Package '$package_name' is already installed.${NC}"
        exit 1
    fi
    
    mkdir -p "$INSTALL_DIR"
    echo -e "${GREEN}Installing $package_name...${NC}"
    git clone --progress "$repo_url" "$package_path" 2>&1 |
    while IFS= read -r line; do
        if [[ "$line" =~ ([0-9]+)% ]]; then
            percent=${BASH_REMATCH[1]}
            filled=$((percent / 5))
            empty=$((20 - filled))
            bar="[${GREEN}$(printf '█%.0s' $(seq 1 $filled))${NC}$(printf ' %.0s' $(seq 1 $empty))]"
            echo -ne "\rDownloading: $bar $percent%"
        fi
    done
    echo -e "\n${GREEN}Installed $package_name to $package_path${NC}"
}

add_to_path() {
    package_name="$1"
    package_path="$INSTALL_DIR/$package_name"
    
    if [ ! -d "$package_path" ]; then
        echo -e "${RED}Error: Package '$package_name' not found.${NC}"
        exit 1
    fi
    
    echo "export PATH=\"$package_path:$PATH\"" >> ~/.bashrc
    echo "export PATH=\"$package_path:$PATH\"" >> ~/.zshrc
    source ~/.bashrc
    source ~/.zshrc
    echo -e "${GREEN}$package_name added to PATH${NC}"
}

run_package() {
    package_name="$1"
    shift
    package_path="$INSTALL_DIR/$package_name"
    os=$(uname)
    
    if [ ! -d "$package_path" ]; then
        echo -e "${RED}Error: Package '$package_name' is not installed.${NC}"
        exit 1
    fi
    
    if [ "$os" == "Linux" ]; then
        exec "$package_path/index.sh" "$@"
    elif [ "$os" == "Darwin" ]; then
        exec "$package_path/index-mac.sh" "$@"
    elif [[ "$os" == MINGW* || "$os" == CYGWIN* ]]; then
        cmd.exe /c "$package_path/index-win.bat" "$@"
    else
        echo -e "${RED}Unsupported OS${NC}"
    fi
}

create_project() {
    project_name="$1"
    mkdir -p "$project_name"
    echo "#!/bin/bash" > "$project_name/index.sh"
    echo "#!/bin/bash" > "$project_name/index-mac.sh"
    echo "@echo off" > "$project_name/index-win.bat"
    cat <<EOL > "$project_name/info.json"
{
  "name": "$project_name",
  "external packages": [],
  "version": null
}
EOL
    chmod +x "$project_name/index.sh" "$project_name/index-mac.sh"
    echo -e "${GREEN}Created new project: $project_name${NC}"
}

update_gitpak() {
    echo -e "${YELLOW}Updating gitpak...${NC}"
    curl -sL "https://raw.githubusercontent.com/I-FOX-Development/gitpak/refs/heads/main/update.sh" | bash
    echo -e "${GREEN}gitpak has been updated!${NC}"
}

case "$1" in
    help) show_help ;;
    i) install_package "$2" ;;
    path) shift; add_to_path "$2" ;;
    run) shift; run_package "$1" "$@" ;;
    project) shift; [ "$1" == "new" ] && create_project "$2" ;;
    update) update_gitpak ;;
    *) show_help ;;
esac
