GITPAK_DIR="$HOME/.gitpak"
INSTALL_DIR="$GITPAK_DIR/packages"
temp_gitpak=$(mktemp)
curl -sL "https://raw.githubusercontent.com/I-FOX-Development/gitpak/refs/heads/main/gitpak.sh" -o "$temp_gitpak"
mv "$temp_gitpak" "$GITPAK_DIR/gitpak.sh"
chmod +x "$GITPAK_DIR/gitpak.sh"
echo "export PATH=\"$GITPAK_DIR:$PATH\"" >> ~/.bashrc
echo "export PATH=\"$GITPAK_DIR:$PATH\"" >> ~/.zshrc
source ~/.bashrc
source ~/.zshrc
ln -sf "$GITPAK_DIR/gitpak.sh" "$GITPAK_DIR/gitpak"
source ~/.bashrc
echo "Gitpak updated successfully."
