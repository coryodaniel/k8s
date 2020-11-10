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

.PHONY: integration
integration: integration.yaml
integration: ## Run integration tests using k3d `make cluster`
	TEST_KUBECONFIG=${K3D_KUBECONFIG_PATH} mix test --only external

.PHONY: mock.dupes
mock.dupes: ## List duplicates in resource_definitions mock (this should be empty)
	jq '.[].groupVersion' test/support/discovery/resource_definitions.json | uniq -d

.PHONY: mock.groups
mock.groups: ## List of all groups in resource_definitions mock
	jq '.[].groupVersion' test/support/discovery/resource_definitions.json
