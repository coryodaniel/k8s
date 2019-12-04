.PHONY: help
help: ## Show this help
help:
	@grep -E '^[\/a-zA-Z0-9._%-]+:.*?## .*$$' Makefile | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: quality
quality: ## Run code quality and test targets
quality: cov lint analyze

.PHONY: clean
clean: ## Remove build/doc dirs
	rm -rf _build
	rm -rf cover
	rm -rf deps
	rm -rf doc

.PHONY: deps
deps: ## Fetch deps
	mix deps.get

.PHONY: all
all: ## Run format, credo, dialyzer, and test all supported k8s versions
all: deps docs lint test/all analyze

.PHONY: doc
doc:
	mix docs

.PHONY: test
test: ## Run fast tests on k8s latest stable
	mix test

.PHONY: tdd
tdd: ## Run fast test on k8s last stable in a loop
	mix test.watch

.PHONY: cov
cov: ## Generate coverage HTML
	mix coveralls.html

MASTER_SWAGGER_PATH:=test/support/swagger/master.json
.PHONY: test/master
test/master: ## Run test suite against master
	@-rm -f ${MASTER_SWAGGER_PATH}
	@curl -sSL https://raw.githubusercontent.com/kubernetes/kubernetes/master/api/openapi-spec/swagger.json -o ${MASTER_SWAGGER_PATH}
	K8S_SPEC=${MASTER_SWAGGER_PATH} mix test

.PHONY: test/all
test/all: ## Run full test suite against 1.10+
test/all: test/1.10 test/1.11 test/1.12 test/1.13 test/1.14 test/1.15

test/%: ## Run full test suite against a specific k8s version
	K8S_SPEC=test/support/swagger/$*.json mix test

.PHONY: lint
lint: ## Format and run credo
	mix format
	mix credo

.PHONY: analyze
analyze: ## Run dialyzer
	mix dialyzer

get/%: ## Add a new swagger spec to the test suite
	curl -sfSL https://raw.githubusercontent.com/kubernetes/kubernetes/release-$*/api/openapi-spec/swagger.json -o test/support/swagger/$*.json

.PHONY: mock.dupes
mock.dupes: ## List duplicates in resource_definitions mock (this should be empty)
	jq '.[].groupVersion' test/support/discovery/resource_definitions.json | uniq -d

.PHONY: mock.groups
mock.groups: ## List of all groups in resource_definitions mock
	jq '.[].groupVersion' test/support/discovery/resource_definitions.json
