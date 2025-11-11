# Esegui automaticamente install.sh dopo il clone
if [ -f ~/coder-dotfiles/install.sh ]; then
  echo "Eseguo install.sh..."
  chmod +x ~/coder-dotfiles/install.sh
  ~/coder-dotfiles/install.sh
fi
