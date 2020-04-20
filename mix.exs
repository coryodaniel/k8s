defmodule K8s.MixProject do
  use Mix.Project

  def project do
    [
      app: :k8s,
      description: "Kubernetes API Client for Elixir",
      version: "0.5.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: cli_env(),
      docs: docs(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: dialyzer()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {K8s.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:yaml_elixir, "~> 2.4"},
      {:httpoison, "~> 1.0"},
      {:jason, "~> 1.0"},
      {:notion, "~> 0.2"},
      {:telemetry, ">=  0.4.0"},

      # dev/test deps
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.20", only: :dev},
      {:excoveralls, "~> 0.10", only: :test},
      {:mix_test_watch, "~> 0.8", only: :dev, runtime: false},
      {:stream_data, "~> 0.4", only: :test}
    ]
  end

  defp package do
    [
      name: :k8s,
      maintainers: ["Cory O'Daniel"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/coryodaniel/k8s"
      }
    ]
  end

  defp docs do
    [
      extras: [
        "README.md",
        "guides/usage.md",
        "guides/operations.md",
        "guides/connections.md",
        "guides/middleware.md",
        "guides/authentication.md",
        "guides/discovery.md",
        "guides/advanced.md",
        "guides/testing.md"
      ],
      main: "readme"
    ]
  end

  defp cli_env do
    [
      coveralls: :test,
      "coveralls.detail": :test,
      "coveralls.post": :test,
      "coveralls.html": :test,
      "coveralls.travis": :test
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:mix, :eex],
      ignore_warnings: ".dialyzer_ignore.exs",
      plt_file: {:no_warn, "priv/plts/k8s.plt"}
    ]
  end
end
