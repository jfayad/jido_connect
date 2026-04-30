defmodule Jido.Connect.Slack.Handlers.Actions.SearchMessages do
  @moduledoc false

  alias Jido.Connect.{Data, Error}

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.search_messages(search_params(input), Map.get(credentials, :access_token)) do
      {:ok,
       %{
         query: Data.get(result, :query, search_query(input)),
         messages: Enum.map(Data.get(result, :messages, []), &normalize_message/1),
         total_count: total_count(result),
         pagination: Data.get(result, :pagination, %{}),
         paging: Data.get(result, :paging, %{}),
         next_cursor: Data.get(result, :next_cursor, "")
       }
       |> Data.compact()}
    end
  end

  defp fetch_client(%{slack_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("Slack client module is required", key: :slack_client)}
  end

  defp search_params(input) do
    %{
      query: search_query(input),
      sort: Map.get(input, :sort, "score"),
      sort_dir: Map.get(input, :sort_dir, "desc"),
      count: Map.get(input, :count, 20),
      page: Map.get(input, :page, 1),
      cursor: Map.get(input, :cursor),
      highlight: Map.get(input, :highlight, false),
      team_id: Map.get(input, :team_id)
    }
    |> Data.compact()
  end

  defp search_query(input) do
    [
      Map.fetch!(input, :query),
      qualifier("in", Map.get(input, :in)),
      qualifier("from", Map.get(input, :from)),
      qualifier("before", Map.get(input, :before)),
      qualifier("after", Map.get(input, :after)),
      qualifier("on", Map.get(input, :on)),
      qualifier("has", Map.get(input, :has))
    ]
    |> Enum.reject(&blank?/1)
    |> Enum.join(" ")
  end

  defp qualifier(_name, value) when value in [nil, ""], do: nil
  defp qualifier(name, value), do: "#{name}:#{value}"

  defp blank?(value), do: is_nil(value) or value == ""

  defp total_count(result) do
    Data.get(result, :total_count) ||
      result
      |> Data.get(:pagination, %{})
      |> Data.get(:total_count)
  end

  defp normalize_message(message) when is_map(message) do
    %{
      type: Data.get(message, :type),
      subtype: Data.get(message, :subtype),
      user: Data.get(message, :user),
      username: Data.get(message, :username),
      bot_id: Data.get(message, :bot_id),
      app_id: Data.get(message, :app_id),
      text: Data.get(message, :text),
      ts: Data.get(message, :ts),
      channel: normalize_channel(Data.get(message, :channel)),
      team: Data.get(message, :team),
      permalink: Data.get(message, :permalink),
      iid: Data.get(message, :iid),
      blocks: Data.get(message, :blocks),
      files: Data.get(message, :files),
      attachments: Data.get(message, :attachments),
      reactions: Data.get(message, :reactions)
    }
    |> Data.compact()
  end

  defp normalize_channel(channel) when is_map(channel) do
    %{
      id: Data.get(channel, :id),
      name: Data.get(channel, :name),
      is_private: Data.get(channel, :is_private),
      is_mpim: Data.get(channel, :is_mpim),
      is_shared: Data.get(channel, :is_shared),
      is_ext_shared: Data.get(channel, :is_ext_shared),
      is_org_shared: Data.get(channel, :is_org_shared)
    }
    |> Data.compact()
  end

  defp normalize_channel(_channel), do: nil
end
