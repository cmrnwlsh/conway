defmodule Conway.MixProject do
  use Mix.Project

  def project do
    [
      app: :conway,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  # Convenience aliases. Run "mix lint" for strict static analysis.
  defp aliases do
    [lint: ["credo --strict"]]
  end
end
