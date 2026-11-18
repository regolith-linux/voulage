# Voulage Package Model

## Schema

```json
{
  "description": {
    "title": "<Summarizes the package model, only needed at root>"
  },
  "packages": {
    "<package name>": {
      "source": "<public git url>",
      "ref": "<branch, tag, or commit>"
    }
  }
}
```

## Evaluation at Build Time

The package model for a given `target` is computed by first starting with the
root package model, and then merging any additional `package-model.json` files
found in the subtrees that correspond to dimensions of the `target`.  

### Example

Given the following file tree and the target of `unstable/debian/bullseye/arm64`:

```text
stage
├── release
├── testing
└── unstable
    ├── debian
    │   └── bullseye
    │       ├── amd64
    │       │   ├── manifest.txt
    │       │   └── setup.sh
    │       ├── arm64
    │       │   └── manifest.txt
    │       └── package-model.json
    ├── package-model.json
    └── ubuntu
        ├── focal
        │   ├── amd64
        │   │   └── manifest.txt
        │   └── arm64
        │       └── manifest.txt
        └── impish
```

When computing the package model for `unstable/debian/bullseye/arm64` first, the
`unstable/package-model.json` is read.  Next, we check for a `package-model.json`
in `unstable/debian`, and if found merge it with the root.  This merge pattern
continues to the the leaf node of the `target` specification.  So,
`unstable/debian/bullseye`, then `unstable/debian/bullseye/arm64` are checked for
`package-model.json` files.  The resulting model is used when determining if there
are changes (by comparing to the manifest file contained in each leaf directory).

Each changed package is built from the commit recorded for it in the new
manifest, even if its `ref` has moved since (new commits, force-push, deleted
branch, re-pointed tag). Before the first package is checked out, the build
fails if the recorded commit of any package to build is no longer in its
source. A package publishes the binary packages its build produced, as listed in
the binary `.changes` file, or none. Packages the build leaves out on purpose
(`Architecture`, `Build-Profiles`, `dh -N` or a vendor condition in
`debian/rules`) are not expected. Each file must match the size and checksum
in the `.changes`, udebs and `-dbgsym` packages are left out, and if a
published package depends on another binary package of the same source that
was not built (and no alternative or `Provides` covers it), nothing is
published.
