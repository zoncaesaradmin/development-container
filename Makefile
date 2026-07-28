BUILD ?= buildah bud
RUN ?= podman run
TAG ?= latest
DEBIAN_VARIANT ?= bookworm
GO_VERSION ?= 1.26.0

BASE_IMAGE ?= localhost/automation-base:$(TAG)
GO_IMAGE ?= localhost/automation-go:$(TAG)
PYTHON_IMAGE ?= localhost/automation-python:$(TAG)
DEV_IMAGE ?= localhost/automation-dev:$(TAG)

# ---------------------------------------------------------------------------
# Publishing — one set of variables for every destination:
#   REGISTRY, IMAGE_OWNER, IMAGE_REPO, IMAGE_NAME, VERSION
#   REGISTRY_USER, REGISTRY_TOKEN  (env; never commit)
#
# IMAGE_OWNER empty → path is $(REGISTRY)/$(IMAGE_REPO)/$(IMAGE_NAME)
# IMAGE_OWNER set   → path is $(REGISTRY)/$(IMAGE_OWNER)/$(IMAGE_REPO)/$(IMAGE_NAME)
#
# Named targets (pick one per run):
#   make VERSION=v0.1.0 publish-ghcr
#     → ghcr.io/zoncaesaradmin/development-container/automation-dev
#   make REGISTRY=artifact-dns-1.appliance.internal VERSION=v0.1.0 publish-lan
#     → artifact-dns-1.appliance.internal/development-container/automation-dev
# ---------------------------------------------------------------------------
REGISTRY ?= ghcr.io
IMAGE_OWNER ?= zoncaesaradmin
IMAGE_REPO ?= development-container
IMAGE_NAME ?= automation-dev
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)

GHCR_REGISTRY ?= ghcr.io
GHCR_IMAGE_OWNER ?= zoncaesaradmin

ifeq ($(strip $(IMAGE_OWNER)),)
REMOTE_IMAGE := $(REGISTRY)/$(IMAGE_REPO)/$(IMAGE_NAME)
else
REMOTE_IMAGE := $(REGISTRY)/$(IMAGE_OWNER)/$(IMAGE_REPO)/$(IMAGE_NAME)
endif

.PHONY: build-base build-go build-python build-dev build-all test-dev shell-dev clean \
	login tag-dev push-dev publish \
	login-ghcr publish-ghcr release-ghcr \
	login-lan publish-lan release-lan

build-base:
	$(BUILD) --build-arg DEBIAN_VARIANT=$(DEBIAN_VARIANT) -f Containerfile.base -t $(BASE_IMAGE) .

build-go: build-base
	$(BUILD) --build-arg BASE_IMAGE=$(BASE_IMAGE) --build-arg GO_VERSION=$(GO_VERSION) -f Containerfile.go -t $(GO_IMAGE) .

build-python: build-base
	$(BUILD) --build-arg BASE_IMAGE=$(BASE_IMAGE) -f Containerfile.python -t $(PYTHON_IMAGE) .

build-dev:
	$(BUILD) --build-arg DEBIAN_VARIANT=$(DEBIAN_VARIANT) --build-arg GO_VERSION=$(GO_VERSION) -f Containerfile.dev -t $(DEV_IMAGE) .

build-all: build-base build-go build-python build-dev

test-dev:
	$(RUN) --rm $(DEV_IMAGE) bash -lc "go version && python3 --version && git --version && gcc --version | head -n 1 && podman --version && buildah --version && skopeo --version"

shell-dev:
	$(RUN) --rm -it --privileged --device /dev/fuse -v $(CURDIR):/workspace -w /workspace $(DEV_IMAGE) bash

login:
	@test -n "$(REGISTRY_USER)" || (echo "REGISTRY_USER is not set" >&2 && exit 1)
	@test -n "$(REGISTRY_TOKEN)" || (echo "REGISTRY_TOKEN is not set" >&2 && exit 1)
	@test -n "$(REGISTRY)" || (echo "REGISTRY is not set" >&2 && exit 1)
	echo "$(REGISTRY_TOKEN)" | buildah login --username "$(REGISTRY_USER)" --password-stdin $(REGISTRY)

tag-dev:
	buildah tag $(DEV_IMAGE) $(REMOTE_IMAGE):$(VERSION)
	buildah tag $(DEV_IMAGE) $(REMOTE_IMAGE):latest

push-dev: tag-dev
	buildah push $(REMOTE_IMAGE):$(VERSION)
	buildah push $(REMOTE_IMAGE):latest

publish: push-dev
	@echo "Published $(REMOTE_IMAGE):$(VERSION) and $(REMOTE_IMAGE):latest"

# --- GHCR -------------------------------------------------------------------
login-ghcr:
	$(MAKE) REGISTRY=$(GHCR_REGISTRY) IMAGE_OWNER=$(GHCR_IMAGE_OWNER) login

publish-ghcr:
	$(MAKE) REGISTRY=$(GHCR_REGISTRY) IMAGE_OWNER=$(GHCR_IMAGE_OWNER) VERSION=$(VERSION) publish

release-ghcr: build-dev
	$(MAKE) VERSION=$(VERSION) publish-ghcr

# --- LAN: set REGISTRY=<lan-host>, IMAGE_OWNER forced empty -----------------
login-lan:
	@test -n "$(REGISTRY)" || (echo "login-lan: set REGISTRY=<lan-oci-host>" >&2 && exit 1)
	@if [ "$(REGISTRY)" = "ghcr.io" ]; then \
		echo "login-lan: REGISTRY is still ghcr.io; set REGISTRY=<lan-oci-host>" >&2; \
		exit 1; \
	fi
	$(MAKE) REGISTRY=$(REGISTRY) IMAGE_OWNER= login

publish-lan:
	@test -n "$(REGISTRY)" || (echo "publish-lan: set REGISTRY=<lan-oci-host>" >&2 && exit 1)
	@if [ "$(REGISTRY)" = "ghcr.io" ]; then \
		echo "publish-lan: REGISTRY is still ghcr.io; set REGISTRY=<lan-oci-host>" >&2; \
		exit 1; \
	fi
	$(MAKE) REGISTRY=$(REGISTRY) IMAGE_OWNER= VERSION=$(VERSION) publish

release-lan: build-dev
	$(MAKE) REGISTRY=$(REGISTRY) VERSION=$(VERSION) publish-lan

clean:
	find . -type d \( -name __pycache__ -o -name .pytest_cache -o -name .mypy_cache -o -name .ruff_cache -o -name .cache -o -name .local \) -prune -exec rm -rf {} +
	find . -type f \( -name .coverage -o -name '*.log' -o -name '.DS_Store' \) -delete
