K3D_KUBECONFIG_PATH?=./integration.k3d.yaml
KIND_KUBECONFIG_PATH?=./integration.kind.yaml

.PHONY: help
help: ## Show this help
help:
	@grep -E '^[\/a-zA-Z0-9._%-]+:.*?## .*$$' Makefile | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: clean
clean: ## Remove build/doc dirs
	rm -rf {_build,cover,deps,doc}
	rm -f integration*.yaml

.PHONY: all
all: ## Run format, credo, dialyzer, and test all supported k8s versions
all: 
	mix deps.get
	mix coveralls.html
	mix format
	mix credo --strict
	mix dialyzer
	mix docs
	mix inch

CLUSTER_NAME=k8s-ex
integration.k3d.yaml:
	$(MAKE) delete.k3d create.k3d
	k3d kubeconfig get ${CLUSTER_NAME} > ${K3D_KUBECONFIG_PATH}
	sleep 5

integration.kind.yaml: 
	$(MAKE) delete.kind create.kind
	kind export kubeconfig --kubeconfig ${KIND_KUBECONFIG_PATH} --name "${CLUSTER_NAME}" 

.PHONY: integration.k3d
integration.k3d: integration.k3d.yaml
integration.k3d: ## Run integration tests using k3d `make cluster`
	TEST_WAIT_TIMEOUT=1000 TEST_KUBECONFIG=${K3D_KUBECONFIG_PATH} mix test --only integration

.PHONY: integration.kind
integration.kind: integration.kind.yaml
integration.kind: ## Run integration tests using k3d `make cluster`
	TEST_WAIT_TIMEOUT=1000 TEST_KUBECONFIG=${KIND_KUBECONFIG_PATH} mix test --only integration

.PHONY: test.k3d
test.k3d: integration.k3d.yaml
test.k3d: ## Run integration tests using k3d `make cluster`
	TEST_WAIT_TIMEOUT=1000 TEST_KUBECONFIG=${K3D_KUBECONFIG_PATH} mix test --include integration

.PHONY: test.kind
test.kind: integration.kind.yaml
test.kind: ## Run integration tests using k3d `make cluster`
	TEST_WAIT_TIMEOUT=1000 TEST_KUBECONFIG=${KIND_KUBECONFIG_PATH} mix test --include integration

.PHONY: test.k3d.watch
test.k3d.watch: integration.k3d.yaml
test.k3d.watch: ## Run all tests with mix.watch
	TEST_KUBECONFIG=${K3D_KUBECONFIG_PATH} mix test.watch --include integration

.PHONY: test.kind.watch
test.kind.watch: integration.kind.yaml
test.kind.watch: ## Run all tests with mix.watch
	TEST_KUBECONFIG=${KIND_KUBECONFIG_PATH} mix test.watch --include integration

.PHONY: create.k3d
create.k3d: ## Created k3d cluster
	k3d cluster create ${CLUSTER_NAME} --servers 1 --wait

.PHONY: create.kind
create.kind: ## Created kind cluster
	kind create cluster --wait 600s --name "${CLUSTER_NAME}"

.PHONY: delete.k3d
delete.k3d: ## Delete k3d cluster
	- k3d cluster delete ${CLUSTER_NAME}
	rm -f ${K3D_KUBECONFIG_PATH}

.PHONY: delete.kind
delete.kind: ## Delete kind cluster
	- kind delete cluster --kubeconfig ${KIND_KUBECONFIG_PATH} --name "${CLUSTER_NAME}"
	rm -f ${KIND_KUBECONFIG_PATH}

# Kind as the default

.PHONY: test
test: test.kind

.PHONY: test.watch
test.watch: test.kind.watch