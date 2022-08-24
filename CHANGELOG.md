# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

<!-- Add your changelog entry to the relevant subsection -->

<!-- ### Added | Changed | Deprecated | Removed | Fixed | Security -->

### Fixed

- `K8s.Resourse.label/2`: spec updated to accept label maps as a second argument [#177](https://github.com/coryodaniel/k8s/pull/177)









<!--------------------- Don't add new entries after this line --------------------->

## [1.1.5] - 2022-05-19

### Fixed

- `K8s.Client.watch_and_stream/2`: 410 Gone not rescued [#159](https://github.com/coryodaniel/k8s/pull/159)
- `K8s.Client.watch/3`: `get` operations should be transformed to `list` BEFORE retrieving the resource version [#160](https://github.com/coryodaniel/k8s/pull/160)

### Changed

- `K8s.Client.watch_and_stream/2`: Request BOOKMARK events and process them when watching resource collections. [#159](https://github.com/coryodaniel/k8s/pull/159)

## [1.1.4] - 2022-03-15

- Fix more authorization headers that are not keyword lists [#148](https://github.com/coryodaniel/k8s/pull/148)

## [1.1.3] - 2022-03-13

### Fixed

- Fix default value in `K8s.Client.Runner.Watch.run/4` and `K8s.Client.Runner.Watch.stream/3`

## [1.1.2] - 2022-03-13

### Fixed

- Support for FQDN K8s API servers and Root CA chains [#144](https://github.com/coryodaniel/k8s/issues/144)
- Wrong exception raised by `K8s.Resource.from_file!/2` [#137](https://github.com/coryodaniel/k8s/issues/137), [#143](https://github.com/coryodaniel/k8s/issues/143)
- `K8s.Client.Runner.Watch.stream/3` - convert `:get` to `:list` operation with field selector.
- Make Logger metadata `library: :k8s` available at compile time.

## [1.1.1] - 2022-03-01

### Fixed

- Initialize authorization header as valid keyword list [#142](https://github.com/coryodaniel/k8s/pull/142)
- Restore deprecated `K8s.Sys.Event` module.

## [1.1.0] - 2022-02-21

### Added

- `K8s.Client.Runner.Watch.stream/3` - watches a resource and returns an elixir [Stream](https://hexdocs.pm/elixir/1.12/Stream.html) of events #121
- `K8s.Client.apply/2` - Create a [server-side apply](https://kubernetes.io/docs/reference/using-api/server-side-apply/) operation

### Changed

- Handle generic kubernetes response Failure without a reason [#120](https://github.com/coryodaniel/k8s/pull/120)
- Replace Notion with Telemetry and improve Logging [#128](https://github.com/coryodaniel/k8s/pull/128)

### Deprecated

- `K8s.Client.HTTPProvider.headers/2` was deprecated in favor of `K8s.Client.HTTPProvider.headers/1`
- `K8s.Client.DynamicHTTPProvider.headers/2` was deprecated in favor of `K8s.Client.DynamicHTTPProvider.headers/1`

### Fixed

- Preserve namespace in `get_to_list/1` [#122](https://github.com/coryodaniel/k8s/issues/122), [#123](https://github.com/coryodaniel/k8s/pull/123)
- Fix obsolete doc on wait operation [#118](https://github.com/coryodaniel/k8s/pull/118)
- Dialyzer errors with K8s.Client functions [#119](https://github.com/coryodaniel/k8s/issues/119)
- Enable peer certificate authentication #127. Be aware, this will break configurations that have been using incorrect certificate(s) up to this point.

## [1.0.0] - 2021-07-19

### Added

- `K8s.Resource.NamedList.access!/1` raises if item is missing
- K8s.Operation.put_label_selector/2
- K8s.Operation.get_label_selector/1
- Per connection http provider configuration
- K8s.Operation now uses keyword lists for query_params instead of maps

### Changed

- error tuples refactored away from binary and atom to exception modules
- removed dialyzer exceptions
- `K8s.Conn.from_file/2` now returns an ok or error tuple
- `K8s.Conn.from_service_account/N` now returns an ok or error tuple
- `K8s.Conn.t()` is now the first argument in all runners. `K8s.Operation.t()` is now the second.
- deprecated K8s.http_provider/0
- deprecated K8s.Discovery.default_opts/0
- deprecated K8s.Discovery.default_driver/0
- Refactored cluster names to strings
- `K8s.Resource.NamedList.access/1` deals better with missing items now
- Removed K8s.Client.run/4, use `K8s.Client.run/3` to pass options to HTTP provider
- Middleware moved to K8s.Conn.Middleware

### Removed

- K8s.Conn.lookup/1
- config.exs based cluster registration is no longer supported, build K8s.Conn using K8s.Conn module
- environment variable based cluster registration has been removed and may be moved to an external library

## [0.5.2] - 2020-07-31

### Added

- Added auth `exec` support

## [0.5.1] - 2020-07-17

### Added

- K8s.Operation struct `query_params` field
- BasicAuth auth provider
- Deprecated HTTPoison options being passed to K8s.Client.Runner.base
- K8s.Operation.put_query_param/3 to add query parameters by key
- K8s.Operation.get_query_param/3 to get a query parameter by key
- DigitalOcean authentication
- `K8s.Resource.NamedList.access/1` - Accessor for lists with named items (containers, env, ...) ([#82](https://github.com/coryodaniel/k8s/pull/82))

### Changed

- Refactored old references to `cluster_name` to `conn`

## [0.5.0] - 2020-02-12

### Added

- #42 Request middleware support
- #43 Just in time discovery: K8s.Discovery
- #44 Support for ad-hoc connections. K8s.Conn based functions. Build your own Conn at runtime or config mix/env vars. No more Cluster registry.
- K8s.Resource.from_file/2 and K8s.Resource.all_from_file/2 - non-exception versions

### Removed

- Boot time discovery K8s.Cluster.Discovery
- K8s.Cluster.base_url/1
- Remove K8s.Cluster\*

## [0.4.0] - 2019-08-29

### Changed

- Renamed `K8s.Conf` to `K8s.Conn`
- Refactored `:conf` configuration key to `:conn`

## [0.3.2] - 2019-08-15

### Added

- `K8s.Selector.match_expressions?/2` to check if a resource matches expressions
- `K8s.Selector.match_labels?/2` to check if a resource matches labels

### Changed

- `K8s.Resource` functions moved to submodule

## [0.3.1] - 2019-08-15

### Added

- text/plain response handling
- K8s.Selector - labelSelector support for K8s.Operation

## [0.3.0] - 2019-07-29

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
