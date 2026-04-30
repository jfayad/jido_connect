defmodule Jido.Connect.Slack.Handlers.Actions.UploadFile do
  @moduledoc false

  alias Jido.Connect.Error

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, upload} <-
           client.upload_file(
             Map.take(input, [
               :channel_id,
               :filename,
               :content,
               :title,
               :initial_comment,
               :thread_ts,
               :alt_txt,
               :snippet_type
             ]),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         file_id: Map.fetch!(upload, :file_id),
         files: Map.get(upload, :files, [])
       }}
    end
  end

  defp fetch_client(%{slack_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("Slack client module is required", key: :slack_client)}
  end
end
