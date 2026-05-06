defmodule Jido.Connect.Gmail.Client.Params do
  @moduledoc "Gmail request parameter helpers."

  def message_list_params(params) when is_map(params) do
    []
    |> maybe_put(:q, Map.get(params, :query))
    |> put_repeated(:labelIds, Map.get(params, :label_ids, []))
    |> maybe_put(:maxResults, Map.get(params, :page_size, 25))
    |> maybe_put(:pageToken, Map.get(params, :page_token))
    |> maybe_put(:includeSpamTrash, Map.get(params, :include_spam_trash))
  end

  def thread_list_params(params) when is_map(params), do: message_list_params(params)

  def metadata_get_params(params) when is_map(params) do
    []
    |> maybe_put(:format, "metadata")
    |> put_repeated(:metadataHeaders, Map.get(params, :metadata_headers, []))
  end

  defp put_repeated(params, _key, nil), do: params
  defp put_repeated(params, _key, []), do: params

  defp put_repeated(params, key, values) when is_list(values),
    do: params ++ Enum.map(values, &{key, &1})

  defp put_repeated(params, key, value), do: Keyword.put(params, key, value)

  defp maybe_put(params, _key, nil), do: params
  defp maybe_put(params, _key, ""), do: params
  defp maybe_put(params, key, value), do: Keyword.put(params, key, value)
end
