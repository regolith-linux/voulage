# Regolith 2.0 Package Repository

This repository hosts repositories containing Regolith packages. 

## Status

This repository hosts scripts and package metadata for the Regolith Desktop and Regolith Linux projects.  We appreciate bug reports, PRs, and suggestions. 

### `regolith-desktop` installable status

![](https://github.com/regolith-linux/voulage/actions/workflows/test-desktop-installable.yml/badge.svg)

## How To Install Packages - Debian and Ubuntu

Refer to the [Regolith Desktop](https://regolith-desktop.com) site for installation instructions.

## All Package Repos

This git repo contains multiple repositories hosted via GitHub pages.  The following script snippet describes what is available:

```bash
export STAGE=release # choose 'unstable', 'testing', or 'release'
export DISTRO=ubuntu    # choose either 'ubuntu' or 'debian' here depending on system installing into
export CODENAME=jammy # choose either 'focal' or 'jammy' for ubuntu or 'bullseye' for debian
export ARCH=amd64       # choose either 'amd64' or 'arm64'
echo deb [arch=$ARCH] https://regolith-$STAGE-$DISTRO-$CODENAME-$ARCH.s3.amazonaws.com $CODENAME main | sudo tee /etc/apt/sources.list.d/regolith.list
```
