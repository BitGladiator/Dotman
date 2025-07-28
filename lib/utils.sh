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

#Install Dotfiles (Symlink them to $HOME)
install_dotfiles() {
  log_info "Installing dotfiles..."

  # Load the selected profile from the .dotmanrc config file
  if [ -f "$HOME/.dotmanrc" ]; then
    source "$HOME/.dotmanrc"
  fi

  # Default path to configs/ if no profile is selected
  DOTFILES_PATH="$PROJECT_ROOT/configs"

  # If a profile is set and it's not 'default', use the profile folder
  if [ -n "$DOTMAN_PROFILE" ] && [ "$DOTMAN_PROFILE" != "default" ]; then
    PROFILE_PATH="$PROJECT_ROOT/profiles/$DOTMAN_PROFILE"
    if [ -d "$PROFILE_PATH" ]; then
      DOTFILES_PATH="$PROFILE_PATH"
      log_info "Using profile: $DOTMAN_PROFILE"
    else
      log_warn "Profile '$DOTMAN_PROFILE' not found. Falling back to 'configs/'"
    fi
  fi

  # Loop through all files in the active dotfiles folder
  for file in "$DOTFILES_PATH"/*; do
    [ -f "$file" ] || continue  # Skip if not a regular file

    # Prepend a dot to the filename to make it a hidden file (e.g. bashrc -> .bashrc)
    basefile=".$(basename "$file")"

    # Full target path in user's home directory
    target="$HOME/$basefile"

    # If a file or symlink already exists at the target location
    if [ -f "$target" ] || [ -L "$target" ]; then
      # Back it up before replacing
      backup_dotfiles "$target"
      rm -f "$target"
    fi

    # Create a symlink from the dotfile source to $HOME
    ln -s "$file" "$target"

    log_success "Linked $basefile -> $(realpath "$file")"
  done

  log_success "Dotfiles installed successfully!"
}
# Change the active profile
use_profile() {
  PROFILE_NAME="$1"

  if [ -z "$PROFILE_NAME" ]; then
    log_error "Please provide a profile name. Example: use-profile work"
    return 1
  fi

  PROFILE_PATH="$PROJECT_ROOT/profiles/$PROFILE_NAME"

  if [ ! -d "$PROFILE_PATH" ]; then
    log_error "Profile '$PROFILE_NAME' does not exist at $PROFILE_PATH"
    return 1
  fi

  # Update ~/.dotmanrc
  sed -i "s/^DOTMAN_PROFILE=.*/DOTMAN_PROFILE=$PROFILE_NAME/" "$HOME/.dotmanrc"

  log_success "Active profile set to '$PROFILE_NAME'"
}
# List available profiles and highlight the active one
list_profiles() {
  # Load active profile from .dotmanrc
  if [ -f "$HOME/.dotmanrc" ]; then
    source "$HOME/.dotmanrc"
  else
    log_error "No .dotmanrc found. Run 'dotman.sh init' first."
    return 1
  fi

  log_info "Available profiles:"
  for dir in "$PROJECT_ROOT/profiles/"*/; do
    profile=$(basename "$dir")

    # Mark active profile
    if [ "$profile" = "$DOTMAN_PROFILE" ]; then
      echo "  ➤ $profile (active)"
    else
      echo "    $profile"
    fi
  done
}
# Create a new dotfiles profile
create_profile() {
  PROFILE_NAME="$1"

  if [ -z "$PROFILE_NAME" ]; then
    log_error "Please provide a profile name. Example: create-profile dev"
    return 1
  fi

  PROFILE_DIR="$PROJECT_ROOT/profiles/$PROFILE_NAME"

  if [ -d "$PROFILE_DIR" ]; then
    log_error "Profile '$PROFILE_NAME' already exists."
    return 1
  fi

  # Create the new profile directory
  mkdir -p "$PROFILE_DIR"

  # Optionally create a template dotfile
  echo "# Add your dotfiles for $PROFILE_NAME here" > "$PROFILE_DIR/readme.txt"

  log_success "Profile '$PROFILE_NAME' created at $PROFILE_DIR"
}
# Delete an existing dotfiles profile
delete_profile() {
  PROFILE_NAME="$1"

  if [ -z "$PROFILE_NAME" ]; then
    log_error "Please provide a profile name. Example: delete-profile dev"
    return 1
  fi

  PROFILE_DIR="$PROJECT_ROOT/profiles/$PROFILE_NAME"

  if [ ! -d "$PROFILE_DIR" ]; then
    log_error "Profile '$PROFILE_NAME' does not exist."
    return 1
  fi

  # Load active profile from config
  if [ -f "$HOME/.dotmanrc" ]; then
    source "$HOME/.dotmanrc"
  fi

  # Warn if trying to delete the active profile
  if [ "$PROFILE_NAME" = "$DOTMAN_PROFILE" ]; then
    log_error "You are trying to delete the currently active profile '$PROFILE_NAME'. Please switch profiles first."
    return 1
  fi

  # Ask for confirmation
  read -p "Are you sure you want to delete profile '$PROFILE_NAME'? (y/n): " CONFIRM
  if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    rm -rf "$PROFILE_DIR"
    log_success "Profile '$PROFILE_NAME' deleted."
  else
    log_info "Delete cancelled."
  fi
}
# Show dotfile installation status
status_dotfiles() {
  log_info "Checking dotfiles status..."

  # Load the profile from config
  if [ -f "$HOME/.dotmanrc" ]; then
    source "$HOME/.dotmanrc"
  fi

  DOTFILES_PATH="$PROJECT_ROOT/configs"

  if [ -n "$DOTMAN_PROFILE" ] && [ "$DOTMAN_PROFILE" != "default" ]; then
    PROFILE_PATH="$PROJECT_ROOT/profiles/$DOTMAN_PROFILE"
    if [ -d "$PROFILE_PATH" ]; then
      DOTFILES_PATH="$PROFILE_PATH"
      log_info "Using profile: $DOTMAN_PROFILE"
    else
      log_error "Profile '$DOTMAN_PROFILE' does not exist."
      return 1
    fi
  fi

  # Loop through files in the active profile
  for file in "$DOTFILES_PATH"/*; do
    [ -f "$file" ] || continue

    basefile=".$(basename "$file")"
    target="$HOME/$basefile"

    if [ -L "$target" ]; then
      # If it's a symlink
      link_target=$(readlink "$target")
      if [ "$link_target" = "$file" ]; then
        echo "SUCCESS: $basefile is correctly linked"
      else
        echo "WARNING: $basefile is a symlink but points elsewhere"
      fi
    elif [ -f "$target" ]; then
      # Regular file exists and could be a conflict
      echo "ERROR: $basefile exists and may conflict"
    else
      echo "ERROR: $basefile is missing (not installed yet)"
    fi
  done

  log_info "Status check complete."
}


