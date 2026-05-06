defmodule Jido.Connect.Gmail.Privacy do
  @moduledoc """
  Gmail privacy boundary helpers.

  Gmail message subjects, snippets, addresses, labels, and headers can contain
  personal or message content. Full RFC822 body content, Gmail `raw` payloads,
  and MIME part `body.data` bytes are intentionally excluded from normalized
  metadata structs unless a future action explicitly declares body access.
  """

  @message_content_fields [
    :snippet,
    :headers,
    :payload_summary,
    :email_address,
    :subject,
    :to,
    :cc,
    :bcc,
    :from
  ]
  @raw_body_keys MapSet.new(["raw", "body", "data", :raw, :body, :data])

  @doc "Fields that should be treated as message content or personal data."
  def message_content_fields, do: @message_content_fields

  @doc "Returns true for raw body keys that should not survive default normalization."
  def raw_body_key?(key), do: MapSet.member?(@raw_body_keys, key)
end
