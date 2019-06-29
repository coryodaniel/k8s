.PHONY: help clean deps all test tdd cov test/all lint analyze get-and-test-master

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

test/all: ## Run full test suite against 1.10+ and master
test/all: test/1.10 test/1.11 test/1.12 test/1.13 test/1.14 test/1.15
test/all: get-and-test-master

MASTER_SWAGGER_PATH:=test/support/swagger/master.json
get-and-test-master:
	@-rm -f ${MASTER_SWAGGER_PATH}
	@curl -sSL https://raw.githubusercontent.com/kubernetes/kubernetes/master/api/openapi-spec/swagger.json -o ${MASTER_SWAGGER_PATH}
	K8S_SPEC=${MASTER_SWAGGER_PATH} mix test

test/%: ## Run full test suite against a specific k8s version
	K8S_SPEC=test/support/swagger/$*.json mix test

lint: ## Format and run credo
	mix format
	mix credo

analyze: ## Run dialyzer
	mix dialyzer

get/%: ## Add a new swagger spec to the test suite
	curl -sSL https://raw.githubusercontent.com/kubernetes/kubernetes/release-$*/api/openapi-spec/swagger.json -o test/support/swagger/$*.json
