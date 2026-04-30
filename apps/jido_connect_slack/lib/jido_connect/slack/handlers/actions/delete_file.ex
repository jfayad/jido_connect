defmodule Jido.Connect.Slack.Handlers.Actions.DeleteFile do
  @moduledoc false

  alias Jido.Connect.Error

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, file} <-
           client.delete_file(
             Map.take(input, [:file_id]),
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{file_id: Map.fetch!(file, :file_id)}}
    end
  end

  defp fetch_client(%{slack_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("Slack client module is required", key: :slack_client)}
  end
end
