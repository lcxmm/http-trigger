GO = go
GO_FLAGS =
GOFMT = gofmt
KUBECFG = kubecfg
DOCKER = docker
CONTROLLER_IMAGE = kubeless-controller-manager:latest
HTTP_CONTROLLER_IMAGE = http-trigger-controller:latest
OS = linux
ARCH = amd64
BUNDLES = bundles
GO_PACKAGES = ./cmd/... ./pkg/...
GO_FILES := $(shell find $(shell $(GO) list -f '{{.Dir}}' $(GO_PACKAGES)) -name \*.go)

export KUBECFG_JPATH := $(CURDIR)/ksonnet-lib
export PATH := $(PATH):$(CURDIR)/bats/bin

.PHONY: all

KUBELESS_ENVS := \
	-e OS_PLATFORM_ARG \
	-e OS_ARCH_ARG \

default: binary

all:
	CGO_ENABLED=1 ./script/make.sh

binary:
	CGO_ENABLED=1 ./script/binary

binary-cross:
	./script/binary-cli

http-controller-build:
	./script/binary-controller -os=$(OS) -arch=$(ARCH) http-controller github.com/kubeless/http-trigger/cmd/http-trigger-controller

http-controller-image: docker/http-controller
	$(DOCKER) build -t $(HTTP_CONTROLLER_IMAGE) $<

docker/http-controller: http-controller-build
	cp $(BUNDLES)/kubeless_$(OS)-$(ARCH)/http-controller $@

update:
	./hack/update-codegen.sh

test:
	$(GO) test $(GO_FLAGS) $(GO_PACKAGES)

validation:
	./script/validate-vet
	./script/validate-lint
	./script/validate-gofmt
	./script/validate-git-marks

integration-tests:
	./script/integration-tests minikube deployment
	./script/integration-tests minikube basic

minikube-rbac-test:
	./script/integration-test-rbac minikube

fmt:
	$(GOFMT) -s -w $(GO_FILES)

bats:
	git clone --depth=1 https://github.com/sstephenson/bats.git

ksonnet-lib:
	git clone --depth=1 https://github.com/ksonnet/ksonnet-lib.git

.PHONY: bootstrap
bootstrap: bats ksonnet-lib

	go get github.com/mitchellh/gox
	go get github.com/golang/lint/golint

	@if ! which kubecfg >/dev/null; then \
	sudo wget -q -O /usr/local/bin/kubecfg https://github.com/ksonnet/kubecfg/releases/download/v0.6.0/kubecfg-$$(go env GOOS)-$$(go env GOARCH); \
	sudo chmod +x /usr/local/bin/kubecfg; \
	fi

	@if ! which kubectl >/dev/null; then \
	KUBECTL_VERSION=$$(wget -qO- https://storage.googleapis.com/kubernetes-release/release/stable.txt); \
	sudo wget -q -O /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/$$KUBECTL_VERSION/bin/$$(go env GOOS)/$$(go env GOARCH)/kubectl; \
	sudo chmod +x /usr/local/bin/kubectl; \
	fi

build_and_test:
	./script/start-test-environment.sh "make binary && make controller-image CONTROLLER_IMAGE=bitnami/kubeless-controller-manager:latest && make integration-tests"
