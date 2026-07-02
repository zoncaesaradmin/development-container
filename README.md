# Automation Base Image Project

This repository now has two layers of content:

1. A local copy of the `devcontainers/images` implementation under the existing upstream-style layout (`build/`, `src/`, and related files) so we can keep their structure and ideas close at hand.
2. A simpler top-level image build path for our own automation-focused developer images built around open-source OCI tooling.

The copied upstream tree is preserved intentionally. The top-level `Containerfile.*`, `scripts/`, and `Makefile` files are the primary implementation for this project.

## Current focus

The combined development image is intentionally limited to:

- Go
- Python
- OCI container tooling (`podman`, `buildah`, `skopeo`)
- Common developer and native build utilities needed for Git workflows and CGO-enabled builds

This keeps the dev image smaller and easier to maintain while still covering current usage.

## Tooling requirements (who needs what)

- **Build machine** (builds these `Containerfile.*` into images): needs **Buildah** only. Podman is not required to build.
- **Run machine** (runs the resulting `automation-dev` container, e.g. via `make shell-dev` / `make test-dev`): needs **Podman**.
- **Skopeo** ships inside the built image itself, for developers to use from within their devcontainer. It is not a host/build-machine dependency.

These can be the same machine or different ones — the point is the build step itself only depends on Buildah.

## Current image set

- `Containerfile.base`
  Installs the shared base toolchain: Git, shell utilities, native build dependencies, and `podman` / `buildah` / `skopeo`.
- `Containerfile.go`
  Builds on `automation-base` and adds the Go toolchain.
- `Containerfile.python`
  Builds on `automation-base` and adds Python and common Python packaging tools.
- `Containerfile.dev`
  Builds a self-contained combined dev image for Go + Python work so the dev container can build directly without relying on locally pre-built intermediate images.

## Build strategy

The default build path uses fully open-source OCI tooling, split by responsibility:

- **`buildah bud`** — builds the images (default `BUILD` command in the `Makefile`). This is the only tool required on a machine that just needs to *build* these images, e.g. a CI/build server. Podman is not required there.
- **`podman run`** — runs/tests a built image (default `RUN` command, used by `test-dev` and `shell-dev`). This is only needed on a machine that needs to *run* the resulting container.
- **`skopeo`** — bundled inside the built images (via `scripts/install-common.sh`) so developers can inspect/copy images from within their devcontainer. It is not required on the build machine itself.

If you prefer Podman for builds instead, override `BUILD`: `make BUILD="podman build" build-all`.

## Quick start

Build the full stack with the default Buildah flow (only `buildah` is required on the build machine):

```bash
make build-all
```

Build only the combined dev image:

```bash
make build-dev
```

Switch to `podman build` without changing files:

```bash
make BUILD="podman build" build-all
```

Open a shell in the combined dev image:

```bash
make shell-dev
```

Verify the core toolchain versions inside the combined image:

```bash
make test-dev
```

Remove local cache and log files that are not useful to keep in Git:

```bash
make clean
```

## Image tags

By default, images are tagged locally as:

- `localhost/automation-base:latest`
- `localhost/automation-go:latest`
- `localhost/automation-python:latest`
- `localhost/automation-dev:latest`

You can override the tag:

```bash
make TAG=dev build-all
```

## Dev container config

A ready-to-use dev container definition for the combined image lives at:

- `.devcontainer/devcontainer.json`

An additional copy also exists at `.devcontainer/automation-base/devcontainer.json`.

Both are configured for nested OCI image builds with the combined Go + Python toolchain.

## Keeping the image lean

The combined dev image intentionally does not include extra language runtimes such as Java, Node.js, Rust, Ruby, or .NET yet. The shared base still keeps the common developer packages and C/C++ build toolchain needed by many Go and Python projects, including CGO-backed builds.

## Adding another language later

To add another language stack later, follow the same pattern:

1. Add a new installer script under `scripts/`, for example `scripts/install-rust.sh`.
2. Add a dedicated image definition, for example `Containerfile.rust`, that starts from `Containerfile.base`.
3. If the combined dev image should include that language too, add the installer to `Containerfile.dev`.
4. Add matching `make` targets in `Makefile`.

The safest places to extend are:

- shared packages: `scripts/install-common.sh`
- Go toolchain: `scripts/install-go.sh`
- Python toolchain: `scripts/install-python.sh`
- combined dev image contents: `Containerfile.dev`
- build commands and tags: `Makefile`

## Notes

- The container storage driver is set to `vfs` by default for better compatibility when building images inside another container.
- The upstream copied tree is left in place on purpose so we can keep borrowing patterns for future language images without having to re-clone or re-study it.
- No upstream files were removed as part of this bootstrap. New project-specific files live alongside the copied implementation.
