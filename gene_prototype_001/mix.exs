defmodule GenePrototype0001.MixProject do
  use Mix.Project

  def project do
    [
      app: :gene_prototype_0001,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :runtime_tools, :wx, :observer],
      mod: {GenePrototype0001.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bandit, "~> 1.6.11"},
      {:cabbage, "~> 0.4.1"},
      {:jason, "~> 1.4"},
      {:nanoid, "~> 2.1"},
      {:nx, "~> 0.9.2"},
      {:req, "~> 0.5.10", only: :test},
      {:websock, "~> 0.5"},
      {:websock_adapter, "~> 0.5"},
    ]
  end
end
