defmodule K8s.MixProject do
  use Mix.Project

  def project do
    [
      app: :k8s,
      description: "A Kubernetes library and HTTP client in Elixir",
      version: "0.2.3",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.travis": :test
      ],
      docs: [
        extras: ["README.md", "docs/usage.md"],
        main: "readme"
      ],
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [
        plt_add_apps: [:mix, :eex],
        ignore_warnings: ".dialyzer_ignore.exs"
      ]
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
      {:yaml_elixir, "~> 2.1"},
      {:httpoison, "~> 1.0"},
      {:jason, "~> 1.0"},

      # dev/test deps
      {:credo, "~> 1.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.4", only: [:dev, :test], runtime: false},
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
end
