import_file_if_available("~/.iex.exs")

IO.puts("Loading custom shell config from `#{__DIR__}/.iex.exs`...")

# Project imports
alias HelloOry.AuthClients.Keycloak, as: K
alias HelloOry.AuthClients.Keycloak.Token, as: KT
alias HelloOry.AuthClients.Keycloak.Token.Strategy, as: KTS
