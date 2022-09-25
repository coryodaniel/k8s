defmodule K8s.MixProject do
  use Mix.Project

  @source_url "https://github.com/coryodaniel/k8s"
  @version "1.1.5"

  def project do
    [
      app: :k8s,
      description: "Kubernetes API Client for Elixir",
      version: @version,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: cli_env(),
      docs: docs(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: dialyzer(),
      xref: [exclude: [:cover]]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :websockex]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:castore, "~> 0.1"},
      {:yaml_elixir, "~> 2.8"},
      {:httpoison, "~> 1.7"},
      {:jason, "~> 1.0"},
      {:telemetry, "~> 1.0"},

      # dev/test deps (e.g. code coverage)
      {:inch_ex, github: "rrrene/inch_ex", only: [:dev, :test]},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:test, :dev], runtime: false},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:excoveralls, "~> 0.14", only: [:test]},
      {:mix_test_watch, "~> 1.1", only: :dev, runtime: false},
      {:stream_data, "~> 0.4", only: :test},
      {:websockex, "~> 0.4.0"}
    ]
  end

  defp package do
    [
      name: :k8s,
      maintainers: ["Cory O'Daniel"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "https://hexdocs.pm/k8s/changelog.html"
      },
      files: ["lib", "mix.exs", "README*", "LICENSE*", "CHANGELOG.md"]
    ]
  end

  defp docs do
    [
      extras: [
        "README.md",
        "CHANGELOG.md",
        "guides/usage.md",
        "guides/operations.md",
        "guides/connections.md",
        "guides/middleware.md",
        "guides/authentication.md",
        "guides/discovery.md",
        "guides/advanced.md",
        "guides/testing.md",
        "guides/observability.md"
      ],
      main: "readme",
      source_ref: @version,
      source_url: @source_url,
      formatters: ["html"]
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
      ignore_warnings: ".dialyzer_ignore.exs",
      plt_add_apps: [:mix, :eex],
      plt_core_path: "priv/plts",
      plt_file: {:no_warn, "priv/plts/k8s.plt"}
    ]
  end
end
