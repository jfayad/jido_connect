defmodule Jido.Connect.GitHub.Handlers.Actions.SearchIssues do
  @moduledoc false

  alias Jido.Connect.{Data, Error}

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.search_issues(search_params(input), Map.get(credentials, :access_token)) do
      {:ok,
       %{
         results: Enum.map(Map.fetch!(result, :results), &normalize_result/1),
         total_count: Map.get(result, :total_count)
       }}
    end
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end

  defp search_params(input) do
    %{
      q: search_query(input),
      sort: Map.get(input, :sort, "updated"),
      direction: Map.get(input, :direction, "desc"),
      page: Map.get(input, :page, 1),
      per_page: Map.get(input, :per_page, 30)
    }
  end

  defp search_query(input) do
    [
      Map.get(input, :query, ""),
      qualifier("repo", Map.fetch!(input, :repo)),
      type_qualifier(Map.get(input, :type, "all")),
      qualifier("state", state(input)),
      qualifier("author", Map.get(input, :author)),
      qualifier("assignee", Map.get(input, :assignee)),
      qualifier("label", Map.get(input, :label))
    ]
    |> Enum.reject(&blank?/1)
    |> Enum.join(" ")
  end

  defp type_qualifier("issue"), do: "is:issue"
  defp type_qualifier("pull_request"), do: "is:pr"
  defp type_qualifier(_type), do: nil

  defp state(%{state: "all"}), do: nil
  defp state(input), do: Map.get(input, :state, "open")

  defp qualifier(_name, value) when value in [nil, ""], do: nil
  defp qualifier(name, value), do: "#{name}:#{value}"

  defp blank?(value), do: is_nil(value) or value == ""

  defp normalize_result(result) do
    %{
      type: Map.get(result, :type, :issue),
      number: Map.fetch!(result, :number),
      url: Map.fetch!(result, :url),
      title: Map.fetch!(result, :title),
      state: Map.fetch!(result, :state),
      user: Map.get(result, :user),
      labels: Map.get(result, :labels, []),
      comments: Map.get(result, :comments),
      created_at: Map.get(result, :created_at),
      updated_at: Map.get(result, :updated_at)
    }
    |> Data.compact()
  end
end
