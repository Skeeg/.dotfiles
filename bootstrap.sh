#!/usr/bin/env bash
#
# Dotfiles Bootstrap Script
# 
# This script creates symlinks from the home directory to any desired dotfiles
# in this repository. It will backup any existing files/directories before
# creating symlinks.
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory (where the dotfiles repo is)
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles_backups/$(date +%Y_%m_%d_%H%M%S)"

# Files and directories to exclude from symlinking
EXCLUDE_LIST=(
  ".git"
  ".gitignore"
  "bootstrap.sh"
  "merge_gitconfig.sh"
  "readme.md"
  "README.md"
  "Dockerfile"
  "Dockerfile.generated"
  "context_portal"
  ".profile.d/merge_content"
)

# Function to print colored output
print_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if item should be excluded
should_exclude() {
  local item="$1"
  for excluded in "${EXCLUDE_LIST[@]}"; do
    if [[ "$item" == "$excluded" ]]; then
      return 0
    fi
  done
  return 1
}

# Function to backup existing file or directory
backup_if_exists() {
  local target="$1"
  if [[ -e "$target" && ! -L "$target" ]]; then
    if [[ ! -d "$BACKUP_DIR" ]]; then
      mkdir -p "$BACKUP_DIR"
      print_info "Created backup directory: $BACKUP_DIR"
    fi
    
    # Preserve the original path structure in the backup
    local item_name
    item_name="$(basename "$target")"
    local backup_path="$BACKUP_DIR/$item_name"
    
    mv "$target" "$backup_path"
    if [[ -d "$backup_path" ]]; then
      print_warning "Backed up existing directory $item_name to $backup_path"
    else
      print_warning "Backed up existing file $item_name to $backup_path"
    fi
  elif [[ -L "$target" ]]; then
    # It's already a symlink, remove it
    rm "$target"
    print_info "Removed existing symlink: $target"
  fi
  return 0
}

# Function to create symlink
create_symlink() {
  local source="$1"
  local target="$2"
  
  backup_if_exists "$target"
  
  ln -sf "$source" "$target"
  
  local item_name
  item_name="$(basename "$target")"
  if [[ -d "$source" ]]; then
    print_success "Linked directory: $item_name -> $source"
  else
    print_success "Linked file: $item_name -> $source"
  fi
}

# Main function to process dotfiles
link_dotfiles() {
  print_info "Starting dotfiles linking process..."
  print_info "Dotfiles directory: $DOTFILES_DIR"
  echo ""
  
  # Enable dotglob to include hidden files in * expansion
  shopt -s dotglob nullglob
  
  # Process all items in the dotfiles directory
  for item in "$DOTFILES_DIR"/*; do
    # Skip if item doesn't exist (in case glob doesn't match)
    [[ -e "$item" ]] || continue
    
    local basename
    basename="$(basename "$item")"
    
    # Skip current and parent directory references
    [[ "$basename" == "." || "$basename" == ".." ]] && continue
    
    # Check if item should be excluded
    if should_exclude "$basename"; then
      print_info "Skipping excluded item: $basename"
      continue
    fi
    
    local target="$HOME/$basename"
    create_symlink "$item" "$target"
  done
  
  echo ""
  print_success "Dotfiles linking complete!"
  
  if [[ -d "$BACKUP_DIR" ]]; then
    echo ""
    print_info "Backup location: $BACKUP_DIR"
    print_warning "You can remove the backup directory once you've verified everything works correctly."
  fi
}

# Function to merge gitconfig aliases
merge_gitconfig_aliases() {
  print_info "Checking gitconfig aliases..."
  
  local merge_script="$DOTFILES_DIR/merge_gitconfig.sh"
  if [[ -x "$merge_script" ]]; then
    "$merge_script"
  else
    print_warning "merge_gitconfig.sh not found or not executable"
  fi
}

# Main execution
main() {
  echo ""
  echo "========================================"
  echo "  Dotfiles Bootstrap"
  echo "========================================"
  echo ""
  
  # Check if we're in the right directory
  if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    print_error "This doesn't appear to be a git repository!"
    print_error "Please run this script from your dotfiles repository."
    exit 1
  fi
  
  # Link dotfiles
  link_dotfiles
  
  # Merge gitconfig aliases
  echo ""
  merge_gitconfig_aliases
  
  echo ""
  echo "========================================"
  print_success "Bootstrap complete!"
  echo "========================================"
  echo ""
  print_info "Next steps:"
  echo "  1. Open a new terminal or run: source ~/.zshrc"
  echo "  2. Verify your configuration is working correctly"
  echo "  3. Remove backup directory if everything looks good"
  echo ""
}

# Run main function
main
