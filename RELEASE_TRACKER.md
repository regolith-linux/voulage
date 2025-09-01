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

- `Yes` indicates that the git tag defined in `testing` package model file is
the latest commit in the git ref defined in `unstable/` package model file.
- `No` indicates that the git tag defined in `testing/` package model file is
**NOT** the latest commit in the git ref defined in `unstable/` package model file.

## List of Packages

<!-- AUTO_GENERATE_START -->
| Package⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀| Unstable | Testing | Need Release |
|:------------------------------|:---------|:--------|:-------------|
| [arc-icon-theme](https://github.com/regolith-linux/arc-icon-theme) | `main` | `v20250203-1` | [Yes](https://github.com/regolith-linux/arc-icon-theme/compare/v20250203-1...main) |
| [armesto](https://github.com/regolith-linux/armesto) | `main` | `v0.2.1ubuntu1` | [Yes](https://github.com/regolith-linux/armesto/compare/v0.2.1ubuntu1...main) |
| [ayu-theme](https://github.com/regolith-linux/ayu-theme) | `master` | `v0.2.3-1` | [Yes](https://github.com/regolith-linux/ayu-theme/compare/v0.2.3-1...master) |
| [childe](https://github.com/regolith-linux/childe) | `main` | `v0.1.3` | [Yes](https://github.com/regolith-linux/childe/compare/v0.1.3...main) |
| [dracula-gtk](https://github.com/regolith-linux/dracula-gtk) | `master` | `v1.1.2` | [Yes](https://github.com/regolith-linux/dracula-gtk/compare/v1.1.2...master) |
| [fonts-jetbrains-mono](https://github.com/regolith-linux/fonts-jetbrains-mono) | `master` | `v1.0.2-1regolith1` | [Yes](https://github.com/regolith-linux/fonts-jetbrains-mono/compare/v1.0.2-1regolith1...master) |
| [fonts-materialdesignicons-webfont](https://github.com/regolith-linux/fonts-materialdesignicons-webfont) | `master` | `v1.6.50-4regolith1` | [Yes](https://github.com/regolith-linux/fonts-materialdesignicons-webfont/compare/v1.6.50-4regolith1...master) |
| [fonts-nerd-fonts](https://github.com/regolith-linux/fonts-nerd-fonts) | `debian` | `v2.1.0-3` | No |
| [fonts-source-code-pro-ttf](https://github.com/regolith-linux/fonts-source-code-pro-ttf) | `main` | `v1.011-0ubuntu1-ppa2` | [Yes](https://github.com/regolith-linux/fonts-source-code-pro-ttf/compare/v1.011-0ubuntu1-ppa2...main) |
| [gruvbox-gtk](https://github.com/regolith-linux/gruvbox-gtk) | `master` | `v1.0.2-1` | [Yes](https://github.com/regolith-linux/gruvbox-gtk/compare/v1.0.2-1...master) |
| [gtklock](https://github.com/regolith-linux/gtklock) | `master` | `v2.2.1` | [Yes](https://github.com/regolith-linux/gtklock/compare/v2.2.1...master) |
| [i3status-rs](https://github.com/regolith-linux/i3status-rs_debian) | `ubuntu/v0.22.0` | `ubuntu/v0.22.0` | [Yes](https://github.com/regolith-linux/i3status-rs_debian/compare/ubuntu/v0.22.0...ubuntu/v0.22.0) |
| [i3status-rs](https://github.com/regolith-linux/i3status-rs_debian) | `ubuntu/v0.22.0` | `v0.22.2-1-ubuntu-jammy` | [Yes](https://github.com/regolith-linux/i3status-rs_debian/compare/v0.22.2-1-ubuntu-jammy...ubuntu/v0.22.0) |
| [i3status-rs](https://github.com/regolith-linux/i3status-rs_debian) | `ubuntu/v0.32.1` | `v0.32.1-1` | [Yes](https://github.com/regolith-linux/i3status-rs_debian/compare/v0.32.1-1...ubuntu/v0.32.1) |
| [i3xrocks](https://github.com/regolith-linux/i3xrocks) | `master` | `v1.3.6-1` | [Yes](https://github.com/regolith-linux/i3xrocks/compare/v1.3.6-1...master) |
| [i3-next-workspace](https://github.com/regolith-linux/i3-next-workspace) | `main` | `v1.0.5` | [Yes](https://github.com/regolith-linux/i3-next-workspace/compare/v1.0.5...main) |
| [i3-snapshot](https://github.com/regolith-linux/i3-snapshot) | `master` | `v1.1-1ubuntu1-ppa1` | [Yes](https://github.com/regolith-linux/i3-snapshot/compare/v1.1-1ubuntu1-ppa1...master) |
| [i3-swap-focus](https://github.com/regolith-linux/i3-swap-focus) | `master` | `v0.4.4` | [Yes](https://github.com/regolith-linux/i3-swap-focus/compare/v0.4.4...master) |
| [i3-wm](https://github.com/regolith-linux/i3-wm) | `main` | `v4.22-2` | [Yes](https://github.com/regolith-linux/i3-wm/compare/v4.22-2...main) |
| [ilia](https://github.com/regolith-linux/ilia) | `main` | `v0.17.0` | [Yes](https://github.com/regolith-linux/ilia/compare/v0.17.0...main) |
| [lago](https://github.com/regolith-linux/lago) | `main` | `v0.2.0-1` | [Yes](https://github.com/regolith-linux/lago/compare/v0.2.0-1...main) |
| [libtrawldb](https://github.com/regolith-linux/libtrawldb) | `master` | `v0.1-3` | [Yes](https://github.com/regolith-linux/libtrawldb/compare/v0.1-3...master) |
| [nordic](https://github.com/regolith-linux/nordic) | `main` | `v2.1.0-2` | [Yes](https://github.com/regolith-linux/nordic/compare/v2.1.0-2...main) |
| [picom](https://github.com/regolith-linux/picom) | `main` | `v11.2.3` | [Yes](https://github.com/regolith-linux/picom/compare/v11.2.3...main) |
| [plymouth-theme-regolith](https://github.com/regolith-linux/plymouth-theme-regolith) | `master` | `v1.2.3` | No |
| [python3-i3ipc](https://github.com/regolith-linux/python3-i3ipc) | `master` | `v2.1.1-1ubuntu1-ppa8` | [Yes](https://github.com/regolith-linux/python3-i3ipc/compare/v2.1.1-1ubuntu1-ppa8...master) |
| [regolith-archive-keyring](https://github.com/regolith-linux/regolith-archive-keyring) | `main` | `v0.1.0` | No |
| [regolith-avizo](https://github.com/regolith-linux/avizo) | `master` | `v0.1.4` | [Yes](https://github.com/regolith-linux/avizo/compare/v0.1.4...master) |
| [regolith-compositor-compton-glx](https://github.com/regolith-linux/regolith-compositor-compton-glx) | `master` | `v1.2.1` | [Yes](https://github.com/regolith-linux/regolith-compositor-compton-glx/compare/v1.2.1...master) |
| [regolith-compositor-none](https://github.com/regolith-linux/regolith-compositor-none) | `master` | `v1.0.4-1` | [Yes](https://github.com/regolith-linux/regolith-compositor-none/compare/v1.0.4-1...master) |
| [regolith-compositor-picom-glx](https://github.com/regolith-linux/regolith-compositor-picom-glx) | `master` | `v1.4.0` | [Yes](https://github.com/regolith-linux/regolith-compositor-picom-glx/compare/v1.4.0...master) |
| [regolith-compositor-xcompmgr](https://github.com/regolith-linux/regolith-compositor-xcompmgr) | `master` | `v1.4.0-1` | [Yes](https://github.com/regolith-linux/regolith-compositor-xcompmgr/compare/v1.4.0-1...master) |
| [regolith-control-center](https://github.com/regolith-linux/regolith-control-center) | `regolith/1%43.0-1` | `v1.43.1-8-gnome-43` | [Yes](https://github.com/regolith-linux/regolith-control-center/compare/v1.43.1-8-gnome-43...regolith/1%43.0-1) |
| [regolith-control-center](https://github.com/regolith-linux/regolith-control-center) | `regolith/46` | `v1.46.0-4-gnome-46` | [Yes](https://github.com/regolith-linux/regolith-control-center/compare/v1.46.0-4-gnome-46...regolith/46) |
| [regolith-control-center](https://github.com/regolith-linux/regolith-control-center) | `regolith/48` | `` | No |
| [regolith-control-center](https://github.com/regolith-linux/regolith-control-center) | `regolith/48` | n/a | No |
| [regolith-control-center](https://github.com/regolith-linux/regolith-control-center) | `regolith/48` | `regolith/48` | No |
| [regolith-control-center](https://github.com/regolith-linux/regolith-control-center) | `regolith/48` | `v1.48.1-9-gnome-48` | No |
| [regolith-control-center](https://github.com/regolith-linux/regolith-control-center) | `ubuntu/jammy` | `v1.41.19-ubuntu-jammy` | [Yes](https://github.com/regolith-linux/regolith-control-center/compare/v1.41.19-ubuntu-jammy...ubuntu/jammy) |
| [regolith-default-settings](https://github.com/regolith-linux/regolith-default-settings) | `main` | `v2.0.5` | [Yes](https://github.com/regolith-linux/regolith-default-settings/compare/v2.0.5...main) |
| [regolith-desktop](https://github.com/regolith-linux/regolith-desktop) | `main` | `v4.9.0` | [Yes](https://github.com/regolith-linux/regolith-desktop/compare/v4.9.0...main) |
| [regolith-displayd](https://github.com/regolith-linux/regolith-displayd) | `master` | `v0.3.2` | [Yes](https://github.com/regolith-linux/regolith-displayd/compare/v0.3.2...master) |
| [regolith-distro-ubuntu](https://github.com/regolith-linux/regolith-distro-ubuntu) | `main` | `v2.0.0-2` | [Yes](https://github.com/regolith-linux/regolith-distro-ubuntu/compare/v2.0.0-2...main) |
| [regolith-ftue](https://github.com/regolith-linux/regolith-ftue) | `main` | `v2.2.1` | [Yes](https://github.com/regolith-linux/regolith-ftue/compare/v2.2.1...main) |
| [regolith-i3xrocks-config](https://github.com/regolith-linux/regolith-i3xrocks-config) | `master` | `v5.5.2` | [Yes](https://github.com/regolith-linux/regolith-i3xrocks-config/compare/v5.5.2...master) |
| [regolith-inputd](https://github.com/regolith-linux/regolith-inputd) | `master` | `v0.4.0` | [Yes](https://github.com/regolith-linux/regolith-inputd/compare/v0.4.0...master) |
| [regolith-lightdm-config](https://github.com/regolith-linux/regolith-lightdm-config) | `master` | `v1.3.7` | [Yes](https://github.com/regolith-linux/regolith-lightdm-config/compare/v1.3.7...master) |
| [regolith-look-default](https://github.com/regolith-linux/regolith-look-default) | `main` | `v0.8.3` | [Yes](https://github.com/regolith-linux/regolith-look-default/compare/v0.8.3...main) |
| [regolith-look-extra](https://github.com/regolith-linux/regolith-look-extra) | `main` | `v0.9.2` | [Yes](https://github.com/regolith-linux/regolith-look-extra/compare/v0.9.2...main) |
| [regolith-powerd](https://github.com/regolith-linux/regolith-powerd) | `master` | `v0.5.0` | [Yes](https://github.com/regolith-linux/regolith-powerd/compare/v0.5.0...master) |
| [regolith-rofication](https://github.com/regolith-linux/regolith-rofication) | `master` | `v1.5.1` | [Yes](https://github.com/regolith-linux/regolith-rofication/compare/v1.5.1...master) |
| [regolith-rofi-config](https://github.com/regolith-linux/regolith-rofi-config) | `master` | `v1.4.2-1` | [Yes](https://github.com/regolith-linux/regolith-rofi-config/compare/v1.4.2-1...master) |
| [regolith-session](https://github.com/regolith-linux/regolith-session) | `debian-bookworm` | `v1.1.13-3-debian-bookworm` | [Yes](https://github.com/regolith-linux/regolith-session/compare/v1.1.13-3-debian-bookworm...debian-bookworm) |
| [regolith-session](https://github.com/regolith-linux/regolith-session) | `fix/trixie-session-init-1094494` | `fix/trixie-session-init-1094494` | [Yes](https://github.com/regolith-linux/regolith-session/compare/fix/trixie-session-init-1094494...fix/trixie-session-init-1094494) |
| [regolith-session](https://github.com/regolith-linux/regolith-session) | `fix/trixie-session-init-1094494` | n/a | No |
| [regolith-session](https://github.com/regolith-linux/regolith-session) | `main` | `v1.1.13-1` | [Yes](https://github.com/regolith-linux/regolith-session/compare/v1.1.13-1...main) |
| [regolith-sway-touchpad-gestures](https://github.com/regolith-linux/regolith-sway-touchpad-gestures) | `main` | `v0.1.0-3` | [Yes](https://github.com/regolith-linux/regolith-sway-touchpad-gestures/compare/v0.1.0-3...main) |
| [regolith-system-ubuntu](https://github.com/regolith-linux/regolith-system-ubuntu) | `main` | `v1.0.1` | [Yes](https://github.com/regolith-linux/regolith-system-ubuntu/compare/v1.0.1...main) |
| [regolith-unclutter-xfixes](https://github.com/regolith-linux/regolith-unclutter-xfixes) | `master` | `v1.5-3` | [Yes](https://github.com/regolith-linux/regolith-unclutter-xfixes/compare/v1.5-3...master) |
| [regolith-wm-config](https://github.com/regolith-linux/regolith-wm-config) | `main` | `v4.11.9` | [Yes](https://github.com/regolith-linux/regolith-wm-config/compare/v4.11.9...main) |
| [remontoire](https://github.com/regolith-linux/remontoire) | `master` | `v1.4.4` | No |
| [solarc-theme](https://github.com/regolith-linux/solarc-theme) | `master` | `v800c997-4` | [Yes](https://github.com/regolith-linux/solarc-theme/compare/v800c997-4...master) |
| [sway-audio-idle-inhibit](https://github.com/regolith-linux/SwayAudioIdleInhibit) | `main` | `v0.1.4` | [Yes](https://github.com/regolith-linux/SwayAudioIdleInhibit/compare/v0.1.4...main) |
| [sway-regolith](https://github.com/regolith-linux/sway-regolith) | `packaging/v1.7-regolith` | `v1.7-8-ubuntu-jammy` | [Yes](https://github.com/regolith-linux/sway-regolith/compare/v1.7-8-ubuntu-jammy...packaging/v1.7-regolith) |
| [sway-regolith](https://github.com/regolith-linux/sway-regolith) | `packaging/v1.9-regolith` | `v1.9-17` | [Yes](https://github.com/regolith-linux/sway-regolith/compare/v1.9-17...packaging/v1.9-regolith) |
| [sway-regolith](https://github.com/regolith-linux/sway-regolith) | `packaging/v1.10-regolith` | `` | No |
| [sway-regolith](https://github.com/regolith-linux/sway-regolith) | `packaging/v1.10-regolith` | `packaging/v1.10-regolith` | No |
| [sway-regolith](https://github.com/regolith-linux/sway-regolith) | `packaging/v1.10-regolith` | `v1.10-2` | No |
| [trawl](https://github.com/regolith-linux/trawl) | `master` | `v0.2.5` | [Yes](https://github.com/regolith-linux/trawl/compare/v0.2.5...master) |
| [ubiquity-slideshow-regolith](https://github.com/regolith-linux/ubiquity-slideshow-regolith) | `master` | `v202` | No |
| [whitesur-gtk-theme](https://github.com/regolith-linux/WhiteSur-gtk-theme) | `debian` | `v1.1-2025.02.03` | [Yes](https://github.com/regolith-linux/WhiteSur-gtk-theme/compare/v1.1-2025.02.03...debian) |
| [xdg-desktop-portal-regolith](https://github.com/regolith-linux/xdg-desktop-portal-regolith) | `debian-bookworm` | `v0.3.7-2-debian-bookworm` | No |
| [xdg-desktop-portal-regolith](https://github.com/regolith-linux/xdg-desktop-portal-regolith) | `main` | `v0.3.7-1` | [Yes](https://github.com/regolith-linux/xdg-desktop-portal-regolith/compare/v0.3.7-1...main) |
| [xdg-desktop-portal-regolith](https://github.com/regolith-linux/xdg-desktop-portal-regolith) | `ubuntu/jammy` | `v0.3.7-3-ubuntu-jammy` | No |
| [xrescat](https://github.com/regolith-linux/xrescat) | `master` | `v1.2.1-3` | [Yes](https://github.com/regolith-linux/xrescat/compare/v1.2.1-3...master) |
<!-- AUTO_GENERATE_END -->

## False Positives

At the time of writing, there are so many projects reporting `Need Release`: `Yes`.
Most of them are false positive which was caused by a necessary commit (i.e.
`feat: use build-only to test pull request`) that went through after the latest
release was tagged.

Our plan is to make sure we properly tag the latest commits on each project so
that the reporting table above is completely informative. This will happen some
time after the GA release of `v3.3`.

In the meantime the following projects worth keep an eye on to make sure all of
them are tagged and released properly:

- `i3status-rs`
- `i3-wm`
- `ilia`
- `libtrawldb`
- `regolith-control-center`
- `regolith-desktop`
- `regolith-session`
- `regolith-wm-config`
- `sway-regolith`
- `trawl`
- `xdg-desktop-portal-regolith`
