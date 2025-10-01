# Remove a Distro and Codename

To remove a codename from the build system follow the steps below:

1. remove the codename folder from unstable

   ```shell
   rm -r stage/unstable/<distro>/<codename>
   ```

1. remove the codename folder from testing

   ```shell
   rm -r stage/testing/<distro>/<codename>
   ```

1. mark the codename as legacy in `.github/workflows/test-desktop-installable2.yml`

   ```diff
   ubuntu-oracular:
     runs-on: ${{ fromJSON(needs.matrix-builder.outputs.runners)[matrix.arch] }}
     needs: matrix-builder
     if: |
   -   (inputs.legacy == 'no') &&
   +   (inputs.legacy == 'yes') &&
   ```

1. open a new pull request with these changes

> Remove support for [end-of-life oracular] pull request can be taken as an example.

[end-of-life oracular]: https://github.com/regolith-linux/voulage/pull/122
