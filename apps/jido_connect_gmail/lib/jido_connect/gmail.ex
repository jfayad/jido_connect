defmodule Jido.Connect.Gmail do
  @moduledoc """
  Gmail integration authored with the `Jido.Connect` Spark DSL.
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.Gmail.Actions.Read
    ]

  integration do
    id(:gmail)
    name("Gmail")
    description("Gmail mailbox, message, draft, send, label, and poll tools.")
    category(:email)
    docs(["https://developers.google.com/gmail/api/guides"])
  end

  catalog do
    package(:jido_connect_gmail)
    status(:available)
    tags([:google, :workspace, :email, :productivity])
  end

  auth do
    oauth2 :user do
      default?(true)
      owner(:app_user)
      subject(:user)
      label("Google OAuth user")
      authorize_url("https://accounts.google.com/o/oauth2/v2/auth")
      token_url("https://oauth2.googleapis.com/token")
      callback_path("/integrations/google/oauth/callback")
      token_field(:access_token)
      refresh_token_field(:refresh_token)
      setup :oauth2_authorization_code
      credential_fields([:access_token, :refresh_token])
      lease_fields([:access_token])

      scopes(
        Jido.Connect.Google.Scopes.user_default() ++
          Jido.Connect.Google.Scopes.product(:gmail)
      )

      default_scopes(Jido.Connect.Google.Scopes.user_default())
      optional_scopes(Jido.Connect.Google.Scopes.product(:gmail))
      pkce?(true)
      refresh?(true)
      revoke?(true)
    end
  end
end
