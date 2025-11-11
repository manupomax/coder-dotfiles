# Esegui automaticamente install.sh dopo il clone
if [ -f ~/dotfiles/install.sh ]; then
  echo "Eseguo install.sh..."
  chmod +x ~/dotfiles/install.sh
  ~/dotfiles/install.sh
fi
