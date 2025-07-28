#!/usr/bin/env bash

# Load utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_ROOT/lib/utils.sh"

COMMAND="$1"
shift

case "$COMMAND" in
  init)
    init_dotman "$@"
    ;;
  install)
    install_dotfiles "$@"
    ;;
  backup)
    backup_dotfiles "$@"
    ;;
  use-profile)
    use_profile "$@"
    ;;
  list-profiles)
    list_profiles "$@"
    ;;
  create-profile)
    create_profile "$@"
    ;;
  delete-profile)
    delete_profile "$@"
    ;;
  status)
    status_dotfiles "$@"
    ;;
  help|--help|-h|"")
    show_help
    ;;
  *)
    echo "Unknown command: $COMMAND"
    show_help
    ;;
esac

