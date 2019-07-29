# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added

- `K8s.Client.DynamicHTTPProvider` to allow per-process registering of HTTP request handlers.
- `K8s.Cluster.Discovery` discovery interface
- `K8s.Cluster.Discovery.api_versions/1` - queries a cluster for all apiVersions
- `K8s.Cluster.Discovery.resource_definitions/1` - queries a cluster for all resource definitions
- `K8s.Cluster.Discovery.HTTPDriver` for discovery via k8s REST API
- `K8s.Cluster.Discovery.FileDriver` for discovery via a file, used for testing, shipped to help dependent libraries mock discovery
- Support for creating subresources
- Support for getting subresources
- Support for updating subresources

### Changed

- Refactored tests on DynamicHTTPProvider
- Refactored discovery to use `K8s.Cluster.Discovery`
- Set correct content-type for patch operations (https://github.com/coryodaniel/k8s/issues/32)
- Refactored Operation.kind -> Operation.name
- Group.cluster_key/2 -> Group.lookup_key/2
- K8s.Cluster.Group :ets data structure changed to map
- K8s.Cluster.Group module encompases access to :ets table
- Refactored Operation.resource -> Operation.data. The term `resource` is a bit overloaded in this repo, since the operation is encapsulating the HTTP request, `data` feels a bit more clear.
- Refactored internal references to "group version" to "api version"

## [0.2.13] - 2019-06-27

### Added

- K8s.Cluster.base_url/1

## [0.2.12] - 2019-06-26

### Added

- First K8s.Client.Runner.Stream evaluation made lazy
- K8s.Resource.api_version/1

## [0.2.11] - 2019-06-24

### Added

- K8s.Resource.cpu/1 parses cpu resource requests/limits strings to number
- K8s.Resource.memory/1 parses cpu resource requests/limits strings to number

## [0.2.10] - 2019-06-24

### Added

- K8s.Client.Runner.Stream for producing elixir streams from k8s list results
- K8s 1.15 swagger file

### Changed

- Reversed pattern matching in functions from `var=pattern` to `pattern=var`
- Added make target for fetching master swagger before running tests

## [0.2.9] - 2019-06-10

### Added

- Kubernetes resources, groups, and CRDs are autodiscovered at boot time. No swagger file to include or override.
- Client supports standard HTTP calls, async batches, wait on status, and watchers
- Supports multiple clusters
- Supports multiple kubernetes APIs in the same runtime
- serviceaccount authentication
- token authentication
- certificate authentication
- auth-provider authetnicati
- Tested against kubernetes swagger specs: 1.10+ and master
- CRD support
- Kubernetes resource and version helper functions
- Kube config file parsing
- Pluggable auth providers
