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
      {:jason, "~> 1.4"},
      {:nx, "~> 0.9.2"},
      {:bandit, "~> 1.6"},
      {:websock, "~> 0.5"},
      {:websock_adapter, "~> 0.5"}
    ]
  end
end
