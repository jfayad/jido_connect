defmodule Jido.Connect.GitHub.Webhook do
  @moduledoc """
  Pure helpers for GitHub webhook verification and event normalization.
  """

  def parse_headers(headers) when is_map(headers) do
    %{
      delivery_id: header(headers, "x-github-delivery"),
      event: header(headers, "x-github-event"),
      signature: header(headers, "x-hub-signature-256")
    }
  end

  def verify_signature(body, signature, secret)

  def verify_signature(_body, _signature, nil), do: {:error, :missing_secret}
  def verify_signature(_body, _signature, ""), do: {:error, :missing_secret}
  def verify_signature(_body, nil, _secret), do: {:error, :missing_signature}

  def verify_signature(body, "sha256=" <> expected, secret)
      when is_binary(body) and is_binary(secret) do
    actual =
      :hmac
      |> :crypto.mac(:sha256, secret, body)
      |> Base.encode16(case: :lower)

    if secure_compare(actual, expected), do: :ok, else: {:error, :invalid_signature}
  end

  def verify_signature(_body, _signature, _secret), do: {:error, :invalid_signature}

  def verify_request(body, headers, secret) do
    parsed = parse_headers(headers)

    with :ok <- verify_signature(body, parsed.signature, secret),
         {:ok, payload} <- decode_body(body) do
      {:ok, Map.put(parsed, :payload, payload)}
    end
  end

  def normalize_signal("issues", %{"action" => "opened"} = payload) do
    issue = get(payload, "issue") || %{}
    repo = get(payload, "repository") || %{}

    {:ok,
     %{
       repo: get(repo, "full_name"),
       issue_number: get(issue, "number"),
       title: get(issue, "title"),
       url: get(issue, "html_url") || get(issue, "url")
     }}
  end

  def normalize_signal("issues", %{action: "opened"} = payload) do
    normalize_signal("issues", stringify_keys(payload))
  end

  def normalize_signal("issues", payload) when is_map(payload) do
    {:error, {:unsupported_issue_action, get(payload, "action")}}
  end

  def normalize_signal(_event, _payload), do: {:error, :unsupported_event}

  def duplicate?(delivery_id, seen_delivery_ids) do
    delivery_id in seen_delivery_ids
  end

  defp decode_body(body) when is_binary(body) do
    Jason.decode(body)
  end

  defp header(headers, key) do
    Map.get(headers, key) || Map.get(headers, String.downcase(key)) ||
      Map.get(headers, String.to_atom(key))
  end

  defp get(map, key), do: Map.get(map, key) || Map.get(map, String.to_atom(key))

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end

  defp secure_compare(left, right) when byte_size(left) == byte_size(right) do
    left
    |> :binary.bin_to_list()
    |> Enum.zip(:binary.bin_to_list(right))
    |> Enum.reduce(0, fn {left_byte, right_byte}, acc ->
      :erlang.bor(acc, :erlang.bxor(left_byte, right_byte))
    end)
    |> Kernel.==(0)
  end

  defp secure_compare(_left, _right), do: false
end
