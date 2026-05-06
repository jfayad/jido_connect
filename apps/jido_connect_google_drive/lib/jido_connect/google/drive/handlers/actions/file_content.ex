defmodule Jido.Connect.Google.Drive.Handlers.Actions.FileContent do
  @moduledoc false

  defmacro __using__(operation: operation) do
    quote bind_quoted: [operation: operation] do
      alias Jido.Connect.Google.Drive.Client

      @operation operation

      def run(input, %{credentials: credentials}) do
        with {:ok, client} <- fetch_client(credentials),
             {:ok, file_content} <-
               apply(client, @operation, [
                 normalize_input(input),
                 Map.get(credentials, :access_token)
               ]) do
          {:ok, %{file_content: file_content}}
        end
      end

      defp normalize_input(input), do: Map.put_new(input, :supports_all_drives, false)

      defp fetch_client(%{google_drive_client: client}) when is_atom(client), do: {:ok, client}
      defp fetch_client(_credentials), do: {:ok, Client}
    end
  end
end
