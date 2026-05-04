defmodule Jido.Connect.Slack.Webhook do
  @moduledoc """
  Pure helpers for Slack signed request verification and event normalization.
  """

  alias Jido.Connect.Slack.Webhook.{Normalizer, Verification}

  defdelegate parse_headers(headers), to: Verification
  defdelegate verify_signature(body, headers, signing_secret, opts \\ []), to: Verification
  defdelegate verify_request(body, headers, signing_secret, opts \\ []), to: Verification
  defdelegate verify_delivery(body, headers, signing_secret, opts \\ []), to: Verification

  def url_verification_challenge(%{"type" => "url_verification", "challenge" => challenge})
      when is_binary(challenge) do
    {:ok, challenge}
  end

  def url_verification_challenge(_payload) do
    {:error,
     Jido.Connect.Error.provider("Slack payload is not a URL verification challenge",
       provider: :slack,
       reason: :not_url_verification
     )}
  end

  defdelegate normalize_signal(delivery), to: Normalizer
  defdelegate normalize_signal(event, payload), to: Normalizer
  defdelegate normalize_event(payload), to: Normalizer
end
