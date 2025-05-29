K8s.Client.DynamicHTTPProvider.start_link(nil)

ExUnit.start(
  exclude: [:integration, :reliability],
  timeout: System.get_env("MIX_TEST_TIMEOUT", "60000") |> String.to_integer()
)
