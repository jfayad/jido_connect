defmodule Jido.Connect.GitHub.Webhook do
  @moduledoc """
  Pure helpers for GitHub webhook verification and event normalization.
  """

  alias Jido.Connect.GitHub.Webhook.{Normalizer, Verification}

  defdelegate parse_headers(headers), to: Verification
  defdelegate verify_signature(body, signature, secret), to: Verification
  defdelegate verify_request(body, headers, secret), to: Verification
  defdelegate verify_delivery(body, headers, secret, opts \\ []), to: Verification
  defdelegate duplicate?(delivery_id, seen_delivery_ids), to: Verification

  defdelegate normalize_signal(delivery), to: Normalizer
  defdelegate normalize_signal(event, payload), to: Normalizer
end
