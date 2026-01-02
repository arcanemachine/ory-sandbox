defmodule OauthSandbox.JwtHelpers do
  @moduledoc "JWT helper functions"

  def read_jwt_header(jwt_string), do: JOSE.JWT.peek_protected(jwt_string)

  def read_jwt_payload(jwt_string), do: JOSE.JWT.peek_payload(jwt_string)
end
