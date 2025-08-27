# Add new Distro and Codename

Adding a new distro/codename to the build system requires a few manual steps.
There is a small variation between adding new distro/codename to unstable vs
testing stage.

The difference is to how to add the content to corresponding `package-model-json`
file.

## Unstable

1. create new codename folder
1. create package model file
1. add the packages to the package model file
1. add the corresponding sections in `.github/workflows/test-desktop-installable2.yml`
1. open a new pull request with these changes

A good starting point is to copy the latest available package-model file and
modify it as needed.

```shell
# introducing new Ubuntu Questing to unstable:
cp -r stage/unstable/ubuntu/plucky/ stage/unstable/ubuntu/questing/
# modify questing/package-model.json file if needed
```

> Add [questing to unstable] pull request can be taken as an example.

## Testing

1. copy the codename folder from unstable
1. leave the `ref`s as is in the copied file. it will get updated by the Actions.
1. open a new pull request with these changes

A good starting point is to copy the content of latest available package-model
file and modify it as needed.

```shell
# introducing new Ubuntu Questing to testing:
cp -r stage/unstable/ubuntu/questing/ stage/testing/ubuntu/questing/
```

> Add [plucky to testing] pull request can be taken as an example.

## Build and Publish

In either cases, after the pull request to add the new codename has been reviewed
and merged we need to build and publish the packages. Because of internal package
dependencies (specifically for `trawl`, at the time of writing), this needs to be
done in steps:

1. run `Package Builder Debian v5` for `libtrawldb`
2. run `Package Builder Debian v5` for `trawl`

> Due to an outstanding bug, there might be a chance that after running `trawl`, the
> manifest record of `libtrawldb` gets removed. Make sure the manifest file contains
> both of these or otherwise manually add `libtrawldb` one back.

3. run `Package Builder Debian v5` without "Only build pacakge" set

>
> [!IMPORTANT]
> All these action runs must have stage, distro, and codename set to target that
> specific codename you want to release for the first time.

[questing to unstable]: https://github.com/regolith-linux/voulage/pull/113
[plucky to testing]: https://github.com/regolith-linux/voulage/pull/102
