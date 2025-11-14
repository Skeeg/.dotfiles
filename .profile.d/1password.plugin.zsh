#!/bin/bash

# 1Password convenience functions
# 1PASSWORD_ACCOUNT should be set in _personalprefs.plugin.zsh and exported.  Or you can add it as another input parameter to these functions if you prefer.

update_1password_item() {
  # This function updates a 1Password item with the given username and password as a unique field.  The username is used as the field name, it will be stored as a password type field with the value of password in a protected manner.
  if [ $# -ne 3 ]; then
    echo "Error: update_1password_item requires 3 arguments: item_name, field, password" >&2
    return 1
  fi
  
  local item_name="$1"
  local field="$2"
  local password="$3"
  
  op item edit --account "$1PASSWORD_ACCOUNT" "$item_name" "${field}[password]=${password}"
}

get_1password_field() {
  # This function retrieves a specific field from a 1Password item.
  if [ $# -ne 2 ]; then
    echo "Error: get_1password_item requires 2 arguments: item_name, field" >&2
    return 1
  fi
  
  local item_name="$1"
  local field="$2" # Field is generally structured as a username or environment variable

  op item get --account "$1PASSWORD_ACCOUNT" "$item_name" --fields label="$field" --reveal
}
