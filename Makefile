K3D_KUBECONFIG_PATH=./integration.yaml

.PHONY: help
help: ## Show this help
help:
	@grep -E '^[\/a-zA-Z0-9._%-]+:.*?## .*$$' Makefile | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: clean
clean: ## Remove build/doc dirs
	rm -rf {_build,cover,deps,doc}

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

integration.yaml: ## Create a k3d cluster
	- k3d cluster delete k8s-ex
	k3d cluster create k8s-ex --servers 1 --wait
	k3d kubeconfig get k8s-ex > ${K3D_KUBECONFIG_PATH}
	sleep 5

.PHONY: integration-tests
integration-tests: integration.yaml
integration-tests: ## Run integration tests using k3d `make cluster`
	TEST_KUBECONFIG=${K3D_KUBECONFIG_PATH} mix test --only external

.PHONY: all-tests
all-tests: integration.yaml
all-tests: ## Run all tests
	TEST_KUBECONFIG=${K3D_KUBECONFIG_PATH} mix test --include external
