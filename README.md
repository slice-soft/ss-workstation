# ss-workstation

SliceSoft's cross-OS **workstation onboarding** — dotfiles, configs and installers
that set up a full development environment on **CachyOS / Arch Linux** or **macOS**
with a single command.

## Quick start

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/slice-soft/ss-workstation/main/install.sh)
```

The dispatcher detects your OS, clones this **public** repo to
`~/dev/slicesoft/ss-workstation`, and runs the matching installer. No
authentication required.

> Already cloned? Just run `bash ~/dev/slicesoft/ss-workstation/install.sh`.

## What it sets up

- **Shell** — zsh + [starship](https://starship.rs) prompt, autosuggestions,
  syntax highlighting, [atuin](https://atuin.sh) history
- **Terminal** — kitty + [zellij](https://zellij.dev) multiplexer with a `dev`
  layout (nvim + lazygit + Claude Code)
- **Editor** — Neovim (lazy.nvim + LSP + Copilot + treesitter)
- **Runtimes** — [mise](https://mise.jdx.dev): Node 22 (LTS), Go 1.24, Python 3.12
- **CLI** — git, gh, lazygit, ripgrep, fd, fzf, bat, eza, btop, jq, …
- **npm globals** — Claude Code, Codex
- **Linux desktop only** — Hyprland (Wayland) + Waybar (with custom audio scripts)

## OS support

| OS | Scope |
|---|---|
| **CachyOS / Arch** | Full desktop: Wayland WM (Hyprland/Waybar) + terminal + editor + shell |
| **macOS** | Terminal + editor + shell (no tiling WM) |

## Structure

```
install.sh              # dispatcher — detects OS, clones repo, runs installer
linux/
  install.sh            # CachyOS/Arch installer (pacman + yay)
  packages.txt          # single source of truth for packages
  configs/              # Linux-only: hyprland, waybar (+ audio scripts)
macos/
  install.sh            # macOS installer (Homebrew)
  Brewfile              # single source of truth for packages
shared/
  configs/              # cross-OS: nvim, kitty, zellij, zsh, starship
```

## How dotfiles work

Configs are **symlinked** from this repo into `~/.config` (and `~/.zshrc`), so a
`git pull` here updates your live configs. Machine-specific bits are **not**
versioned and stay local:

- `~/.config/hypr/local.conf` — monitors / GPU (seeded from `local.conf.example`)
- `~/.zshrc.local` — personal aliases / environment (sourced at the end of `~/.zshrc`)

## After setup — join the SliceSoft ecosystem

This repo sets up your **machine**. To get the org's repos and docs:

```bash
gh auth login
gh repo clone slice-soft/slice-soft ~/dev/slicesoft/slice-soft
bash ~/dev/slicesoft/slice-soft/setup.sh   # clones every repo you can access
```
