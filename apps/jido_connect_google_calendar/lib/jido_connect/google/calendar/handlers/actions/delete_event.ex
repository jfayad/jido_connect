defmodule Jido.Connect.Google.Calendar.Handlers.Actions.DeleteEvent do
  @moduledoc false

  alias Jido.Connect.Google.Calendar.Client
  alias Jido.Connect.Google.Calendar.Handlers.Actions.EventMutation

  def run(input, %{credentials: credentials}) do
    with :ok <- EventMutation.validate_update(input),
         {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.delete_event(
             EventMutation.normalize_update(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{result: result}}
    end
  end

  defp fetch_client(%{google_calendar_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
