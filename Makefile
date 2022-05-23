K3D_KUBECONFIG_PATH?=./integration.yaml

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
integration.yaml: ## Create a k3d cluster
	- k3d cluster delete ${CLUSTER_NAME}
	k3d cluster create ${CLUSTER_NAME} --servers 1 --wait
	k3d kubeconfig get ${CLUSTER_NAME} > ${K3D_KUBECONFIG_PATH}
	sleep 5

.PHONY: test.integration
test.integration: integration.yaml
test.integration: ## Run integration tests using k3d `make cluster`
	ERL_INETRC="./priv/erl_inetrc" TEST_KUBECONFIG=${K3D_KUBECONFIG_PATH} mix test --only integration

.PHONY: test
test: integration.yaml
test: ## Run all tests
	TERL_INETRC="./priv/erl_inetrc" TEST_KUBECONFIG=${K3D_KUBECONFIG_PATH} mix test --include integration

.PHONY: test.watch
test.watch: integration.yaml
test.watch: ## Run all tests with mix.watch
	ERL_INETRC="./priv/erl_inetrc" TEST_KUBECONFIG=${K3D_KUBECONFIG_PATH} mix test.watch --include integration

.PHONY: k3d.delete
k3d.delete: ## Delete k3d cluster
	- k3d cluster delete ${CLUSTER_NAME}

.PHONY: k3d.create
k3d.create: ## Created k3d cluster
	k3d cluster create ${CLUSTER_NAME} --servers 1 --wait