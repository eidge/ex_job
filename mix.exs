defmodule ExJob.Mixfile do
  use Mix.Project

  @app :ex_job
  @version "0.2.1"
  @github "https://github.com/eidge/ex_job"

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.5",
      consolidate_protocols: Mix.env() != :test,
      description: "Zero dependency, ultra-fast, background job processing library.",
      package: package(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {ExJob.Application, []}
    ]
  end

  defp package do
    [
      name: @app,
      maintainers: ["Hugo Ribeira"],
      licenses: ["MIT"],
      files: ~w(mix.exs lib README.md),
      links: %{"Github" => @github}
    ]
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:benchee, "~> 0.11", only: :dev},
      {:gen_stage, "~> 0.13"}
    ]
  end

  defp aliases do
    [
      test: "test --no-start"
    ]
  end

  defp docs do
    [
      main: "ExJob",
      extras: ["README.md"]
    ]
  end
end
