#!/bin/bash

# Exit on error for critical parts, but handle non-zero exits gracefully where expected
set -o pipefail

# Colors
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RED="\e[31m"
RESET="\e[0m"

# Print helper functions
info() {
    echo -e "${BLUE}🚀 $1${RESET}"
}

section() {
    echo -e "${GREEN}🧹 $1...${RESET}"
}

warn() {
    echo -e "${YELLOW}⚠️ $1${RESET}"
}

error() {
    echo -e "${RED}❌ $1${RESET}"
}

# Ensure script is run with root privileges where required (sudo)
check_sudo() {
    if ! sudo -v &>/dev/null; then
        error "Sudo privileges are required for some cleanup tasks."
        exit 1
    fi
}

# Helper to run a command if it exists (no command name repetition required)
run_if_exists() {
    local cmd="$1"
    if command -v "$cmd" &> /dev/null; then
        section "Cleaning $cmd cache"
        "$@"
    else
        warn "$cmd is not installed."
    fi
    echo ""
}

# Clean AUR helper cache safely and non-interactively
clean_aur() {
    local helper="$1"
    if command -v "$helper" &> /dev/null; then
        section "Clearing $helper AUR cache"
        yes | "$helper" -Scc --noconfirm
    else
        warn "$helper not installed."
    fi
    echo ""
}

# Get available disk space in 1K blocks
get_free_space() {
    df -P -k / | tail -1 | awk '{print $4}'
}

# Convert KB to human-readable format
human_readable() {
    local kb=$1
    awk -v kb="$kb" 'BEGIN {
        if (kb >= 1048576) {
            printf "%.2f GB\n", kb/1048576
        } else if (kb >= 1024) {
            printf "%.2f MB\n", kb/1024
        } else {
            printf "%d KB\n", kb
        }
    }'
}

info "Starting Full Arch Linux Cleanup..."
echo ""

# ---------------------------------------------
# 0. Record initial free space & show disk usage
# ---------------------------------------------
initial_free=$(get_free_space)

echo -e "${YELLOW}📊 Disk usage BEFORE cleanup:${RESET}"
df -h /
echo ""

# Verify sudo access
check_sudo

# ---------------------------------------------
# 1. Clear pacman cache safely
# ---------------------------------------------
section "Clearing pacman cache"
# pacman -Scc deletes everything, leaving no way to downgrade if an update breaks the system.
# paccache -r (from pacman-contrib) keeps the last 2 versions by default, which is much safer.
if command -v paccache &> /dev/null; then
    echo "Using paccache to clear unused package versions (retaining last 2)..."
    sudo paccache -rk2
    sudo paccache -ruk0 # Remove all uninstalled package cache
else
    warn "paccache not found (install pacman-contrib). Falling back to pacman -Sc (retains installed packages)..."
    sudo pacman -Sc --noconfirm
fi
echo ""

# ---------------------------------------------
# 2 & 3. Clear AUR cache (paru/yay)
# ---------------------------------------------
clean_aur paru
clean_aur yay

# ---------------------------------------------
# 4. Remove orphan packages
# ---------------------------------------------
section "Removing orphan packages"
# Get the list of orphans. pacman -Qtdq returns 1 if no orphans found.
orphans=$(pacman -Qtdq)
if [[ -n "$orphans" ]]; then
    sudo pacman -Rns --noconfirm $orphans
else
    echo -e "${YELLOW}No orphan packages found.${RESET}"
fi
echo ""

# ---------------------------------------------
# 5. Clear systemd journal logs
# ---------------------------------------------
section "Clearing systemd journal logs"
sudo journalctl --vacuum-size=100M
echo ""

# ---------------------------------------------
# 6. Clean huge log files
# ---------------------------------------------
section "Cleaning large log files (>50MB)"
# Restrict search to /var/log to avoid scanning the entire filesystem
sudo find /var/log -type f -size +50M -exec truncate -s 0 {} \;
echo ""

# ---------------------------------------------
# 7. Remove leftover core dumps safely
# ---------------------------------------------
section "Removing core dumps"
# Scanning / for core* is extremely slow and dangerous (can delete non-core dump files).
# We vacuum using coredumpctl if available, and clear /var/lib/systemd/coredump/
if command -v coredumpctl &> /dev/null; then
    sudo coredumpctl vacuum --keep-free=1024M 2>/dev/null || true
fi
if [ -d /var/lib/systemd/coredump ]; then
    sudo find /var/lib/systemd/coredump -type f -delete 2>/dev/null || true
fi
echo ""

# ---------------------------------------------
# 8. Kernel cleanup
# ---------------------------------------------
echo -e "${YELLOW}🧨 Checking for old kernels...${RESET}"
if command -v mhwd-kernel &> /dev/null; then
    echo -e "${GREEN}Manjaro detected — removing old kernels...${RESET}"
    sudo mhwd-kernel -li | grep linux | awk '{print $2}' | tail -n +2 | \
    xargs -I {} sudo mhwd-kernel -r {}
else
    echo -e "${GREEN}✔ No old kernels found (Arch does not keep old kernels).${RESET}"
fi
echo ""

# ---------------------------------------------
# 9 & 10. Clear user cache selectively
# ---------------------------------------------
section "Clearing user cache"
# Deleting all of ~/.cache/* blindly will break current sessions of running applications (browsers, Discord, etc.).
# We clear files older than 14 days, excluding critical browser directories.
find ~/.cache -type f -mtime +14 \
    -not -path "*/mozilla/*" \
    -not -path "*/google-chrome/*" \
    -not -path "*/chromium/*" \
    -delete 2>/dev/null || true

# Clean up empty cache directories
find ~/.cache -type d -empty -delete 2>/dev/null || true

section "Clearing thumbnail cache"
rm -rf ~/.cache/thumbnails/* 2>/dev/null || true
echo ""

# ---------------------------------------------
# 11. Remove temp build directories safely
# ---------------------------------------------
section "Removing temporary build directories"
# Blindly running rm -rf /tmp/* will delete active X11, Wayland, ssh, tmux, and systemd sockets, causing system instability.
# Instead, remove only files/folders that haven't been modified in 2 days.
for tmp_dir in /tmp /var/tmp; do
    sudo find "$tmp_dir" -mindepth 1 -mtime +2 -exec rm -rf {} + 2>/dev/null || true
done
echo ""

# ---------------------------------------------
# 12. Empty trash
# ---------------------------------------------
section "Emptying trash"
rm -rf ~/.local/share/Trash/* 2>/dev/null || true
echo ""

# ---------------------------------------------
# 13-19. Dev tools cache cleaning
# ---------------------------------------------
run_if_exists docker system prune -a -f --volumes
run_if_exists npm cache clean --force
run_if_exists yarn cache clean
run_if_exists pnpm store prune
run_if_exists pip cache purge

if command -v cargo &> /dev/null; then
    section "Cleaning cargo cache"
    if command -v cargo-cache &> /dev/null; then
        cargo cache -a
    else
        warn "cargo-cache is not installed. Run 'cargo install cargo-cache' to clean cargo cache."
    fi
else
    warn "cargo is not installed."
fi
echo ""

run_if_exists flatpak uninstall --unused -y

# ---------------------------------------------
# 20. Show disk usage AFTER cleanup
# ---------------------------------------------
echo -e "${YELLOW}📉 Disk usage AFTER cleanup:${RESET}"
df -h /
echo ""

# Calculate freed space
final_free=$(get_free_space)
cleared_kb=$((final_free - initial_free))

if (( cleared_kb > 0 )); then
    cleared_space=$(human_readable "$cleared_kb")
    info "DONE! Your system has been fully deep cleaned! Freed ${cleared_space} of disk space."
else
    info "DONE! Your system has been fully deep cleaned!"
fi
