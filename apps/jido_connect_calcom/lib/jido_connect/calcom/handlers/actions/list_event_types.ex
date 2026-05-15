defmodule Jido.Connect.Calcom.Handlers.Actions.ListEventTypes do
  @moduledoc false

  alias Jido.Connect.Calcom.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, params} <- list_input(input),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, event_types} <-
           client.list_event_types(params, ResourceHelpers.credential_token(credentials)) do
      {:ok,
       %{
         event_types:
           event_types
           |> Enum.map(&ResourceHelpers.public_map/1)
       }}
    end
  end

  defp list_input(input) do
    params =
      input
      |> Map.take([:username, :event_slug, :org_slug, :org_id])
      |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
      |> Map.new()

    {:ok, params}
  end
end
