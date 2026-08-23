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
- **Linux desktop only** — Hyprland (Wayland, uwsm-managed) + Waybar (with custom
  audio scripts), running as a systemd user service so it restarts on its own

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
  configs/              # Linux-only: hyprland, waybar (+ audio scripts), systemd units
macos/
  install.sh            # macOS installer (Homebrew)
  Brewfile              # single source of truth for packages
shared/
  configs/              # cross-OS: nvim, kitty, zellij, zsh, starship
  makefiles/base.mk     # shared build commands, included by every repo's Makefile
```

## How dotfiles work

Configs are **symlinked** from this repo into `~/.config` (and `~/.zshrc`), so a
`git pull` here updates your live configs. Machine-specific bits are **not**
versioned and stay local:

- `~/.config/hypr/local.conf` — monitors / GPU (seeded from `local.conf.example`)
- `~/.zshrc.local` — personal aliases / environment (sourced at the end of `~/.zshrc`)

## Pick the uwsm session at login

At your first login after setup, choose **"Hyprland (uwsm-managed)"** in the
session selector (top right in SDDM). The display manager remembers it, so it is
a one-time step.

uwsm starts Hyprland as a proper systemd user session, which is what makes
`graphical-session.target` activate — and that target is what pulls up
`waybar.service`. Because the unit carries `Restart=on-failure`, the bar comes
back on its own when it crashes, including after an update replaces glibc, GTK
or Wayland underneath the running process.

If you log into the plain **"Hyprland"** session instead, `uwsm finalize` fails
and `hyprland.conf` falls back to launching `waybar` directly, exactly as before
— you just lose the auto-restart.

## Shared build tooling (`base.mk`)

Every SliceSoft repo shares one set of `make` commands (`setup`, `test`, `lint`,
`clean`, `check-secrets`) so any repo behaves the same. The installer symlinks
that base to a **fixed path in your home**:

```
~/.config/slicesoft/base.mk  ->  shared/makefiles/base.mk
```

Each repo's `Makefile` includes it from there — a stable absolute path, so it
works no matter where the repo is cloned:

```make
SS_BASE ?= $(HOME)/.config/slicesoft/base.mk
ifeq ($(wildcard $(SS_BASE)),)
    $(error SliceSoft base.mk not found — run the ss-workstation setup)
endif
include $(SS_BASE)
# ...then repo-specific targets (build, run, ...)
```

A `git pull` here updates the base everywhere at once. External contributors who
haven't run this setup just get a clear error and use the raw `go`/`npm`
commands from the repo's `CONTRIBUTING.md`.

## After setup — join the SliceSoft ecosystem

This repo sets up your **machine**. To get the org's repos and docs:

```bash
gh auth login
gh repo clone slice-soft/slice-soft ~/dev/slicesoft/slice-soft
bash ~/dev/slicesoft/slice-soft/setup.sh   # clones every repo you can access
```
