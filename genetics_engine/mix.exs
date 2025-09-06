defmodule GeneticsEngine.MixProject do
  use Mix.Project

  def project do
    [
      app: :genetics_engine,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test
      ],
      docs: &docs/0
    ]
  end

  defp docs do
    [
      main: "GeneticsEngine", # The main page in the docs
#      logo: "path/to/logo.png",
      extras: ["README.md"]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :runtime_tools, :wx, :observer],
      mod: {GeneticsEngine.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bandit, "~> 1.6.11"},
      {:excoveralls, "~> 0.18.5"},
      {:ex_doc, "~> 0.38.2"},
      {:jason, "~> 1.4"},
      {:nanoid, "~> 2.1"},
      {:nx, "~> 0.9.2"},
      {:req, "~> 0.5.10", only: :test},
      {:websock, "~> 0.5"},
      {:websock_adapter, "~> 0.5"},
    ]
  end
end
