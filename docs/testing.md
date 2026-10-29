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

## Script tests

The versions that `update_changelog()` in `ext-debian.sh` writes for each stage
are covered by a script test. It needs `git`, `dpkg-dev` and `devscripts`:

```console
$ .github/scripts/tests/test-update-changelog.sh
```

## Package versions per stage

| Stage | Version written to `debian/changelog` | Example |
|---|---|---|
| `testing`, `backports`, `release-*` | `<version>-1regolith-<codename>` | `1.2.2-1-1regolith-resolute` |
| `unstable`, `experimental` | `<version>-1regolith+git<date>.<time>.<commit>-<codename>` | `1.2.2-1-1regolith+git20261027.155210.50b8f31-resolute` |

`<version>` is the version at the top of the package's `debian/changelog`.
`<date>.<time>` is the UTC committer date of the commit being built. A snapshot
sorts above the release with the same `<version>` and below the next release.
If the changelog entry is `UNRELEASED`, `+git` becomes `~git`, so that the
snapshots sort below that upcoming release.
