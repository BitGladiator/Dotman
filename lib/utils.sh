#!/usr/bin/env bash
# Print info messages
log_info() {
  echo -e "$1"
}

# Print success messages
log_success() {
  echo -e "$1"
}

# Print error messages
log_error() {
  echo -e "$1" >&2
}

# Show help screen
show_help() {
  echo "Dotman - Dotfiles Manager"
  echo
  echo "Usage:"
  echo "  dotman.sh <command>"
  echo
  echo "Commands:"
  echo "  init          Initialize Dotman folders and config"
  echo "  install       Symlink dotfiles to home directory"
  echo "  backup        Backup existing dotfiles"
  echo "  help          Show this help message"
  echo
}

# Initialize Dotman for first-time setup
init_dotman() {
  log_info "Initializing Dotman..."

  DOTMANRC="$HOME/.dotmanrc"

  # Create .dotmanrc if it doesn't exist
  if [ ! -f "$DOTMANRC" ]; then
    echo "DOTMAN_PROFILE=default" > "$DOTMANRC"
    echo "DOTMAN_BACKUP_DIR=$PROJECT_ROOT/backup" >> "$DOTMANRC"
    log_success "Created default .dotmanrc"
  else
    log_info ".dotmanrc already exists"
  fi

  # Ensure backup and logs folders exist
  mkdir -p "$PROJECT_ROOT/backup"
  mkdir -p "$PROJECT_ROOT/logs"

  log_success "Dotman initialized!"
}

# Backup existing dotfiles from $HOME
backup_dotfiles() {
  log_info "Backing up existing dotfiles..."

  # Create a timestamped backup directory
  TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
  BACKUP_DIR="$PROJECT_ROOT/backup/$TIMESTAMP"
  mkdir -p "$BACKUP_DIR"

  # Loop through each file in configs/
  for file in "$PROJECT_ROOT/configs/"*; do
    basefile=".$(basename "$file")"
    target="$HOME/$basefile"

    # If the file already exists in home, copy it to backup
    if [ -f "$target" ] || [ -L "$target" ]; then
      cp -a "$target" "$BACKUP_DIR/"
      log_info "Backed up $basefile"
    fi
  done

  log_success "Backup complete at $BACKUP_DIR"
}

# Install/symlink dotfiles into $HOME
install_dotfiles() {
  log_info "Installing dotfiles..."

  for file in "$PROJECT_ROOT/configs/"*; do
    basefile=".$(basename "$file")"
    target="$HOME/$basefile"

    # If the file already exists, back it up and remove it
    if [ -f "$target" ] || [ -L "$target" ]; then
      log_info "Backing up existing $basefile"
      backup_dotfiles
      rm -f "$target"
    fi

    # Create a symbolic link from configs/ to $HOME
    ln -s "$file" "$target"
    log_success "Linked $basefile"
  done

  log_success "All dotfiles installed!"
}

