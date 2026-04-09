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

# Update mode flag — set to true via --update argument in main()
_update_mode=false

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

# Detect the OS using /etc/os-release on Linux or uname on macOS
detect_os() {
  if [[ "$(uname)" == "Darwin" ]]; then
    echo "macos"
  elif [[ -f /etc/os-release ]]; then
    . /etc/os-release
    echo "$ID"
  else
    echo "unknown"
  fi
}

# Install blesh (ble.sh) nightly to ~/.local/share/blesh/
# Used on all Linux platforms — not in standard package repos.
# The nightly URL is stable and always points to the latest build.
install_blesh() {
  if [[ -d "$HOME/.local/share/blesh" ]]; then
    print_info "blesh already installed, skipping"
    return 0
  fi
  print_info "Installing blesh nightly (bash autosuggestions) to ~/.local/share/blesh..."
  mkdir -p "$HOME/.local/share"
  curl -sL https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz \
    | tar -xJ -C "$HOME/.local/share"
  mv "$HOME/.local/share/ble-nightly" "$HOME/.local/share/blesh"
  print_success "blesh installed."
}

update_blesh() {
  print_info "Updating blesh nightly..."
  rm -rf "$HOME/.local/share/blesh"
  install_blesh
}

# Update SteamOS home-directory tools (no package manager available)
update_steamos_extras() {
  print_info "Updating SteamOS home-directory tools..."

  print_info "Updating starship..."
  curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$HOME/.local/bin"

  if [[ -d "$HOME/.fzf" ]]; then
    print_info "Updating fzf..."
    git -C "$HOME/.fzf" pull --ff-only
    "$HOME/.fzf/install" --bin --no-update-rc --no-bash --no-zsh --no-fish
  fi

  for _p in zsh-autosuggestions zsh-syntax-highlighting; do
    if [[ -d "$HOME/.zsh/$_p" ]]; then
      print_info "Updating $_p..."
      git -C "$HOME/.zsh/$_p" pull --ff-only
    fi
  done
  unset _p

  if command -v bat &>/dev/null; then
    local _latest
    _latest=$(curl -s https://api.github.com/repos/sharkdp/bat/releases/latest \
      | grep '"tag_name"' | cut -d'"' -f4)
    local _installed
    _installed="v$(bat --version | awk '{print $2}')"
    if [[ "$_installed" == "$_latest" ]]; then
      print_info "bat is already up to date ($_installed)"
    else
      print_info "Updating bat $_installed → $_latest..."
      local _arch; _arch="$(uname -m)-unknown-linux-musl"
      local _dir="bat-${_latest}-${_arch}"
      curl -sL "https://github.com/sharkdp/bat/releases/download/${_latest}/${_dir}.tar.gz" \
        | tar -xz -C "$HOME/.local/bin" --strip-components=1 "${_dir}/bat"
      chmod +x "$HOME/.local/bin/bat"
    fi
  fi

  update_blesh
}

# Install required packages for the dotfiles plugin stack:
#   starship  — cross-shell prompt (replaces omz + powerlevel10k)
#   fzf       — fuzzy finder, Ctrl+R history search
#   bat       — syntax-highlighted cat/man pager (ccat/cless aliases)
#   zsh-autosuggestions   — fish-like inline suggestions (zsh only)
#   zsh-syntax-highlighting — command coloring as you type (zsh only)
#   bash-completion       — tab completion for bash
#   blesh     — bash readline enhancement (autosuggestions + syntax highlighting)
install_packages() {
  local os
  os=$(detect_os)

  print_info "Detected OS: $os"
  print_info "Installing required packages..."
  echo ""

  case "$os" in
    macos)
      if ! command -v brew &>/dev/null; then
        print_error "Homebrew not found. Install from https://brew.sh first, then re-run bootstrap."
        return 1
      fi
      brew install starship fzf bat zsh-autosuggestions zsh-syntax-highlighting bash-completion@2
      ;;

    fedora|amzn)
      if command -v starship &>/dev/null; then
        print_info "starship already installed, skipping curl install"
      else
        print_info "Installing Starship via official installer..."
        curl -sS https://starship.rs/install.sh | sh -s -- --yes
      fi
      yum install -y fzf bat zsh-autosuggestions zsh-syntax-highlighting bash-completion
      if [[ "$_update_mode" == true ]]; then update_blesh; else install_blesh; fi
      ;;

    alpine)
      if command -v starship &>/dev/null; then
        print_info "starship already installed, skipping curl install"
      else
        print_info "Installing Starship via official installer..."
        curl -sS https://starship.rs/install.sh | sh -s -- --yes
      fi
      apk add fzf bat zsh-autosuggestions zsh-syntax-highlighting bash-completion
      if [[ "$_update_mode" == true ]]; then update_blesh; else install_blesh; fi
      ;;

    arch)
      sudo pacman -Syu --noconfirm starship fzf bat zsh-autosuggestions zsh-syntax-highlighting bash-completion
      if [[ "$_update_mode" == true ]]; then update_blesh; else install_blesh; fi
      ;;

    steamos)
      # SteamOS has an immutable root filesystem — pacman installs don't persist
      # across OS updates. Install everything to the home directory instead.
      if [[ "$_update_mode" == true ]]; then
        update_steamos_extras
      else
        mkdir -p "$HOME/.local/bin" "$HOME/.zsh"

        if command -v starship &>/dev/null; then
          print_info "starship already installed, skipping"
        else
          print_info "Installing Starship to ~/.local/bin..."
          curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$HOME/.local/bin"
        fi

        if [[ -d "$HOME/.fzf" ]]; then
          print_info "fzf already installed at ~/.fzf, skipping"
        else
          print_info "Installing fzf to ~/.fzf..."
          git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
          "$HOME/.fzf/install" --bin --no-update-rc --no-bash --no-zsh --no-fish
        fi

        if command -v bat &>/dev/null; then
          print_info "bat already installed, skipping"
        else
          print_info "Installing bat to ~/.local/bin..."
          local _bat_ver
          _bat_ver=$(curl -s https://api.github.com/repos/sharkdp/bat/releases/latest \
            | grep '"tag_name"' | cut -d'"' -f4)
          local _bat_arch; _bat_arch="$(uname -m)-unknown-linux-musl"
          local _bat_dir="bat-${_bat_ver}-${_bat_arch}"
          curl -sL "https://github.com/sharkdp/bat/releases/download/${_bat_ver}/${_bat_dir}.tar.gz" \
            | tar -xz -C "$HOME/.local/bin" --strip-components=1 "${_bat_dir}/bat"
          chmod +x "$HOME/.local/bin/bat"
        fi

        for _plugin in zsh-autosuggestions zsh-syntax-highlighting; do
          if [[ ! -d "$HOME/.zsh/$_plugin" ]]; then
            print_info "Installing $_plugin to ~/.zsh/..."
            git clone --depth 1 "https://github.com/zsh-users/$_plugin" "$HOME/.zsh/$_plugin"
          else
            print_info "$_plugin already installed, skipping"
          fi
        done
        unset _plugin

        install_blesh
      fi
      ;;

    debian|ubuntu)
      sudo apt-get update -qq
      sudo apt-get install -y fzf bat bash-completion zsh-autosuggestions zsh-syntax-highlighting
      if command -v starship &>/dev/null; then
        print_info "starship already installed, skipping curl install"
      else
        print_info "Installing Starship via official installer (not in apt repos)..."
        curl -sS https://starship.rs/install.sh | sh -s -- --yes
      fi
      if [[ "$_update_mode" == true ]]; then update_blesh; else install_blesh; fi
      ;;

    *)
      print_warning "Unknown OS '$os' — skipping package installation."
      print_warning "Install manually: starship fzf bat zsh-autosuggestions zsh-syntax-highlighting"
      return 0
      ;;
  esac

  echo ""
  print_success "Package installation complete."
}


# Main execution
main() {
  echo ""
  echo "========================================"
  echo "  Dotfiles Bootstrap"
  echo "========================================"
  echo ""

  # Parse flags
  _update_mode=false
  for arg in "$@"; do
    [[ "$arg" == "--update" ]] && _update_mode=true
  done

  if [[ "$_update_mode" == true ]]; then
    print_info "Running in UPDATE mode — refreshing packages only, skipping dotfile linking."
  fi

  # Check if we're in the right directory
  if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    print_error "This doesn't appear to be a git repository!"
    print_error "Please run this script from your dotfiles repository."
    exit 1
  fi

  # Install required packages
  echo ""
  install_packages

  if [[ "$_update_mode" != true ]]; then
    # Link dotfiles
    echo ""
    link_dotfiles

    # Merge gitconfig aliases
    echo ""
    merge_gitconfig_aliases
  fi

  echo ""
  echo "========================================"
  print_success "Bootstrap complete!"
  echo "========================================"
  echo ""
  print_info "Next steps:"
  if [[ "$(uname)" == "Darwin" ]]; then
    echo "  1. Open a new terminal or: source ~/.zshrc (zsh) | source ~/.bashrc (bash)"
  else
    echo "  1. Open a new terminal or run: source ~/.bashrc"
  fi
  echo "  2. Verify starship prompt, Ctrl+R fzf history, and man page colors"
  echo "  3. Remove backup directory if everything looks good"
  echo ""
}

# Run main function
main "$@"
