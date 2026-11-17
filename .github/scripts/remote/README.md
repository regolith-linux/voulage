# Archive server scripts

These scripts run on the Regolith archive server, **not** in CI. They are
reference copies; the copies on the server are the ones that run. If you change
one here, deploy it to the server too, and if you change one on the server,
update it here.

CI calls them over SSH from the composite actions in
[regolith-linux/actions](https://github.com/regolith-linux/actions). The host,
user and key come from the `KAMATERA_*` repository secrets.

| Script | Called by | What it does |
|---|---|---|
| `publish-repos.sh` | `publish-repo` action, from `publish-packages.yml` (the last job of `build-deb-v5.yml`) | Adds the packages a build uploaded to `/opt/archives/packages/voulage/run-<id>/` to aptly local repos, creating repos and published components as needed, then publishes. |
| `get-published-sources.sh` | `rebuild-sources` action, from `rebuild-sources.yml` | Reads the build's `SOURCELOG_*.txt` and stages the existing `.orig.tar.gz` and `.debian.tar.xz` files so the source packages can be rebuilt against the tarball already in the archive. |
| `cleanup-workspace.sh` | `rebuild-sources` action | Removes a run's folder from `/opt/archives/workspace/` once its sources are rebuilt. |
| `remove-bookworm-packages.sh` | by hand | For each package file in a staging folder, removes the same name and version from `bookworm-main` in the stable suite, so a rebuilt copy can be published without an aptly conflict. Used for the 3.4.0 release. Bookworm only; edit it for other codenames. |

See [docs/archive-server.md](../../../docs/archive-server.md) for how the
archive is laid out and for the manual steps a release needs.
