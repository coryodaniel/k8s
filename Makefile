.PHONY: help clean deps all test tdd cov test/all lint analyze

help: ## Show this help
help:
	@grep -E '^[\/a-zA-Z0-9._%-]+:.*?## .*$$' Makefile | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

clean: ## Remove build/doc dirs
	rm -rf _build
	rm -rf cover
	rm -rf deps
	rm -rf doc

deps: ## Fetch deps
	mix deps.get

all: ## Run format, credo, dialyzer, and test all supported k8s versions
all: deps lint test/all analyze

test: ## Run fast tests on k8s latest stable
	mix test

tdd: ## Run fast test on k8s last stable in a loop
	mix test.watch

cov: ## Generate coverage HTML
	mix coveralls.html

test/all: ## Run full test suite against
test/all: test/1.10 test/1.11 test/1.12 test/1.13 test/master

test/%: ## Run full test suite against a specific k8s version
	K8S_SPEC=test/support/swagger/$*.json mix test

lint: ## Format and run credo
	mix format
	mix credo

analyze: ## Run dialyzer
	mix dialyzer
