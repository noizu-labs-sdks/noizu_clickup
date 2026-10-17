defmodule Noizu.ClickUp.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/noizu-labs-sdks/noizu_clickup"

  def project do
    [
      app: :noizu_clickup,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      name: "Noizu.ClickUp",
      description: description(),
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:req, "~> 0.7"},
      {:jason, "~> 1.4"},
      {:plug, "~> 1.16", only: [:test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Elixir client for the ClickUp API v2: workspaces, spaces, folders, lists, tasks, " <>
      "comments, custom fields, members, tags, time tracking, and signed webhooks. " <>
      "Built on Req with pagination streams, rate-limit-aware retries, and typed errors."
  end

  defp package do
    [
      name: "noizu_clickup",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "API Contract" => @source_url <> "/blob/main/docs/API-CONTRACT.md"
      },
      files: ~w(lib docs/API-CONTRACT.md CHANGELOG.md LICENSE README.md mix.exs .formatter.exs)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: [
        "README.md": [filename: "readme", title: "Noizu.ClickUp"],
        "CHANGELOG.md": [],
        "docs/API-CONTRACT.md": [title: "API Contract"]
      ]
    ]
  end
end
