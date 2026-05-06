defmodule Jido.Connect.Google.Drive.Handlers.Actions.GetFile do
  @moduledoc false

  alias Jido.Connect.Google.Drive.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, file} <-
           client.get_file(normalize_input(input), Map.get(credentials, :access_token)) do
      {:ok, %{file: public_map(file)}}
    end
  end

  defp normalize_input(input), do: Map.put_new(input, :supports_all_drives, false)

  defp fetch_client(%{google_drive_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(map) when is_map(map), do: map
  defp public_map(value), do: value
end
