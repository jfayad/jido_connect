defmodule Jido.Connect.Slack.Handlers.Actions.ShareFile do
  @moduledoc false

  alias Jido.Connect.Error

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, share} <-
           client.share_file(
             Map.take(input, [
               :file_id,
               :channels,
               :title,
               :initial_comment,
               :thread_ts
             ]),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         file_id: Map.fetch!(share, :file_id),
         files: Map.get(share, :files, [])
       }}
    end
  end

  defp fetch_client(%{slack_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("Slack client module is required", key: :slack_client)}
  end
end
