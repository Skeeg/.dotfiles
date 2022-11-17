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

# Install

This repo clones into the `$HOME` path for consistent cross-machine configuration.
[See here for a tutorial on this approach][Dotfiles-Tutorial].

Run the [install script][Install-Script] below.

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Skeeg/.dotfiles/main/.personal/bin/install-dotfiles)"
```

What does this script do?

1. Clones the repo to `~/.personal/.cfg` for working tree at `~/` including:
	- A ZSH config file `.zshrc` with sensible defaults
	- A ZSH "personal" config file `.zshrc.local` with some tuning
	- `dotgit` alias to run git commands on this repo
	- A plethora of functions and methods from setting up command logging history, to aliases, and some useful functions.
2. Ignores any user files that aren't explicitly tracked
3. Installs app bundle with Homebrew...
    - [Visual Studio Code][VS-Code]
    - [Many others, see the full list][BrewFile]
    - There is [another Brewfile][PersonalBrew] stored as well that is not business oriented, but mainly here to show the methods for you to consider for experimentation.
4. Compiles an [Antibody][Antibody] bundle of ZSH plugins to load on shell init
5. Takes inputs for creating global git user config file
6. Establishes a [baseline gitignore][GitIgnore] spec for common exclusions.

> 💁‍♂️ `.zshrc` will also source `.zshrc.local` if it exists, so add any personal configs there.

### Optional Apps

Other apps can be manually installed, e.g recommended: [Alfred][Alfred], [Insomnia][Insomnia], [Warp][Warp].

Check those out and you can run this command at any time.

```
brew install alfred insomnia warp
```

# Links

- [DotFiles tutorial][Dotfiles-Tutorial]
- [Homebrew][Homebrew]
- [Oh-My-ZSH][Oh-My-ZSH]
- [Antibody][Antibody]
