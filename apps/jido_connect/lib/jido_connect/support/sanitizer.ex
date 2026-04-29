defmodule Jido.Connect.Sanitizer do
  @moduledoc """
  Sanitizes values before they cross observability or public transport boundaries.

  The telemetry profile keeps values inspectable and bounded for operators. The
  transport profile converts values into JSON-safe shapes for stable public
  error payloads.
  """

  @sensitive_keys MapSet.new([
                    :access_token,
                    :api_key,
                    :authorization,
                    :bot_token,
                    :client_secret,
                    :cookie,
                    :credential,
                    :credentials,
                    :fields,
                    :id_token,
                    :password,
                    :private_key,
                    :refresh_token,
                    :secret,
                    :set_cookie,
                    :signature,
                    :signing_secret,
                    :token,
                    :x_hub_signature_256,
                    :x_slack_signature,
                    "access_token",
                    "api_key",
                    "authorization",
                    "bot_token",
                    "client_secret",
                    "cookie",
                    "credential",
                    "credentials",
                    "fields",
                    "id_token",
                    "password",
                    "private_key",
                    "refresh_token",
                    "secret",
                    "set-cookie",
                    "set_cookie",
                    "signature",
                    "signing_secret",
                    "token",
                    "x-hub-signature-256",
                    "x-slack-signature",
                    "x_hub_signature_256",
                    "x_slack_signature"
                  ])

  @default_opts [
    max_depth: 4,
    max_binary: 512,
    max_collection: 50
  ]

  @type profile :: :telemetry | :transport

  @spec sanitize(term(), profile(), keyword()) :: term()
  def sanitize(value, profile \\ :telemetry, opts \\ [])
      when profile in [:telemetry, :transport] do
    opts = Keyword.merge(@default_opts, opts)
    do_sanitize(value, profile, opts, 0)
  end

  defp do_sanitize(value, profile, opts, depth) do
    if depth >= opts[:max_depth] do
      "[truncated]"
    else
      do_sanitize_value(value, profile, opts, depth)
    end
  end

  defp do_sanitize_value(value, _profile, _opts, _depth)
       when is_nil(value) or is_boolean(value) or is_number(value),
       do: value

  defp do_sanitize_value(value, :telemetry, _opts, _depth) when is_atom(value), do: value

  defp do_sanitize_value(value, :transport, _opts, _depth) when is_atom(value),
    do: Atom.to_string(value)

  defp do_sanitize_value(value, _profile, opts, _depth) when is_binary(value) do
    truncate_binary(value, opts[:max_binary])
  end

  defp do_sanitize_value(%DateTime{} = value, _profile, _opts, _depth),
    do: DateTime.to_iso8601(value)

  defp do_sanitize_value(%NaiveDateTime{} = value, _profile, _opts, _depth),
    do: NaiveDateTime.to_iso8601(value)

  defp do_sanitize_value(%Date{} = value, _profile, _opts, _depth), do: Date.to_iso8601(value)
  defp do_sanitize_value(%Time{} = value, _profile, _opts, _depth), do: Time.to_iso8601(value)

  defp do_sanitize_value(%_module{} = value, profile, opts, depth) do
    value
    |> Map.from_struct()
    |> Map.put(:struct, value.__struct__)
    |> do_sanitize(profile, opts, depth)
  end

  defp do_sanitize_value(value, profile, opts, depth) when is_map(value) do
    value
    |> Enum.take(opts[:max_collection])
    |> Map.new(fn {key, item} ->
      sanitized_key = sanitize_key(key, profile)

      sanitized_value =
        if sensitive_key?(key) do
          "[redacted]"
        else
          do_sanitize(item, profile, opts, depth + 1)
        end

      {sanitized_key, sanitized_value}
    end)
    |> maybe_note_truncation(map_size(value), opts[:max_collection], profile)
  end

  defp do_sanitize_value(value, profile, opts, depth) when is_list(value) do
    value
    |> Enum.take(opts[:max_collection])
    |> Enum.map(&do_sanitize(&1, profile, opts, depth + 1))
    |> maybe_append_truncation(length(value), opts[:max_collection])
  end

  defp do_sanitize_value(value, :transport, opts, depth) when is_tuple(value) do
    %{
      "__type__" => "tuple",
      "items" =>
        value
        |> Tuple.to_list()
        |> Enum.take(opts[:max_collection])
        |> Enum.map(&do_sanitize(&1, :transport, opts, depth + 1))
    }
  end

  defp do_sanitize_value(value, :telemetry, opts, _depth) when is_tuple(value) do
    value
    |> inspect(limit: opts[:max_collection], printable_limit: opts[:max_binary])
    |> truncate_binary(opts[:max_binary])
  end

  defp do_sanitize_value(value, _profile, opts, _depth) do
    value
    |> inspect(limit: opts[:max_collection], printable_limit: opts[:max_binary])
    |> truncate_binary(opts[:max_binary])
  end

  defp sanitize_key(key, :telemetry), do: key
  defp sanitize_key(key, :transport) when is_atom(key), do: Atom.to_string(key)
  defp sanitize_key(key, :transport) when is_binary(key), do: key
  defp sanitize_key(key, :transport), do: inspect(key)

  defp sensitive_key?(key) when is_binary(key) do
    MapSet.member?(@sensitive_keys, key) or
      key
      |> String.downcase()
      |> String.replace("-", "_")
      |> then(&MapSet.member?(@sensitive_keys, &1))
  end

  defp sensitive_key?(key) when is_atom(key) do
    MapSet.member?(@sensitive_keys, key) or sensitive_key?(Atom.to_string(key))
  end

  defp sensitive_key?(_key), do: false

  defp truncate_binary(value, max_binary) when byte_size(value) <= max_binary, do: value

  defp truncate_binary(value, max_binary) do
    kept = binary_part(value, 0, max_binary)
    "#{kept}...[truncated #{byte_size(value) - max_binary} bytes]"
  end

  defp maybe_note_truncation(map, size, max, :telemetry) when size > max,
    do: Map.put(map, :__truncated__, size - max)

  defp maybe_note_truncation(map, size, max, :transport) when size > max,
    do: Map.put(map, "__truncated__", size - max)

  defp maybe_note_truncation(map, _size, _max, _profile), do: map

  defp maybe_append_truncation(list, size, max) when size > max,
    do: list ++ ["[truncated #{size - max} items]"]

  defp maybe_append_truncation(list, _size, _max), do: list
end
