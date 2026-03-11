# Rust "auto vendoring"

Vendoring is the process of downloading a snapshot of a given program's dependencies such that it can be built without downloading packages from the internet. To support building Rust applications without all dependencies/versions staged in upstream Debian, there is a special build feature based on https://blog.shadura.me/2020/12/22/vendoring-rust-in-debian-derivative/.

## Setup

The target package needs to have the file `/debian/cargo-checksum.json`. If this file exists, the special logic will be invoked by `voulage`.

## Build

In the target package, the `rules` file needs to take the vendored tarball into account when building the package.  See [here](https://github.com/kgilmer/elbey/pull/12/files) for an example, or refer to the blog post above.
