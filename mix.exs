defmodule Rex.Mixfile do
  use Mix.Project

  def project do
    [
      app: :rex,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Rex.Application, []}
    ]
  end

  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
    ]
  end

  defp aliases do
    [
      test: "test --no-start"
    ]
  end
end
