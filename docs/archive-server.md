# Archive Server Runbook

How `archive.regolith-desktop.com` is laid out, what CI does on it, and the
manual steps it still needs. The scripts mentioned here are in
[.github/scripts/remote](../.github/scripts/remote/).

## Layout

The archive is served by Apache and managed with [aptly](https://www.aptly.info/).

| Path | Contents |
|---|---|
| `/etc/aptly/<distro>/<suite>.conf` | One aptly config (and database) per distro and suite. `<distro>` is `debian` or `ubuntu`. `<suite>` is `experimental`, `unstable`, `testing`, `backports` or `stable`. |
| `/opt/archives/packages/voulage/run-<id>/` | Staging: what one `build-deb-v5` run uploaded, as `<distro>/<codename>/<suite or version>/`. |
| `/opt/archives/workspace/voulage/run-<id>/` | Staging for source rebuilds (`SOURCELOG_*.txt` and tarballs). |
| `/opt/archives/{packages,workspace}/voulage/held/run-<id>/` | What run `<id>` uploaded for a target whose build failed on some architecture, moved out of the staging folders so it isn't published. Nothing reads it; delete it once the failure is understood. |
| `/opt/archives/published/<distro>/<suite>/public/` | aptly's published trees, served as `http://archive.regolith-desktop.com/<distro>/<suite>/`. |

### aptly naming

- **Local repo:** `<codename>-<component>`, e.g. `noble-main`, `noble-v3.4`. Each suite has its own config, so `noble-main` in `ubuntu/testing.conf` and `noble-main` in `ubuntu/stable.conf` are different repos.
- **Published distribution:** one per codename per suite, named `<codename>`, e.g. `noble` in `ubuntu/stable.conf`.
- **Components:** non-stable suites only have `main`. The stable suite has `main` plus one `vX.Y` component per release (`v3.3`, `v3.4`, …), all under the same published `<codename>`.

A sources line maps onto this as:

```
deb http://archive.regolith-desktop.com/ubuntu/stable noble v3.4
                                         distro/suite codename component
```

## What CI does

A `build-deb-v5.yml` run with `do-publish=yes`:

1. **Build.** Each target builds the changed packages. For a `release-X_Y` stage the suite is `stable` and the component is `X.Y`. `ext-debian.sh` puts each file in `<distro>/<codename>/stable/` and hard-links it into `<distro>/<codename>/X.Y/`.
2. **Upload.** The files go to `/opt/archives/packages/voulage/run-<id>/`, and `SOURCELOG_<target>.txt` goes to `/opt/archives/workspace/voulage/run-<id>/`.
3. **Rebuild sources** (`rebuild-sources.yml`). `get-published-sources.sh` stages the `.orig.tar.gz` already in the archive, so every codename and component shares one tarball per version. The `.dsc` is rebuilt against it, then `cleanup-workspace.sh` removes the workspace folder.
4. **Publish** (`publish-packages.yml`). `publish-repos.sh` walks the run folder. For each `<distro>/<codename>/<folder>` it:
   - creates the local repo if it's missing,
   - runs `aptly repo add -remove-files`, with `-force-replace` only for experimental and unstable,
   - then either publishes the codename (`publish repo`) or updates it. For a stable `vX.Y` component that's new to the codename, it first runs `publish source add -component=vX.Y`, then `publish update`.
5. **Manifests.** The build commits the updated `manifests/<distro>/<codename>/<suite>-<component>/manifest.txt`.

A build leg that fails doesn't stop the other targets. Steps 3 to 5 run for
every target whose legs all passed. A target with a failed leg on any
architecture is held back as a whole: its files are moved to `held/run-<id>/`
before step 3 (the legs that passed have already uploaded theirs), and its
manifest isn't updated, so the next build retries it. The run still ends as
failed.

Two consequences matter for releases:

- **Every stable release build also adds to `<codename>-main`**, because the `stable/` folder is uploaded next to `X.Y/`. So stable `main` collects every release's packages; nobody needs to point it at a release.
- **Stable is added without `-force-replace`.** If a package that's already in `<codename>-main` is rebuilt with the same name and version, the files differ and `aptly repo add` fails on the conflict. This is why release manifests are seeded with the packages that haven't changed (see #151), so that they aren't rebuilt.

## New release component

`publish-repos.sh` creates `<codename>-vX.Y` and adds it to the published codename the first time a build uploads to it. It does **not** bring over packages from the previous release that weren't rebuilt. Do that by hand after the build.

"Copy" here always means `aptly repo copy`. It copies package references between local repos in aptly's database and touches no files; `publish update` then rebuilds the indexes and links the existing files into the component's pool. Don't `cp` files into `/opt/archives/published/`: aptly owns that tree, and files it doesn't know about appear in no index and can block later publishes.

Set `C=/etc/aptly/<distro>/stable.conf`.

1. **Build the release stage** with `build-deb-v5.yml`.
2. **Copy the packages that weren't rebuilt** into the new component. There are two ways:
   - **Everything from the previous release, minus the rebuilt packages.** Use this for a point release (3.4 → 3.4.2):
     ```
     aptly -config=$C repo copy -dry-run <codename>-v3.4 <codename>-v3.4.2 'Name (~ .*), !Name (ilia)'
     ```
   - **Only named packages, pinned to a version, from stable `main`.** This is how 3.4.0 was done. Use it for a minor release, so packages the new release dropped don't come along. Run it once per **binary** package; multi-binary sources need each binary listed, e.g. `plymouth-theme-regolith` and `plymouth-theme-regolith-logo`:
     ```
     aptly -config=$C repo copy -dry-run <codename>-main <codename>-v3.5 '<binary>, $Version (% <version>-1regolith*)'
     ```

   Check the `-dry-run` output, then run it again without `-dry-run`.
3. **Publish:** `aptly -config=$C publish update <codename>`.

### A codename with no rebuilt packages

If the release's seeded manifest leaves nothing to build for a codename, CI uploads nothing for it, so `publish-repos.sh` never creates or publishes the component there. Do it by hand:

```
aptly -config=$C repo create -component=v3.4.2 -distribution=<codename> -comment="Regolith for <distro> <codename>" <codename>-v3.4.2
aptly -config=$C repo copy <codename>-v3.4 <codename>-v3.4.2 'Name (~ .*)'
aptly -config=$C publish source add -component=v3.4.2 <codename> <codename>-v3.4.2
aptly -config=$C publish update <codename>
```

A brand-new codename (e.g. the first release with resolute) needs none of this: its first upload creates and publishes both `main` and `vX.Y`.

## Fixing problems

### Publish fails with a conflict in `<codename>-main`

A rebuilt package has the same name and version as one already in stable `main`. Prefer not rebuilding it: add its line to the release manifest and copy it instead (above). If the rebuilt one should win, remove the old one from `main` and publish again:

```
aptly -config=$C repo search <codename>-main '<binary>, $Version (% <version>*)'
aptly -config=$C repo remove <codename>-main '<binary>, $Version (% <version>*)'
```

For a whole staging folder on bookworm, `remove-bookworm-packages.sh <staging folder>` does this for every file in it. Run it on the `stable/` folder and on the `X.Y/` folder of the run.

### Removing a bad package version

```
aptly -config=$C repo search <codename>-<component> '<binary>, $Version (% <version>*)'
aptly -config=$C repo remove <codename>-<component> '<binary>, $Version (% <version>*)'
aptly -config=$C publish update <codename>
aptly -config=$C db cleanup
```

Remove it from both `<codename>-main` and `<codename>-vX.Y` if it's in both. If its files linger in the published pool and block a later publish, check that no index references them, then delete them:

```
zgrep -l '<version>' /opt/archives/published/<distro>/<suite>/public/dists/*/main/*/Packages.gz
rm -v /opt/archives/published/<distro>/<suite>/public/pool/main/<letter>/<source>/<file>
```

### `publish update` can't find the distribution

Some distributions are published with a prefix. Check `aptly -config=$C publish list -raw` and pass the prefix it shows, e.g. `publish update resolute .`.

### Removing an end-of-life codename

```
aptly -config=$C publish drop <codename>
aptly -config=$C repo drop <codename>-main
aptly -config=$C repo drop <codename>-vX.Y   # each release component
```

Do this in each suite's config. See also [remove-distro-codename.md](remove-distro-codename.md) for the build-system side.

## Useful commands

```
aptly -config=$C repo list
aptly -config=$C repo show <repo>
aptly -config=$C repo search <repo> '<query>'
aptly -config=$C publish list
aptly -config=$C publish source list <codename>
```

Package queries use aptly's syntax, e.g. `'name, $Version (% 1.2.3*), $PackageType (source)'`.
