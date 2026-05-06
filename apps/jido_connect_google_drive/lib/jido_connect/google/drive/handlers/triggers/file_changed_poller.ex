defmodule Jido.Connect.Google.Drive.Handlers.Triggers.FileChangedPoller do
  @moduledoc false

  alias Jido.Connect.Google.Drive.Client

  def poll(config, %{credentials: credentials, checkpoint: checkpoint}) do
    with {:ok, client} <- fetch_client(credentials) do
      poll_changes(
        client,
        normalize_config(config),
        checkpoint,
        Map.get(credentials, :access_token)
      )
    end
  end

  defp poll_changes(client, config, checkpoint, access_token) when checkpoint in [nil, ""] do
    with {:ok, %{start_page_token: start_page_token}} <-
           client.get_start_page_token(config, access_token) do
      {:ok, %{signals: [], checkpoint: start_page_token}}
    end
  end

  defp poll_changes(client, config, checkpoint, access_token) do
    params = Map.put(config, :page_token, checkpoint)

    with {:ok, result} <- client.list_changes(params, access_token) do
      {:ok,
       %{
         signals: Enum.map(Map.get(result, :changes, []), &normalize_signal/1),
         checkpoint:
           Map.get(result, :next_page_token) || Map.get(result, :new_start_page_token) ||
             checkpoint
       }}
    end
  end

  defp normalize_config(config) do
    config
    |> Map.put_new(:page_size, 100)
    |> Map.put_new(:spaces, "drive")
    |> Map.put_new(:include_items_from_all_drives, false)
    |> Map.put_new(:include_removed, true)
    |> Map.put_new(:restrict_to_my_drive, false)
    |> Map.put_new(:supports_all_drives, false)
  end

  defp normalize_signal(change) do
    %{
      change_id: Map.get(change, :change_id),
      file_id: Map.get(change, :file_id),
      removed: Map.get(change, :removed?, false),
      time: Map.get(change, :time),
      drive_id: Map.get(change, :drive_id),
      change_type: Map.get(change, :change_type),
      file: public_map(Map.get(change, :file))
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(map) when is_map(map), do: map
  defp public_map(value), do: value

  defp fetch_client(%{google_drive_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
