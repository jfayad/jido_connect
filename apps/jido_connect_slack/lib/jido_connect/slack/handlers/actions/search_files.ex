defmodule Jido.Connect.Slack.Handlers.Actions.SearchFiles do
  @moduledoc false

  alias Jido.Connect.{Data, Error}

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.search_files(search_params(input), Map.get(credentials, :access_token)) do
      {:ok,
       %{
         query: Data.get(result, :query, search_query(input)),
         files: Enum.map(Data.get(result, :files, []), &normalize_file/1),
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

  defp normalize_file(file) when is_map(file) do
    %{
      id: Data.get(file, :id),
      created: Data.get(file, :created),
      timestamp: Data.get(file, :timestamp),
      name: Data.get(file, :name),
      title: Data.get(file, :title),
      mimetype: Data.get(file, :mimetype),
      filetype: Data.get(file, :filetype),
      pretty_type: Data.get(file, :pretty_type),
      user: Data.get(file, :user),
      user_team: Data.get(file, :user_team),
      mode: Data.get(file, :mode),
      editable: Data.get(file, :editable),
      size: Data.get(file, :size),
      is_external: Data.get(file, :is_external),
      external_type: Data.get(file, :external_type),
      is_public: Data.get(file, :is_public),
      public_url_shared: Data.get(file, :public_url_shared),
      display_as_bot: Data.get(file, :display_as_bot),
      username: Data.get(file, :username),
      permalink: Data.get(file, :permalink),
      channels: Data.get(file, :channels),
      groups: Data.get(file, :groups),
      ims: Data.get(file, :ims),
      comments_count: Data.get(file, :comments_count),
      shares: Data.get(file, :shares),
      initial_comment: Data.get(file, :initial_comment)
    }
    |> Data.compact()
  end
end
