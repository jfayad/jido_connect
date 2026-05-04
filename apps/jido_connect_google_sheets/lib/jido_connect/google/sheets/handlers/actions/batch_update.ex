defmodule Jido.Connect.Google.Sheets.Handlers.Actions.BatchUpdate do
  @moduledoc false

  alias Jido.Connect.{Error, Google.Sheets.Client}

  @max_requests 100

  def run(input, %{credentials: credentials}) do
    with :ok <- validate_requests(input),
         {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.batch_update(normalize_input(input), Map.get(credentials, :access_token)) do
      {:ok, %{batch_update: result}}
    end
  end

  defp validate_requests(%{requests: requests}) when is_list(requests) do
    cond do
      requests == [] ->
        {:error,
         Error.validation("Batch update requests must not be empty",
           reason: :invalid_batch_update_requests,
           details: %{expected: "non-empty list"}
         )}

      length(requests) > @max_requests ->
        {:error,
         Error.validation("Batch update request count exceeds limit",
           reason: :invalid_batch_update_requests,
           details: %{max_requests: @max_requests, request_count: length(requests)}
         )}

      true ->
        validate_request_shapes(requests)
    end
  end

  defp validate_requests(_input) do
    {:error,
     Error.validation("Batch update requests must be a list",
       reason: :invalid_batch_update_requests,
       details: %{expected: :list}
     )}
  end

  defp validate_request_shapes(requests) do
    requests
    |> Enum.with_index()
    |> Enum.find_value(fn {request, index} ->
      cond do
        not is_map(request) ->
          invalid_request(index, "request must be a map")

        map_size(request) != 1 ->
          invalid_request(index, "request must contain exactly one operation")

        true ->
          nil
      end
    end)
    |> case do
      nil -> :ok
      error -> error
    end
  end

  defp invalid_request(index, message) do
    {:error,
     Error.validation("Invalid batch update request",
       reason: :invalid_batch_update_request,
       details: %{index: index, message: message}
     )}
  end

  defp normalize_input(input) do
    input
    |> Map.put_new(:include_spreadsheet_in_response, false)
    |> Map.put_new(:response_ranges, [])
    |> Map.put_new(:response_include_grid_data, false)
  end

  defp fetch_client(%{google_sheets_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
