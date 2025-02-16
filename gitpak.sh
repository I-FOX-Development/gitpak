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
    echo -e "  ${YELLOW}gitpak path add all${NC}       Add all packages to PATH"
    echo -e "  ${YELLOW}gitpak list${NC}               List all installed packages"
    echo -e "  ${YELLOW}gitpak run <package>${NC}      Run package without adding to PATH"
    echo -e "  ${YELLOW}gitpak project new <name>${NC} Create a new package project"
    echo -e "  ${YELLOW}gitpak update${NC}             Update gitpak to the latest version"
    echo -e "  ${YELLOW}gitpak search <package>${NC}   Search for a package in the public register"
    echo -e "  ${YELLOW}gitpak uninstall <package>${NC} Uninstall a package (with confirmation)"
    echo -e "    ${YELLOW}gitpak uninstall gitpak${NC}   Uninstall gitpak itself (with confirmation)"
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

    # Ensure progress reaches 100% before completing
    echo -ne "\rDownloading: [${GREEN}$(printf '█%.0s' $(seq 1 20))${NC}] 100%\n"
    echo -e "\n${GREEN}Installed $package_name to $package_path${NC}"
    
    # Get the package name from info.json
    info_file="$package_path/info.json"
    if [ -f "$info_file" ]; then
        new_name=$(jq -r .name "$info_file")
        if [ "$new_name" != "$package_name" ]; then
            mv "$package_path" "$INSTALL_DIR/$new_name"
            echo -e "${GREEN}Renamed package to '$new_name'.${NC}"
        fi
    fi
}

uninstall_package() {
    package_name="$1"
    
    # Special check for uninstalling gitpak itself
    if [ "$package_name" == "gitpak" ]; then
        echo -e "${YELLOW}Are you sure you want to uninstall gitpak? This will remove the gitpak manager from your system. [y/n]${NC}"
        read -r confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo -e "${RED}Uninstallation cancelled.${NC}"
            exit 0
        fi
    else
        echo -e "${YELLOW}Are you sure you want to uninstall '$package_name'? [y/n]${NC}"
        read -r confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo -e "${RED}Uninstallation cancelled.${NC}"
            exit 0
        fi
    fi

    package_path="$INSTALL_DIR/$package_name"

    # Check if the package exists
    if [ ! -d "$package_path" ]; then
        echo -e "${RED}Error: Package '$package_name' is not installed.${NC}"
        exit 1
    fi

    # Remove package directory
    rm -rf "$package_path"
    echo -e "${GREEN}Uninstalled package '$package_name'${NC}"

    # Remove package from PATH in .bashrc and .zshrc
    sed -i "/$package_path/d" ~/.bashrc
    sed -i "/$package_path/d" ~/.zshrc
    source ~/.bashrc
    source ~/.zshrc
    echo -e "${GREEN}Removed '$package_name' from PATH${NC}"
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

add_all_to_path() {
    for package_path in "$INSTALL_DIR"/*; do
        if [ -d "$package_path" ]; then
            package_name=$(basename "$package_path")
            echo "export PATH=\"$package_path:$PATH\"" >> ~/.bashrc
            echo "export PATH=\"$package_path:$PATH\"" >> ~/.zshrc
            echo -e "${GREEN}$package_name added to PATH${NC}"
        fi
    done
    source ~/.bashrc
    source ~/.zshrc
}

list_installed_packages() {
    if [ -d "$INSTALL_DIR" ] && [ "$(ls -A "$INSTALL_DIR")" ]; then
        echo -e "${GREEN}Installed Packages:${NC}"
        for package_path in "$INSTALL_DIR"/*; do
            if [ -d "$package_path" ]; then
                echo "  $(basename "$package_path")"
            fi
        done
    else
        echo -e "${RED}No packages installed.${NC}"
    fi
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
    
    # Check for the main file based on the operating system
    if [ "$os" == "Linux" ]; then
        main_file="$package_path/index.sh"
    elif [ "$os" == "Darwin" ]; then
        main_file="$package_path/index-mac.sh"
    elif [[ "$os" == MINGW* || "$os" == CYGWIN* ]]; then
        main_file="$package_path/index-win.bat"
    else
        echo -e "${RED}Unsupported OS${NC}"
        exit 1
    fi

    # Check if the main file exists
    if [ ! -f "$main_file" ]; then
        echo -e "${RED}The package '$package_name' is invalid ($main_file not found).${NC}"
        exit 1
    fi
    
    # Execute the main file if it exists
    exec "$main_file" "$@"
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

search_package() {
    search_term="$1"
    echo -e "${YELLOW}Searching for '$search_term' in the public register...${NC}"
    
    # Fetch the package list
    response=$(curl -sL "https://raw.githubusercontent.com/I-FOX-Development/gitpak/refs/heads/main/pak.json")
    
    # Extract package names and check if any match the search term
    matching_packages=$(echo "$response" | grep -o '"name": *"[^"]*"' | sed 's/"name": *"\([^"]*\)"/\1/' | grep -i "$search_term")
    
    # Check if we found any matches
    if [ -n "$matching_packages" ]; then
        echo -e "${GREEN}Found the following packages matching '$search_term':${NC}"
        echo "$matching_packages"
    else
        echo -e "${RED}No packages found matching '$search_term'.${NC}"
    fi
}

case "$1" in
    help) show_help ;;
    i) install_package "$2" ;;
    path) shift; 
        if [ "$1" == "add" ] && [ "$2" == "all" ]; then
            add_all_to_path
        else
            add_to_path "$2"
        fi
        ;;
    list) list_installed_packages ;;
    run) shift; run_package "$1" "$@" ;;
    project) shift; [ "$1" == "new" ] && create_project "$2" ;;
    update) update_gitpak ;;
    search) search_package "$2" ;;
    uninstall) uninstall_package "$2" ;;  # Add this line for uninstall command
    *) show_help ;;
esac
