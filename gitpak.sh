#!/bin/bash

GITPAK_DIR="$HOME/.gitpak"
INSTALL_DIR="$GITPAK_DIR/packages"

show_help() {
    echo "gitpak - A simple package manager using Git"
    echo "Commands:"
    echo "  gitpak help               Show this help menu"
    echo "  gitpak i <repo_url>       Install a package from a Git repository"
    echo "  gitpak path add <package> Add package to PATH"
    echo "  gitpak run <package>      Run package without adding to PATH"
    echo "  gitpak project new <name> Create a new package project"
}

install_package() {
    repo_url="$1"
    package_name=$(basename "$repo_url" .git)
    package_path="$INSTALL_DIR/$package_name"
    
    mkdir -p "$INSTALL_DIR"
    git clone "$repo_url" "$package_path"
    echo "Installed $package_name to $package_path"
}

add_to_path() {
    package_name="$1"
    package_path="$INSTALL_DIR/$package_name"
    echo "export PATH=\"$package_path:$PATH\"" >> ~/.bashrc
    echo "export PATH=\"$package_path:$PATH\"" >> ~/.zshrc
    source ~/.bashrc
    source ~/.zshrc
    echo "$package_name added to PATH"
}

run_package() {
    package_name="$1"
    shift
    package_path="$INSTALL_DIR/$package_name"
    os=$(uname)
    
    if [ "$os" == "Linux" ]; then
        exec "$package_path/index.sh" "$@"
    elif [ "$os" == "Darwin" ]; then
        exec "$package_path/index-mac.sh" "$@"
    elif [[ "$os" == MINGW* || "$os" == CYGWIN* ]]; then
        cmd.exe /c "$package_path/index-win.bat" "$@"
    else
        echo "Unsupported OS"
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
    echo "Created new project: $project_name"
}

case "$1" in
    help) show_help ;;
    i) install_package "$2" ;;
    path) shift; add_to_path "$2" ;;
    run) shift; run_package "$1" "$@" ;;
    project) shift; [ "$1" == "new" ] && create_project "$2" ;;
    *) show_help ;;
esac

