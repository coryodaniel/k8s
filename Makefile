.PHONY: clean test/all test lint analyze cov tdd all help build

DEFAULT_VERSION=1.13
SWAGGER_SPECS = $(wildcard ./test/support/swagger/*.json)

help: ## Show this help
help:
	@grep -E '^[\/a-zA-Z0-9._%-]+:.*?## .*$$' Makefile | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

clean:
	rm -rf _build
	rm -rf cover
	rm -rf deps
	rm -rf doc

build:
	mix deps.get
	mix compile

all: ## Run format, credo, dialyzer, and test all supported k8s versions
all: build lint test/all analyze

test: ## Run fast tests on k8s latest stable
	mix test --exclude external:true

tdd: ## Run fast test on k8s last stable in a loop
	mix test.watch --exclude external:true

cov: ## Generate coverage HTML
	mix coveralls.html

test/all: ## Run full test suite agains all supported k8s versions
	$(foreach SPEC, $(SWAGGER_SPECS), $(MAKE) test/$(basename $(notdir $(SPEC))))

test/%: ## Run full test suite against a specific k8s version
	K8S_SPEC=test/support/swagger/$*.json mix test

lint: ## Format and run credo
	mix format
	mix credo

analyze: ## Run dialyzer
	mix dialyzer
