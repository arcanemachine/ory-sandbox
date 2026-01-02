defmodule OauthSandbox.Constants do
  constants = [
    elixir_server_expected_oauth_audience: "service-b",
    elixir_server_expected_oauth_scope: "service-b:read"
  ]

  @moduledoc "Constant values: #{for {k, v} <- constants, do: "\n\n- #{k}: #{inspect(v)}"}"

  for {k, v} <- constants do
    @doc "Constant value: #{inspect(v)}"
    def unquote(k)(), do: unquote(v)
  end
end
