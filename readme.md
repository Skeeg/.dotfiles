[Homebrew]: https://docs.brew.sh/
[Oh-My-ZSH]: https://github.com/ohmyzsh/ohmyzsh/
[Antibody]: https://getantibody.github.io/
[Alfred]: https://www.alfredapp.com/
[Insomnia]: https://insomnia.rest/
[Warp]: https://www.warp.dev/
[VS-Code]: https://code.visualstucdio.com/
[Dotfiles-Tutorial]: https://www.atlassian.com/git/tutorials/dotfiles
[ACloudGuru-Repo]: https://github.com/ACloudGuru/node-dev-dotfiles
[Install-Script]: https://github.com/Skeeg/.dotfiles/blob/main/.personal/bin/install-dotfiles
[BrewFile]: https://github.com/Skeeg/.dotfiles/blob/main/.personal/WorkBrewfile
[PersonalBrew]: https://github.com/Skeeg/.dotfiles/blob/main/.personal/PersonalBrewfile
[GitIgnore]: https://github.com/Skeeg/.dotfiles/blob/main/.config/git/ignore

# Introduction

This can be considered an extension from another [public repository][ACloudGuru-Repo] of similar nature.

It is intended to be used to capture _personal_ preferences and environment configurations.  

> ⚠️ Bear in mind that there is some personal application preferences assumed here that are opinionated for MacOS, and tooling that you may not personally care about outside of working for the same organization as myself.  I may evolve this over time, but ultimately have created this to satisfy my personal preferences at this time.

# Personal DotFiles

Version managed user environment configuration for developers running ZSH.

> ⚠️ This is a public repository, and as a general reminder and guidance, be aware of secrets and PII.
> Don't commit personal data or secrets.

---

# Prerequisites

## Xcode

On a new machine Xcode is required for most anything.

Open a terminal, enter the following, then go for a coffee ☕...

```sh
xcode-select --install
```

## Homebrew

Homebrew manages most of the utilities and apps we need to do the job.

Visit [https://brew.sh](https://brew.sh) to confirm install command is up to date.

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
```

Follow "Next Steps" from the Homebrew installer's terminal output.

Ensure it's working before proceeding...

```sh
brew -v
```

# Installation

This repository uses a symlink-based approach to manage dotfiles. The repository can be cloned anywhere on your system, and the bootstrap script will create symlinks from your home directory to the files in the repository.

## Quick Start

1. **Clone the repository** (can be anywhere, but recommended location):

```sh
git clone https://github.com/Skeeg/.dotfiles.git ~/repo/.dotfiles
cd ~/repo/.dotfiles
```

2. **Run the bootstrap script**:

```sh
./bootstrap.sh
```

The bootstrap script will:
- Create symlinks for all dotfiles and directories from the repository to your `$HOME` directory
- Automatically backup any existing files/directories to `~/.dotfiles_backup_<timestamp>`
- Merge git aliases from `.profile.d/merge_content/.gitconfig_aliases` into your `~/.gitconfig` (without removing existing content)
- Preserve the ability to update dotfiles by pulling changes from the repository

## What Gets Linked

The bootstrap process creates symlinks for:
- Configuration files (`.zshrc`, `.zprofile`, `.bash_profile`, etc.)
- Configuration directories (`.config/`, `.personal/`, `.profile.d/`, etc.)
- Other dotfiles and directories in the repository

The following items are excluded from symlinking:
- `.git/` (repository metadata)
- `bootstrap.sh` and `merge_gitconfig.sh` (bootstrap scripts)
- `readme.md` and documentation files
- `context_portal/` and Docker-related files
- `.profile.d/merge_content/` (used only for merging content, not linking)

## Updating Your Dotfiles

After the initial setup, you can update your dotfiles by:

1. **Pull latest changes**:
```sh
cd ~/repo/.dotfiles  # or wherever you cloned the repo
git pull
```

2. **Re-run bootstrap** (optional, only if new files were added):
```sh
./bootstrap.sh
```

Since your home directory files are symlinked to the repository, most updates will be immediately reflected without re-running the bootstrap script.

## Git Config Aliases

The bootstrap script automatically checks if the git aliases defined in `.profile.d/merge_content/.gitconfig_aliases` are present in your `~/.gitconfig`. If they're missing, they will be added. This process:
- Creates `~/.gitconfig` if it doesn't exist
- Adds the `[alias]` section if it's missing
- Adds individual aliases that are missing (won't duplicate existing ones)
- Creates a backup of your gitconfig before making changes

You can also run the git config merge script independently:
```sh
./merge_gitconfig.sh
```

## Features

This dotfiles setup includes:
- A ZSH config file `.zshrc` with sensible defaults
- A ZSH "personal" config file `.zshrc.local` with additional tuning
- Useful git aliases for common workflows
- Command logging history functionality
- A collection of shell functions and aliases in `.profile.d/`
- Configuration for various development tools and environments

> 💁‍♂️ `.zshrc` will also source `.zshrc.local` if it exists, so add any personal configs there.

### Optional Apps

Other apps can be manually installed via Homebrew, e.g., recommended: [Alfred][Alfred], [Insomnia][Insomnia], [Warp][Warp].

```sh
brew install alfred insomnia warp
```

You can also use the Brewfiles included in `.personal/` directory to install work or personal app bundles:

```sh
# For work-related applications
brew bundle --file=~/.personal/WorkBrewfile

# For personal applications
brew bundle --file=~/.personal/PersonalBrewfile
```

---

# Migrating from Git Bare or Stow

If you're migrating from a git bare repository or GNU Stow approach:

1. **Backup your current setup**: Make sure you have a backup of any important configurations
2. **Remove old setup**:
   - For git bare: Remove the `.cfg` directory and any aliases/functions related to it
   - For stow: Unstow all packages with `stow -D <package-name>`
3. **Clone this repository** to your preferred location (e.g., `~/repo/.dotfiles`)
4. **Run the bootstrap script** which will handle everything via symlinks

The symlink approach is simpler and more dynamic than git bare or stow, requiring only standard shell commands and providing clear visibility of what's linked where.

# Links

- [DotFiles tutorial][Dotfiles-Tutorial]
- [Homebrew][Homebrew]
- [Oh-My-ZSH][Oh-My-ZSH]
- [Antibody][Antibody]
