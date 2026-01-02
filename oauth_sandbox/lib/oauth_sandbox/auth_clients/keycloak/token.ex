defmodule OauthSandbox.AuthClients.Keycloak.Token do
  use Joken.Config
  alias OauthSandbox.Constants, as: C

  defmodule Strategy do
    use JokenJwks.DefaultStrategyTemplate
    alias OauthSandbox.AuthClients.Keycloak

    def get_issuer,
      do: "#{Keycloak.fetch_config!(:base_url)}/realms/#{Keycloak.fetch_config!(:realm)}"

    def init_opts(opts),
      do: [jwks_url: jwks_url(), time_interval: Keyword.fetch!(opts, :time_interval)]

    def jwks_url, do: "#{get_issuer()}/protocol/openid-connect/certs"
  end

  add_hook(JokenJwks, strategy: Strategy)

  @doc """
  Get the discovery document endpoint URL (the endpoint that points to JWKS info) for the main
  Keycloak realm that is configured for use in this application (e.g. "my-realm").
  """
  def get_default_discovery_document_endpoint_url, do: Strategy.jwks_url()

  @doc "Wraps `JokenJwks.HttpFetcher.fetch_signers/2` with defaults for our Keycloak config."
  def fetch_signers(opts \\ []) do
    url = Keyword.get(opts, :url, get_default_discovery_document_endpoint_url())
    fetch_signers_opts = Keyword.get(opts, :fetch_signers_opts, [])

    JokenJwks.HttpFetcher.fetch_signers(url, fetch_signers_opts)
  end

  @impl Joken.Config
  def token_config do
    default_claims(skip: [:iss, :aud])
    |> add_claim("iss", nil, fn iss ->
      iss == Strategy.get_issuer()
    end)
    |> add_claim("aud", nil, fn aud ->
      is_list(aud) and C.elixir_server_expected_oauth_audience() in aud
    end)
    |> add_claim("scope", nil, fn scope ->
      scope |> String.split() |> Enum.any?(&(&1 == C.elixir_server_expected_oauth_scope()))
    end)
  end
end
