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

integration.yaml: ## Create a k3d cluster
	- k3d cluster delete k8s-ex
	k3d cluster create k8s-ex --servers 1 --wait
	k3d kubeconfig get k8s-ex > ${K3D_KUBECONFIG_PATH}
	sleep 5

.PHONY: tests.integration
tests.integration: integration.yaml
tests.integration: ## Run integration tests using k3d `make cluster`
	TEST_KUBECONFIG=${K3D_KUBECONFIG_PATH} mix test --only integration

.PHONY: tests.all
tests.all: integration.yaml
tests.all: ## Run all tests
	TEST_KUBECONFIG=${K3D_KUBECONFIG_PATH} mix test --include integration

.PHONY: tests.watch-all
tests.watch-all: integration.yaml
tests.watch-all: ## Run all tests with mix watchers
	TEST_KUBECONFIG=${K3D_KUBECONFIG_PATH} mix test.watch --include integration
