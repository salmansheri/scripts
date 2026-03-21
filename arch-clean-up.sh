#!/bin/bash

# Colors
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RED="\e[31m"
RESET="\e[0m"

echo -e "${BLUE}🚀 Starting Full Arch Linux Cleanup...${RESET}"
echo ""

# ---------------------------------------------
# 0. Show disk usage BEFORE cleanup
# ---------------------------------------------
echo -e "${YELLOW}📊 Disk usage BEFORE cleanup:${RESET}"
df -h /
echo ""

# ---------------------------------------------
# 1. Clear pacman cache (fully non-interactive)
# ---------------------------------------------
echo -e "${GREEN}🧹 Clearing pacman cache...${RESET}"
yes | sudo pacman -Scc --noconfirm
echo ""

# ---------------------------------------------
# 2. Clear paru AUR cache
# ---------------------------------------------
if command -v paru &> /dev/null; then
    echo -e "${GREEN}🧹 Clearing paru AUR cache...${RESET}"
    paru -Scc --noconfirm
else
    echo -e "${YELLOW}⚠️ Paru not installed.${RESET}"
fi
echo ""

# ---------------------------------------------
# 3. Clear yay AUR cache
# ---------------------------------------------
if command -v yay &> /dev/null; then
    echo -e "${GREEN}🧹 Clearing yay AUR cache...${RESET}"
    yay -Scc --noconfirm
else
    echo -e "${YELLOW}⚠️ Yay not installed.${RESET}"
fi
echo ""

# ---------------------------------------------
# 4. Remove orphan packages
# ---------------------------------------------
echo -e "${GREEN}🗑️ Removing orphan packages...${RESET}"
orphans=$(pacman -Qtdq)
if [[ -n "$orphans" ]]; then
    sudo pacman -Rns $orphans --noconfirm
else
    echo -e "${YELLOW}No orphan packages found.${RESET}"
fi
echo ""

# ---------------------------------------------
# 5. Clear systemd journal logs
# ---------------------------------------------
echo -e "${GREEN}🧼 Clearing systemd journal logs...${RESET}"
sudo journalctl --vacuum-size=100M
echo ""

# ---------------------------------------------
# 6. Clean huge log files
# ---------------------------------------------
echo -e "${GREEN}🗄️ Cleaning large log files (>50MB)...${RESET}"
sudo find /var/log -type f -size +50M -exec truncate -s 0 {} \;
echo ""

# ---------------------------------------------
# 7. Remove leftover core dumps
# ---------------------------------------------
echo -e "${GREEN}💥 Removing core dumps...${RESET}"
sudo find / -name "core*" -type f -delete 2>/dev/null
echo ""

# ---------------------------------------------
# 8. Kernel cleanup (Arch does NOT store old kernels)
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
# 9. Clear user cache
# ---------------------------------------------
echo -e "${GREEN}🧽 Clearing user cache...${RESET}"
rm -rf ~/.cache/*
echo ""

# ---------------------------------------------
# 10. Clear thumbnails
# ---------------------------------------------
echo -e "${GREEN}🖼️ Clearing thumbnail cache...${RESET}"
rm -rf ~/.cache/thumbnails/*
echo ""

# ---------------------------------------------
# 11. Remove temp build directories
# ---------------------------------------------
echo -e "${GREEN}⚒️ Removing temporary build directories...${RESET}"
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*
echo ""

# ---------------------------------------------
# 12. Empty trash
# ---------------------------------------------
echo -e "${GREEN}🗑️ Emptying trash...${RESET}"
rm -rf ~/.local/share/Trash/*
echo ""

# ---------------------------------------------
# 13. Clean Docker
# ---------------------------------------------
if command -v docker &> /dev/null; then
    echo -e "${GREEN}🐳 Cleaning Docker system...${RESET}"
    docker system prune -a -f --volumes
else
    echo -e "${YELLOW}⚠️ Docker not installed.${RESET}"
fi
echo ""

# ---------------------------------------------
# 14. Clean npm cache
# ---------------------------------------------
if command -v npm &> /dev/null; then
    echo -e "${GREEN}📦 Cleaning npm cache...${RESET}"
    npm cache clean --force
fi
echo ""

# ---------------------------------------------
# 15. Clean yarn cache
# ---------------------------------------------
if command -v yarn &> /dev/null; then
    echo -e "${GREEN}🧶 Cleaning yarn cache...${RESET}"
    yarn cache clean
fi
echo ""

# ---------------------------------------------
# 16. Clean pnpm store
# ---------------------------------------------
if command -v pnpm &> /dev/null; then
    echo -e "${GREEN}📦 Cleaning pnpm store...${RESET}"
    pnpm store prune
fi
echo ""

# ---------------------------------------------
# 17. Clean pip cache
# ---------------------------------------------
if command -v pip &> /dev/null; then
    echo -e "${GREEN}🐍 Cleaning pip cache...${RESET}"
    pip cache purge
fi
echo ""

# ---------------------------------------------
# 18. Clean cargo cache
# ---------------------------------------------
if command -v cargo &> /dev/null; then
    echo -e "${GREEN}🦀 Cleaning cargo cache...${RESET}"
    cargo cache -a 2>/dev/null || echo "Install 'cargo-cache' to clean cargo properly."
fi
echo ""

# ---------------------------------------------
# 19. Clean Flatpak
# ---------------------------------------------
if command -v flatpak &> /dev/null; then
    echo -e "${GREEN}📦 Cleaning Flatpak...${RESET}"
    flatpak uninstall --unused -y
    flatpak remove --unused -y
fi
echo ""

# ---------------------------------------------
# 20. Show disk usage AFTER cleanup
# ---------------------------------------------
echo -e "${YELLOW}📉 Disk usage AFTER cleanup:${RESET}"
df -h /

echo ""
echo -e "${GREEN}🎉 DONE! Your system has been fully deep cleaned!${RESET}"
