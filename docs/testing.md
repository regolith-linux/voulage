# Testing

To test the debian package checking and building, run the script:

Check Example:

```console
$ .github/scripts/main.sh \
    check \
    --git-repo-path . \
    --extension .github/scripts/ext-debian.sh \
    --manifest-path /path/to/dir/manifests \
    --pkg-build-path /path/to/dir/packages \
    --pkg-publish-path /path/to/dir/publish \
    --distro ubuntu \
    --codename focal \
    --arch amd64 \
    --stage unstable \
    --suite unstable \
    --component main
```

Build Example:

```console
$ .github/scripts/main.sh \
    build \
    --git-repo-path . \
    --extension .github/scripts/ext-debian.sh \
    --manifest-path /path/to/dir/manifests \
    --pkg-build-path /path/to/dir/packages \
    --pkg-publish-path /path/to/dir/publish \
    --distro ubuntu \
    --codename focal \
    --arch amd64 \
    --stage unstable \
    --suite unstable \
    --component main
```
