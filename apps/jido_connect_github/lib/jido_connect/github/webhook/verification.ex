defmodule Jido.Connect.GitHub.Webhook.Verification do
  @moduledoc false

  alias Jido.Connect.{Error, WebhookDelivery}
  alias Jido.Connect.GitHub.Webhook.Normalizer
  alias Jido.Connect.Webhook, as: CoreWebhook

  def parse_headers(headers) when is_map(headers) do
    %{
      delivery_id: header(headers, "x-github-delivery"),
      event: header(headers, "x-github-event"),
      signature: header(headers, "x-hub-signature-256")
    }
  end

  def verify_signature(body, signature, secret)

  def verify_signature(_body, _signature, nil),
    do: {:error, Error.auth("GitHub webhook secret is required", reason: :missing_secret)}

  def verify_signature(_body, _signature, ""),
    do: {:error, Error.auth("GitHub webhook secret is required", reason: :missing_secret)}

  def verify_signature(_body, nil, _secret),
    do: {:error, Error.auth("GitHub webhook signature is required", reason: :missing_signature)}

  def verify_signature(body, "sha256=" <> expected, secret)
      when is_binary(body) and is_binary(secret) do
    CoreWebhook.verify_hmac_sha256(body, "sha256=" <> expected, secret,
      prefix: "sha256=",
      invalid_signature_message: "GitHub webhook signature is invalid",
      invalid_signature_reason: :invalid_signature
    )
  end

  def verify_signature(_body, _signature, _secret),
    do: {:error, Error.auth("GitHub webhook signature is invalid", reason: :invalid_signature)}

  def verify_request(body, headers, secret) do
    with {:ok, delivery} <- verify_delivery(body, headers, secret) do
      {:ok,
       %{
         delivery_id: delivery.delivery_id,
         event: delivery.event,
         signature: delivery.metadata.signature,
         payload: delivery.payload
       }}
    end
  end

  def verify_delivery(body, headers, secret, opts \\ []) do
    parsed = parse_headers(headers)

    with :ok <- verify_signature(body, parsed.signature, secret),
         {:ok, payload} <- decode_body(body),
         {:ok, delivery} <-
           WebhookDelivery.verified(:github, %{
             delivery_id: parsed.delivery_id,
             event: parsed.event,
             headers: headers,
             payload: payload,
             duplicate?:
               duplicate?(parsed.delivery_id, Keyword.get(opts, :seen_delivery_ids, [])),
             metadata: %{signature: parsed.signature}
           }) do
      {:ok, Normalizer.maybe_put_normalized_signal(delivery)}
    end
  end

  def duplicate?(delivery_id, seen_delivery_ids) do
    CoreWebhook.duplicate?(delivery_id, seen_delivery_ids)
  end

  defp decode_body(body) do
    CoreWebhook.decode_json(body,
      provider: :github,
      message: "GitHub webhook payload is invalid JSON"
    )
  end

  defp header(headers, key) do
    CoreWebhook.header(headers, key)
  end
end
