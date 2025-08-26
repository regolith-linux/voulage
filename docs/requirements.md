# Voulage Requirements

## Terms

* `distro` - A global-level name referring to a Linux distribution (eg: `debian`,
`ubuntu`)
* `codename` - The name of a given release of a distro (eg: `focal`, `bullseye`)
* `arch` - The system architecture of target machines (eg: `amd64`, `arm64`)
* `stage` - May be one of `unstable`, `testing`, `release`. Modeled from
[Debian releases]
* `target` - A specific instance of `distro` + `codename` + `arch` + `stage` that
an end user may use to install software
* `repository` - A collection of packages for a given `distro` + `codename` +
`arch` + `stage`
* `manifest` - A file containing lists of built package sets of:
`<package name> <source ref> <commit id>`

## Requirements

1. Able to model packages for a given target.
2. Able to determine changes for modeled packages for a given target.
3. Able to build packages in a distro-specific way.

## Goals

1. Repo builds should be easily monitor-able. Build failures should have clear
steps to resolve. The state of repositories should be easy to know at a glance
(meaning build failures should result in the repo being in a consistent state)
2. Simple file management. Each file should be in a reasonable place and there
should not be loose or unknown files.
3. Testable.  The repo should have some tests that work against static data so
that correctness can be verified outside of a given instance.

[Debian releases]: https://www.debian.org/releases/
