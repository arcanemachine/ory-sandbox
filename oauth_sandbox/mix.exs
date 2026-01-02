defmodule OauthSandbox.MixProject do
  use Mix.Project

  def project do
    [
      app: :oauth_sandbox,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {OauthSandbox.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug_cowboy, "~> 2.7"},
      {:req, "~> 0.5.16"},
      {:joken, "~> 2.6"},
      {:joken_jwks, "~> 1.7"},
      # TEMP: Hackney currently needed for Joken
      {:hackney, "~> 1.25"}
    ]
  end
end
