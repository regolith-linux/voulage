#!/bin/bash
set -e
set -x


# Configure hostname

echo "seed" > /etc/hostname

# Base dependencies

echo "deb https://deb.debian.org/debian trixie main contrib non-free non-free-firmware" > /etc/apt/sources.list

apt update
DEBIAN_FRONTEND=noninteractive apt-get install -y --upgrade --no-install-recommends wget pgp locales

# Regolith Deb Repo 

wget -qO - https://archive.regolith-desktop.com/regolith.key | gpg --dearmor | tee /usr/share/keyrings/regolith-archive-keyring.gpg > /dev/null

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/regolith-archive-keyring.gpg] https://archive.regolith-desktop.com/debian/unstable trixie main" > /etc/apt/sources.list.d/regolith.list

apt update
# Locale generation

echo "en_US.UTF-8 UTF-8" > /etc/locale.gen

# Complete dependency set

DEBIAN_FRONTEND=noninteractive apt-get install -y --upgrade lightdm lightdm-gtk-greeter regolith-lightdm-config regolith-desktop regolith-session-flashback regolith-session-sway regolith-look-lascaille vim firmware-linux firefox gnome-terminal 

# Remove yourself
rm inner.sh
