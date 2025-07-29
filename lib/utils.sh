#!/usr/bin/env bash
LOG_FILE="$PROJECT_ROOT/logs/dotman-$(date +'%Y-%m-%d_%H-%M-%S').log"
# Print info messages
log_info() {
  echo -e "[INFO] $1"
  echo -e "[INFO] $1" >> "$LOG_FILE"
}

log_success() {
  echo -e "[SUCCESS] $1"
  echo -e "[SUCCESS] $1" >> "$LOG_FILE"
}

log_error() {
  echo -e "[ERROR] $1" >&2
  echo -e "[ERROR] $1" >> "$LOG_FILE"
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
backup_dotfiles() {
  log_info "Backing up existing dotfiles..."

  # Create a timestamped backup directory
  TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
  BACKUP_DIR="$PROJECT_ROOT/backup/$TIMESTAMP"
  mkdir -p "$BACKUP_DIR"

  # Load ignore patterns from .dotmanignore (if exists)
  IGNORE_FILE="$PROJECT_ROOT/.dotmanignore"
  IGNORED_FILES=()
  if [ -f "$IGNORE_FILE" ]; then
    mapfile -t IGNORED_FILES < "$IGNORE_FILE"
  fi

  # Loop through each file in configs/
  for file in "$PROJECT_ROOT/configs/"*; do
    filename="$(basename "$file")"

    # Skip ignored files
    if [[ " ${IGNORED_FILES[@]} " =~ " $filename " ]]; then
      log_info "Skipping ignored file: $filename"
      continue
    fi

    basefile=".$filename"
    target="$HOME/$basefile"

    # If the file already exists in home, copy it to backup
    if [ -f "$target" ] || [ -L "$target" ]; then
      cp -a "$target" "$BACKUP_DIR/"
      log_info "Backed up $basefile"
    fi
  done

  log_success "Backup complete at $BACKUP_DIR"
}
# Install Dotfiles (Symlink them to $HOME)
install_dotfiles() {
  log_info "Installing dotfiles..."

  DRY_RUN=false

  # Check for --dry-run flag in arguments
  for arg in "$@"; do
    if [ "$arg" = "--dry-run" ]; then
      DRY_RUN=true
      log_info "[DRY-RUN MODE ENABLED]"
    fi
  done

  # Load selected profile from .dotmanrc config file
  if [ -f "$HOME/.dotmanrc" ]; then
    source "$HOME/.dotmanrc"
  fi

  # Default path is configs/
  DOTFILES_PATH="$PROJECT_ROOT/configs"

  # If a profile is set and not default, use that folder
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
    [ -f "$file" ] || continue  # Skip non-regular files
    # Skip ignored files
    if is_ignored "$(basename "$file")"; then
      log_info "Skipping ignored file: $(basename "$file")"
      continue
    fi
    basefile=".$(basename "$file")"
    target="$HOME/$basefile"

    # If target exists, prepare to back it up
    if [ -f "$target" ] || [ -L "$target" ]; then
      if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Would back up and replace $basefile"
      else
        backup_dotfiles "$target"
        rm -f "$target"
      fi
    fi

    # Create or simulate symlink
    if [ "$DRY_RUN" = true ]; then
      log_success "[DRY-RUN] Would link $basefile -> $(realpath "$file")"
    else
      ln -s "$file" "$target"
      log_success "Linked $basefile -> $(realpath "$file")"
    fi
  done

  log_success "Dotfiles install ${DRY_RUN:+(dry-run)} complete!"
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
# Remove symlinks in $HOME that were created by Dotman
clean_dotfiles() {
  log_info "Cleaning up dotfiles from \$HOME..."

  # Load profile from config
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
      log_warn "Profile '$DOTMAN_PROFILE' not found. Falling back to configs/"
    fi
  fi

  # Loop through files and remove symlinks in $HOME
  for file in "$DOTFILES_PATH"/*; do
    [ -f "$file" ] || continue
    # Skip ignored files
    if is_ignored "$(basename "$file")"; then
      log_info "Skipping ignored file: $(basename "$file")"
      continue
    fi
    basefile=".$(basename "$file")"
    target="$HOME/$basefile"

    # Only remove if it's a symlink pointing to our dotfile
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$file" ]; then
      rm "$target"
      log_success "Removed symlink: $target"
    fi
  done

  log_success "Clean complete!"
}
# Check if a file is ignored based on .dotmanignore
is_ignored() {
  local file_name="$1"
  local ignore_file="$DOTFILES_PATH/.dotmanignore"

  if [ ! -f "$ignore_file" ]; then
    return 1  # No ignore file → nothing ignored
  fi

  # Check each line in .dotmanignore
  while IFS= read -r pattern || [ -n "$pattern" ]; do
    [[ -z "$pattern" || "$pattern" =~ ^# ]] && continue  # skip empty or comment lines
    if [[ "$file_name" == $pattern || "$file_name" == $(basename "$pattern") ]]; then
      return 0  # ignored
    fi
  done < "$ignore_file"

  return 1
}
version_control() {
  ACTION="$1"
  shift

  # Load active profile
  if [ -f "$HOME/.dotmanrc" ]; then
    source "$HOME/.dotmanrc"
  fi

  DOTFILES_PATH="$PROJECT_ROOT/configs"

  if [ -n "$DOTMAN_PROFILE" ] && [ "$DOTMAN_PROFILE" != "default" ]; then
    PROFILE_PATH="$PROJECT_ROOT/profiles/$DOTMAN_PROFILE"
    [ -d "$PROFILE_PATH" ] && DOTFILES_PATH="$PROFILE_PATH"
  fi

  case "$ACTION" in
    sync)
      COMMIT_MSG="$*"
      [ -z "$COMMIT_MSG" ] && COMMIT_MSG="update dotfiles"

      # 1. Init git repo if not present
      if [ ! -d "$DOTFILES_PATH/.git" ]; then
        git -C "$DOTFILES_PATH" init
        log_info "Initialized Git repository in $DOTFILES_PATH"
      fi

      # 2. Add remote if not already present
      if ! git -C "$DOTFILES_PATH" remote | grep -q origin; then
        echo -n "Enter remote Git repo URL: "
        read REMOTE_URL
        git -C "$DOTFILES_PATH" remote add origin "$REMOTE_URL"
        log_info "Added remote origin -> $REMOTE_URL"
      fi

      # 3. Stage, commit, push
      git -C "$DOTFILES_PATH" add .
      git -C "$DOTFILES_PATH" commit -m "$COMMIT_MSG" || log_info "Nothing to commit."
      git -C "$DOTFILES_PATH" push -u origin main 2>/dev/null || git -C "$DOTFILES_PATH" push -u origin master

      log_success "Dotfiles synced to remote."
      ;;
    *)
      log_error "Unknown version control action: $ACTION"
      ;;
  esac
}

