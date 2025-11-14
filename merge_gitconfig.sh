#!/usr/bin/env zsh
#
# Git Config Merge Script
#
# This script checks if the git aliases from .profile.d/merge_content/.gitconfig_aliases
# are present in ~/.gitconfig and adds them if missing.
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
GITCONFIG_ALIASES="$DOTFILES_DIR/.profile.d/merge_content/.gitconfig_aliases"
USER_GITCONFIG="$HOME/.gitconfig"

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

# Main function
main() {
  # Check if source aliases file exists
  if [[ ! -f "$GITCONFIG_ALIASES" ]]; then
    print_error "Aliases file not found: $GITCONFIG_ALIASES"
    exit 1
  fi
  
  # Create .gitconfig if it doesn't exist
  if [[ ! -f "$USER_GITCONFIG" ]]; then
    print_warning "~/.gitconfig does not exist, creating it..."
    touch "$USER_GITCONFIG"
  fi
  
  # Read the aliases from the source file
  local aliases_content
  aliases_content=$(cat "$GITCONFIG_ALIASES")
  
  # Check if the [alias] section already exists in user's gitconfig
  if grep -q '^\[alias\]' "$USER_GITCONFIG"; then
    print_info "[alias] section found in ~/.gitconfig"
    
    # Check if any of our custom aliases are missing
    local missing_aliases=false
    local aliases_to_add=""
    
    # Extract alias names from our aliases file (lines with '=' that aren't comments)
    while IFS= read -r line; do
      # Skip empty lines, comments, and the [alias] header
      [[ -z "$line" || "$line" =~ ^[[:space:]]*# || "$line" =~ ^\[alias\] ]] && continue
      
      # Extract alias name (everything before the '=')
      if [[ "$line" =~ ^[[:space:]]*([a-zA-Z0-9_-]+)[[:space:]]*= ]]; then
        local alias_name="${match[1]}"
        
        # Check if this alias exists in user's gitconfig
        if ! git config --file "$USER_GITCONFIG" --get "alias.$alias_name" &>/dev/null; then
          missing_aliases=true
          print_warning "Missing alias: $alias_name"
          aliases_to_add+="$line"$'\n'
        fi
      fi
    done < <(grep -v '^\[alias\]' "$GITCONFIG_ALIASES" || true)
    
    if [[ "$missing_aliases" == true ]]; then
      print_info "Adding missing aliases to ~/.gitconfig..."
      
      # Create a backup
      cp "$USER_GITCONFIG" "$USER_GITCONFIG.backup.$(date +%Y%m%d_%H%M%S)"
      
      # Find the [alias] section and add our aliases there
      # Use awk to insert aliases after the [alias] line
      awk -v aliases="$aliases_to_add" '
        /^\[alias\]/ {
          print
          if (!added) {
            printf "\n\t# Aliases from dotfiles repository\n"
            printf "%s", aliases
            added=1
          }
          next
        }
        { print }
      ' "$USER_GITCONFIG" > "$USER_GITCONFIG.tmp"
      
      mv "$USER_GITCONFIG.tmp" "$USER_GITCONFIG"
      print_success "Added missing aliases to ~/.gitconfig"
    else
      print_success "All aliases are already present in ~/.gitconfig"
    fi
  else
    print_info "[alias] section not found in ~/.gitconfig, adding all aliases..."
    
    # Create a backup if file is not empty
    if [[ -s "$USER_GITCONFIG" ]]; then
      cp "$USER_GITCONFIG" "$USER_GITCONFIG.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Append the entire aliases section
    echo "" >> "$USER_GITCONFIG"
    echo "# Aliases from dotfiles repository" >> "$USER_GITCONFIG"
    cat "$GITCONFIG_ALIASES" >> "$USER_GITCONFIG"
    
    print_success "Added [alias] section to ~/.gitconfig"
  fi
}

# Run main function
main
