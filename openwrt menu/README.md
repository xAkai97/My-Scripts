# OpenWrt Build Menu Script

This folder contains:

- `openwrt_menu.sh`: main OpenWrt build dashboard
- `git_menu.sh`: dedicated Git dashboard launched from the main menu
- `install.sh`: installer that sets executable bits and can create a launcher symlink

## What It Does

The script provides quick actions for:

- Updating and installing feeds
- Running `menuconfig` and `defconfig`
- Downloading sources (`make download -j$(nproc)`)
- Automated pipeline (`0`): runs `1 -> 3 -> d -> 3`, then confirms custom/debug build (debug saves to `build_error.log`)
- Custom build (`4`): use all cores (`nproc`) or choose a job count (`1..nproc`)
- Debug build (`5`, `-j1`) saved to `build_error.log`
- Cleaning (`clean`, `dirclean`)
- Finding recently built images
- Optional ownership/permission fixes for build output directories
- Saving debug build logs to `build_error.log` via option (`5`)
- Git actions are handled in a separate menu script (`git_menu.sh`)

It also auto-detects your OpenWrt root by searching upward for `scripts/feeds`, so you can launch it from a subfolder.

## Requirements

- Bash (`bash`)
- Standard Linux utilities: `grep`, `cut`, `find`, `dirname`, `nproc`
- OpenWrt source tree with `scripts/feeds`
- Optional for permission fix action: `sudo`
- Optional for Git menu: `git`

## Setup

1. Put all scripts in the same folder: `openwrt_menu.sh`, `git_menu.sh`, and `install.sh`.
2. Keep that folder accessible from your OpenWrt repo workflow.
3. Run installer:

```bash
bash ./install.sh --link --add-path
```

4. Reload shell and launch:

```bash
source ~/.bashrc
menu
```

## WSL Usage (Windows)

1. Open your WSL distro terminal (Ubuntu/Debian/etc.).
2. `cd` into the folder containing these scripts inside WSL.
3. Run installer:

```bash
bash ./install.sh --link --add-path
```

4. Reload shell and launch:

```bash
source ~/.bashrc
menu
```

Notes for WSL:

- Scripts should live in a Linux path (for example `/home/<user>/scripts/`) not a Windows-mounted path like `/mnt/c/...` — WSL performance and permissions are better on the Linux filesystem.
- `openwrt_menu.sh` auto-detects the OpenWrt root upward from wherever you run it, so you can keep the scripts outside the OpenWrt repo tree.
- Permission-fix option may prompt for your WSL sudo password.

## Native Linux Usage

Same flow as WSL:

```bash
cd /path/to/scripts
bash ./install.sh --link --add-path
source ~/.bashrc
menu
```

## Installer Options

`install.sh` supports an optional launcher symlink so you can run `menu` directly.

```bash
bash ./install.sh --link
```

Common options:

- `--link`: create launcher symlink (default `~/.local/bin/menu`)
- `--bin-dir <path>`: custom launcher directory
- `--launcher <name>`: custom launcher filename
- `--add-path`: append PATH export to shell rc file (requires `--link`)
- `--shell-rc <path>`: rc file to edit with `--add-path` (default `~/.bashrc`)
- `-f` / `--force`: overwrite existing launcher file/symlink

Examples:

```bash
# Basic launcher
bash ./install.sh --link

# Launcher + persist PATH in ~/.bashrc
bash ./install.sh --link --add-path

# Custom launcher name
bash ./install.sh --link --bin-dir "$HOME/bin" --launcher my-menu -f
```

## Other Bash-Compatible Environments

This script is written for Bash and should work in most Bash-capable systems. If an environment lacks tools like `nproc`, install coreutils equivalents or replace that call with a fixed `-j` value.

## Safety Notes

- Git hard reset is guarded by a confirmation prompt because it discards uncommitted changes.
- Permission fixes are limited to common build output dirs (`bin`, `build_dir`, `staging_dir`, `tmp`) and only run after confirmation.
- Failed commands now show a clear error and pause so output is visible.
- If the Git helper script is missing, the main menu shows a clear error instead of failing silently.

## Troubleshooting

- `Could not find OpenWrt root`: make sure you are in the OpenWrt repo tree where `scripts/feeds` exists.
- Build fails: check `build_error.log` if you used debug build (`5`).
- `Permission denied`: run `bash ./install.sh` (or `chmod +x openwrt_menu.sh git_menu.sh install.sh`) and ensure repo path is writable.
- Git pull rejected with `--ff-only`: your branch has diverged; rebase/merge manually.
