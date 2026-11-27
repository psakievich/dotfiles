# tools

One Spack environment (`spack.yaml`), built once and deployed from a buildcache.
This directory does not depend on the dotfiles around it, so it can move into its own repo.

```console
$ ./install.sh                     # make deps all
$ ./install.sh ~/dotfiles/env.sh   # ...and symlink that file to the deployment's load.sh
```

| Stage | Where | What |
|---|---|---|
| build | `DOT_BUILD_ROOT` (default `tools/.build`) | spack clone, padded build tree, build env, buildcache. Disposable. |
| deploy | `DOT_RUNTIME_ROOT` (default `~/.local/opt/dotfiles`) | `opt/` (runtime deps only, from the buildcache), `view/`, `load.sh` |

`load.sh` only prepends to `PATH` and the other variables, and it only references `view/`.
That means `make build-wipe` leaves the deployment working.

To add a tool, edit `spack.yaml` and run `make`, then `make gc` to drop what is no longer needed.
Machine-local overrides go in a gitignored `local.mk` (e.g. `ENV_TEMPLATE = /path/to/spack.yaml`,
`DOT_BUILD_ROOT = /scratch/...`) or exported from `~/.dotlocal`.

`./sspack [--runtime] <args>` runs this spack with the build (or runtime) config scopes.
