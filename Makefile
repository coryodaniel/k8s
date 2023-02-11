KUBECONFIG_PATH?=./integration.yaml

.PHONY: help
help: ## Show this help
help:
	@grep -E '^[\/a-zA-Z0-9._%-]+:.*?## .*$$' Makefile | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: clean
clean: ## Remove build/doc dirs
	rm -rf {_build,cover,deps,doc}
	rm -f integration.yaml

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
k3d.integration.yaml: ## Create a k3d cluster
	- k3d cluster delete ${CLUSTER_NAME}
	k3d cluster create ${CLUSTER_NAME} --servers 1 --wait
	k3d kubeconfig get ${CLUSTER_NAME} > ${KUBECONFIG_PATH}
	sleep 5

kind.integration.yaml: ## Create a k3d cluster
	- kind delete cluster --kubeconfig ${KUBECONFIG_PATH} --name "kind-${CLUSTER_NAME}"
	kind create cluster --kubeconfig ${KUBECONFIG_PATH} --wait 600s --name "kind-${CLUSTER_NAME}"

.PHONY: k3d.test.integration
k3d.test.integration: k3d.integration.yaml
k3d.test.integration: ## Run integration tests using k3d `make cluster`
	TEST_WAIT_TIMEOUT=1000 TEST_KUBECONFIG=${KUBECONFIG_PATH} mix test --only integration

.PHONY: kind.test.integration
kind.test.integration: kind.integration.yaml
kind.test.integration: ## Run integration tests using k3d `make cluster`
	TEST_WAIT_TIMEOUT=1000 TEST_KUBECONFIG=${KUBECONFIG_PATH} mix test --only integration

.PHONY: test
test: k3d.test.integration k3d.delete kind.test.integration kind.delete
test: ## Run all tests
	echo "Done"

.PHONY: test.watch
test.watch: k3d.integration.yaml
test.watch: ## Run all tests with mix.watch
	TEST_KUBECONFIG=${KUBECONFIG_PATH} mix test.watch --include integration

.PHONY: k3d.delete
k3d.delete: ## Delete k3d cluster
	- k3d cluster delete ${CLUSTER_NAME}

.PHONY: k3d.create
k3d.create: ## Created k3d cluster
	k3d cluster create ${CLUSTER_NAME} --servers 1 --wait

.PHONY: kind.delete
kind.delete: ## Delete kind cluster
	- kind delete cluster --kubeconfig ${KUBECONFIG_PATH} --name "kind-${CLUsTER_NAME}"

.PHONY: kind.create
kind.create: ## Created kind cluster
	kind create cluster --kubeconfig ${KUBECONFIG_PATH} --wait 600s --name "kind-${CLUSTER_NAME}"