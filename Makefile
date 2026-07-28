BUILD ?= buildah bud
RUN ?= podman run
TAG ?= latest
DEBIAN_VARIANT ?= bookworm
GO_VERSION ?= 1.26.0

BASE_IMAGE ?= localhost/automation-base:$(TAG)
GO_IMAGE ?= localhost/automation-go:$(TAG)
PYTHON_IMAGE ?= localhost/automation-python:$(TAG)
DEV_IMAGE ?= localhost/automation-dev:$(TAG)

# Publishing. Set all four in the environment (or make args):
#   REGISTRY, IMAGE_OWNER, REGISTRY_USER, REGISTRY_TOKEN
# IMAGE_OWNER empty → $(REGISTRY)/$(IMAGE_REPO)/$(IMAGE_NAME)  (LAN)
# IMAGE_OWNER set   → $(REGISTRY)/$(IMAGE_OWNER)/$(IMAGE_REPO)/$(IMAGE_NAME)  (GHCR)
REGISTRY ?=
IMAGE_OWNER ?=
IMAGE_REPO ?= development-container
IMAGE_NAME ?= dev-build
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)

ifeq ($(strip $(IMAGE_OWNER)),)
REMOTE_IMAGE := $(REGISTRY)/$(IMAGE_REPO)/$(IMAGE_NAME)
else
REMOTE_IMAGE := $(REGISTRY)/$(IMAGE_OWNER)/$(IMAGE_REPO)/$(IMAGE_NAME)
endif

.PHONY: build-base build-go build-python build-dev build-all test-dev shell-dev clean \
	login tag-dev push-dev publish release

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
	@test -n "$(REGISTRY)" || (echo "REGISTRY is not set" >&2 && exit 1)
	@test -n "$(REGISTRY_USER)" || (echo "REGISTRY_USER is not set" >&2 && exit 1)
	@test -n "$(REGISTRY_TOKEN)" || (echo "REGISTRY_TOKEN is not set" >&2 && exit 1)
	echo "$(REGISTRY_TOKEN)" | buildah login --username "$(REGISTRY_USER)" --password-stdin $(REGISTRY)

tag-dev:
	buildah tag $(DEV_IMAGE) $(REMOTE_IMAGE):$(VERSION)
	buildah tag $(DEV_IMAGE) $(REMOTE_IMAGE):latest

push-dev: tag-dev
	buildah push $(REMOTE_IMAGE):$(VERSION)
	buildah push $(REMOTE_IMAGE):latest

publish: push-dev
	@echo "Published $(REMOTE_IMAGE):$(VERSION) and $(REMOTE_IMAGE):latest"

release: build-dev publish

clean:
	find . -type d \( -name __pycache__ -o -name .pytest_cache -o -name .mypy_cache -o -name .ruff_cache -o -name .cache -o -name .local \) -prune -exec rm -rf {} +
	find . -type f \( -name .coverage -o -name '*.log' -o -name '.DS_Store' \) -delete
