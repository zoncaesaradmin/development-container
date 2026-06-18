# Automation Base Image Project

This repository now has two layers of content:

1. A local copy of the `devcontainers/images` implementation under the existing upstream-style layout (`build/`, `src/`, and related files) so we can keep their structure and ideas close at hand.
2. A simpler top-level image build path for our own automation-focused developer images built around open-source OCI tooling.

The copied upstream tree is preserved intentionally. The top-level `Containerfile.*`, `scripts/`, and `Makefile` files are the primary implementation for this project.

## Current image set

- `Containerfile.base`
  Installs common development utilities plus `podman`, `buildah`, and `skopeo`.
- `Containerfile.go`
  Builds on `automation-base` and adds the Go toolchain.
- `Containerfile.python`
  Builds on `automation-base` and adds Python and common Python packaging tools.
- `Containerfile.dev`
  Builds on `automation-go` and adds Python so the resulting image can build Go code, Python code, and container images from one dev container.

## Build strategy

The default build path uses fully open-source OCI tooling:

- `buildah bud` for image builds
- `podman run` for test shells and quick verification
- `skopeo` for image inspection and copy workflows later

All image definitions use standard Dockerfile-compatible syntax, so `podman build` works too.

## Quick start

Build the full stack with the default `buildah` flow:

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

- `.devcontainer/automation-base/devcontainer.json`

It is configured for nested OCI image builds with the combined Go + Python toolchain.

## Notes

- The container storage driver is set to `vfs` by default for better compatibility when building images inside another container.
- The upstream copied tree is left in place on purpose so we can keep borrowing patterns for future language images without having to re-clone or re-study it.
- No upstream files were removed as part of this bootstrap. New project-specific files live alongside the copied implementation.
