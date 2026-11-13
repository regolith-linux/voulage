# Packages Release Tracker

The following packages are being maintained by Regolith core developers. All of
these packages are needed for a successful release of Regolith Desktop. But not
all of them are actively under development.

Some are quite stable, code-complete, or not recently updated from its upstream
project. For example `arc-icon-theme`, `dracula-gtk`, `fonts-nerd-fonts`, etc.
The value for `Need Release` for these packages in the table below probably
should read as `No`.

Other projects are actively being worked on. For example `i3status-rs`, `ilia`,
`regolith-control-center`, `regolith-session`, etc. The value for `Need Release`
for these packages in the table below can be either `Yes`, or `No`, depending
on the time during its SDLC.

## Need Release

There are two values available for `Need Release` in the table below:

- `No` indicates that the git tag defined in `testing/` package model file is
the latest commit in the git ref defined in `unstable/` package model file.
- `Yes` indicates that the git tag defined in `testing/` package model file is
**NOT** the latest commit in the git ref defined in `unstable/` package model file.

## List of Packages

<!-- AUTO_GENERATE_START -->
| Package⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀| Unstable | Testing | Changelog | Need Release |
|:------------------------------|:---------|:--------|:----------|:-------------|
| [arc-icon-theme](https://github.com/regolith-linux/arc-icon-theme) | `main` | `v20251012-1` | `bionic` | No |
| [ayu-theme](https://github.com/regolith-linux/ayu-theme) | `master` | `v0.2.4-1` | `bionic` | No |
| [childe](https://github.com/regolith-linux/childe) | `main` | `v0.1.4` | `focal` | [Yes](https://github.com/regolith-linux/childe/compare/v0.1.4...main) |
| [dracula-gtk](https://github.com/regolith-linux/dracula-gtk) | `master` | `v4.0.0+git20260824` | `focal` | No |
| [fonts-nerd-fonts](https://github.com/regolith-linux/fonts-nerd-fonts) | `debian` | `v3.5.1-2` | `focal` | No |
| [fonts-source-code-pro-ttf](https://github.com/regolith-linux/fonts-source-code-pro-ttf) | `main` | `v1.011-0ubuntu1-ppa3` | `disco` | No |
| [gruvbox-gtk](https://github.com/regolith-linux/gruvbox-gtk) | `master` | `v1.0.2-2` | `bionic` | No |
| [gtklock](https://github.com/regolith-linux/gtklock) | `master` | `v2.2.2` | `focal` | No |
| [i3status-rs](https://github.com/regolith-linux/i3status-rs_debian) | `ubuntu/v0.22.0` | `v0.22.2-2-ubuntu-jammy` | `focal` | [Yes](https://github.com/regolith-linux/i3status-rs_debian/compare/v0.22.2-2-ubuntu-jammy...ubuntu/v0.22.0) |
| [i3status-rs](https://github.com/regolith-linux/i3status-rs_debian) | `ubuntu/v0.32.1` | `v0.32.1-2` | `mantic` | [Yes](https://github.com/regolith-linux/i3status-rs_debian/compare/v0.32.1-2...ubuntu/v0.32.1) |
| [i3status-rs](https://github.com/regolith-linux/i3status-rs_debian) | `ubuntu/v0.40.0` | `v0.40.0-2` | `resolute` | [Yes](https://github.com/regolith-linux/i3status-rs_debian/compare/v0.40.0-2...ubuntu/v0.40.0) |
| [i3xrocks](https://github.com/regolith-linux/i3xrocks) | `master` | `v1.3.7` | `bionic` | No |
| [i3-next-workspace](https://github.com/regolith-linux/i3-next-workspace) | `main` | `v1.0.6` | `jammy` | [Yes](https://github.com/regolith-linux/i3-next-workspace/compare/v1.0.6...main) |
| [i3-snapshot](https://github.com/regolith-linux/i3-snapshot) | `master` | `v1.1-2ubuntu1-ppa2` | `bionic` | [Yes](https://github.com/regolith-linux/i3-snapshot/compare/v1.1-2ubuntu1-ppa2...master) |
| [i3-swap-focus](https://github.com/regolith-linux/i3-swap-focus) | `master` | `v0.4.5` | `focal` | [Yes](https://github.com/regolith-linux/i3-swap-focus/compare/v0.4.5...master) |
| [i3-wm](https://github.com/regolith-linux/i3-wm) | `main` | `v4.22-3` | `unstable` | No |
| [ilia](https://github.com/regolith-linux/ilia) | `main` | `v0.19.2` | `jammy` | [Yes](https://github.com/regolith-linux/ilia/compare/v0.19.2...main) |
| [lago](https://github.com/regolith-linux/lago) | `main` | `v0.2.0-2` | `focal` | [Yes](https://github.com/regolith-linux/lago/compare/v0.2.0-2...main) |
| [libtrawldb](https://github.com/regolith-linux/libtrawldb) | `master` | `v0.1-4` | `focal` | [Yes](https://github.com/regolith-linux/libtrawldb/compare/v0.1-4...master) |
| [nordic](https://github.com/regolith-linux/nordic) | `main` | `v2.2.0+git20260723-1` | `focal` | No |
| [picom](https://github.com/regolith-linux/picom) | `main` | `v11.2.4` | `jammy` | No |
| [plymouth-theme-regolith](https://github.com/regolith-linux/plymouth-theme-regolith) | `master` | `v1.2.3` | `focal` | No |
| [regolith-archive-keyring](https://github.com/regolith-linux/regolith-archive-keyring) | `main` | `v0.1.0` | `jammy` | No |
| [regolith-avizo](https://github.com/regolith-linux/avizo) | `master` | `v0.1.7` | `focal` | No |
| [regolith-compositor-compton-glx](https://github.com/regolith-linux/regolith-compositor-compton-glx) | `master` | `v1.2.4` | `focal` | No |
| [regolith-compositor-none](https://github.com/regolith-linux/regolith-compositor-none) | `master` | `v1.0.4-2` | `bionic` | [Yes](https://github.com/regolith-linux/regolith-compositor-none/compare/v1.0.4-2...master) |
| [regolith-compositor-picom-glx](https://github.com/regolith-linux/regolith-compositor-picom-glx) | `master` | `v1.4.1-1` | `focal` | No |
| [regolith-compositor-xcompmgr](https://github.com/regolith-linux/regolith-compositor-xcompmgr) | `master` | `v1.4.1-1` | `focal` | No |
| [regolith-control-center](https://github.com/regolith-linux/regolith-control-center) | `regolith/1%43.0-1` | `v1.43.1-9-gnome-43` | `lunar` | [Yes](https://github.com/regolith-linux/regolith-control-center/compare/v1.43.1-9-gnome-43...regolith/1%43.0-1) |
| [regolith-control-center](https://github.com/regolith-linux/regolith-control-center) | `regolith/46` | `v1.46.0-5-gnome-46` | `noble` | [Yes](https://github.com/regolith-linux/regolith-control-center/compare/v1.46.0-5-gnome-46...regolith/46) |
| [regolith-control-center](https://github.com/regolith-linux/regolith-control-center) | `regolith/48` | `v1.48.1-10-gnome-48` | `plucky` | [Yes](https://github.com/regolith-linux/regolith-control-center/compare/v1.48.1-10-gnome-48...regolith/48) |
| [regolith-control-center](https://github.com/regolith-linux/regolith-control-center) | `regolith/49` | `v1.49.0-4-gnome-49` | `questing` | [Yes](https://github.com/regolith-linux/regolith-control-center/compare/v1.49.0-4-gnome-49...regolith/49) |
| [regolith-control-center](https://github.com/regolith-linux/regolith-control-center) | `regolith/50` | `v1.50.5-1-gnome-50` | `resolute` | No |
| [regolith-control-center](https://github.com/regolith-linux/regolith-control-center) | `ubuntu/jammy` | `v1.41.20-ubuntu-jammy` | `jammy` | [Yes](https://github.com/regolith-linux/regolith-control-center/compare/v1.41.20-ubuntu-jammy...ubuntu/jammy) |
| [regolith-debootstick-setup](https://github.com/regolith-linux/regolith-debootstick-setup) | `main` | n/a | `trixie` | No |
| [regolith-default-settings](https://github.com/regolith-linux/regolith-default-settings) | `main` | `v2.0.6` | `focal` | [Yes](https://github.com/regolith-linux/regolith-default-settings/compare/v2.0.6...main) |
| [regolith-desktop](https://github.com/regolith-linux/regolith-desktop) | `main` | `v4.11.0` | `jammy` | No |
| [regolith-displayd](https://github.com/regolith-linux/regolith-displayd) | `master` | `v0.5.0` | `jammy` | [Yes](https://github.com/regolith-linux/regolith-displayd/compare/v0.5.0...master) |
| [regolith-distro-ubuntu](https://github.com/regolith-linux/regolith-distro-ubuntu) | `main` | `v2.0.0-3` | `focal` | [Yes](https://github.com/regolith-linux/regolith-distro-ubuntu/compare/v2.0.0-3...main) |
| [regolith-ftue](https://github.com/regolith-linux/regolith-ftue) | `main` | `v2.2.3` | `focal` | No |
| [regolith-i3xrocks-config](https://github.com/regolith-linux/regolith-i3xrocks-config) | `master` | `v6.0.0` | `focal` | No |
| [regolith-inputd](https://github.com/regolith-linux/regolith-inputd) | `master` | `v0.5.0` | `jammy` | [Yes](https://github.com/regolith-linux/regolith-inputd/compare/v0.5.0...master) |
| [regolith-lightdm-config](https://github.com/regolith-linux/regolith-lightdm-config) | `master` | `v1.4.0` | `jammy` | No |
| [regolith-look-default](https://github.com/regolith-linux/regolith-look-default) | `main` | `v0.9.0` | `focal` | No |
| [regolith-look-extra](https://github.com/regolith-linux/regolith-look-extra) | `main` | `v0.11.0` | `jammy` | No |
| [regolith-powerd](https://github.com/regolith-linux/regolith-powerd) | `master` | `v0.10.0` | `jammy` | No |
| [regolith-rofication](https://github.com/regolith-linux/regolith-rofication) | `master` | `v1.5.3` | `focal` | [Yes](https://github.com/regolith-linux/regolith-rofication/compare/v1.5.3...master) |
| [regolith-rofi-config](https://github.com/regolith-linux/regolith-rofi-config) | `master` | `v1.4.3-1` | `focal` | No |
| [regolith-session](https://github.com/regolith-linux/regolith-session) | `debian-bookworm` | `v1.1.14-3-debian-bookworm-debian-bookworm` | `jammy` | [Yes](https://github.com/regolith-linux/regolith-session/compare/v1.1.14-3-debian-bookworm-debian-bookworm...debian-bookworm) |
| [regolith-session](https://github.com/regolith-linux/regolith-session) | `main` | `v1.2.5-1` | `noble` | [Yes](https://github.com/regolith-linux/regolith-session/compare/v1.2.5-1...main) |
| [regolith-sway-touchpad-gestures](https://github.com/regolith-linux/regolith-sway-touchpad-gestures) | `main` | `v0.1.0-4` | `noble` | [Yes](https://github.com/regolith-linux/regolith-sway-touchpad-gestures/compare/v0.1.0-4...main) |
| [regolith-system-ubuntu](https://github.com/regolith-linux/regolith-system-ubuntu) | `main` | `v1.0.1-1` | `focal` | [Yes](https://github.com/regolith-linux/regolith-system-ubuntu/compare/v1.0.1-1...main) |
| [regolith-wm-config](https://github.com/regolith-linux/regolith-wm-config) | `main` | `v4.12.0` | `jammy` | [Yes](https://github.com/regolith-linux/regolith-wm-config/compare/v4.12.0...main) |
| [solarc-theme](https://github.com/regolith-linux/solarc-theme) | `master` | `v800c997-5` | `focal` | No |
| [sway-audio-idle-inhibit](https://github.com/regolith-linux/SwayAudioIdleInhibit) | `main` | `v2.0.4` | `jammy` | [Yes](https://github.com/regolith-linux/SwayAudioIdleInhibit/compare/v2.0.4...main) |
| [sway-regolith](https://github.com/regolith-linux/sway-regolith) | `package-sway-v1.12` | `v1.10-2` | `stonking` | [Yes](https://github.com/regolith-linux/sway-regolith/compare/v1.10-2...package-sway-v1.12) |
| [sway-regolith](https://github.com/regolith-linux/sway-regolith) | `packaging/v1.7-regolith` | `v1.7-9-ubuntu-jammy` | `jammy` | No |
| [sway-regolith](https://github.com/regolith-linux/sway-regolith) | `packaging/v1.9-regolith` | `v1.9-18` | `noble` | No |
| [sway-regolith](https://github.com/regolith-linux/sway-regolith) | `packaging/v1.10-regolith` | `v1.10-2` | `trixie` | No |
| [sway-regolith](https://github.com/regolith-linux/sway-regolith) | `packaging/v1.11-regolith` | `v1.11.2-1` | `resolute` | [Yes](https://github.com/regolith-linux/sway-regolith/compare/v1.11.2-1...packaging/v1.11-regolith) |
| [trawl](https://github.com/regolith-linux/trawl) | `master` | `v0.3.0` | `jammy` | No |
| [ubiquity-slideshow-regolith](https://github.com/regolith-linux/ubiquity-slideshow-regolith) | `master` | `v202` | `jammy` | [Yes](https://github.com/regolith-linux/ubiquity-slideshow-regolith/compare/v202...master) |
| [whitesur-gtk-theme](https://github.com/regolith-linux/WhiteSur-gtk-theme) | `debian` | `v1.2-2026.09.10` | `focal` | No |
| [xdg-desktop-portal-regolith](https://github.com/regolith-linux/xdg-desktop-portal-regolith) | `main` | `v0.3.11-1` | `jammy` | [Yes](https://github.com/regolith-linux/xdg-desktop-portal-regolith/compare/v0.3.11-1...main) |
| [xdg-desktop-portal-regolith](https://github.com/regolith-linux/xdg-desktop-portal-regolith) | `release/1.18` | `v0.3.11-2` | `jammy` | [Yes](https://github.com/regolith-linux/xdg-desktop-portal-regolith/compare/v0.3.11-2...release/1.18) |
| [xdg-desktop-portal-regolith](https://github.com/regolith-linux/xdg-desktop-portal-regolith) | `release/1.18-systemd` | `v0.3.11-3` | `jammy` | [Yes](https://github.com/regolith-linux/xdg-desktop-portal-regolith/compare/v0.3.11-3...release/1.18-systemd) |
| [xrescat](https://github.com/regolith-linux/xrescat) | `master` | `v1.2.1-4` | `focal` | No |
<!-- AUTO_GENERATE_END -->
