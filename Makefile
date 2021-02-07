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
all: deps doc lint test analyze inch

.PHONY: doc
doc:
	mix docs

.PHONY: inch
inch:
	mix inch

.PHONY: test
test: ## Run fast tests on k8s latest stable
	mix test

.PHONY: tdd
tdd: ## Run fast test on k8s last stable in a loop
	mix test.watch

.PHONY: cov
cov: ## Generate coverage HTML
	mix coveralls.html

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
