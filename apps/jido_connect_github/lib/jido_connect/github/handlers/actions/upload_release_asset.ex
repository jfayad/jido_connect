defmodule Jido.Connect.GitHub.Handlers.Actions.UploadReleaseAsset do
  @moduledoc false

  alias Jido.Connect.{Data, Error}

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, asset} <-
           client.upload_release_asset(
             Map.fetch!(input, :upload_url),
             asset_attrs(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok, normalize_asset(asset)}
    end
  end

  defp asset_attrs(input) do
    %{
      name: Map.fetch!(input, :name),
      label: Map.get(input, :label),
      content_type: Map.fetch!(input, :content_type),
      content_base64: Map.fetch!(input, :content_base64)
    }
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end

  defp normalize_asset(asset) do
    %{
      id: Map.fetch!(asset, :id),
      node_id: Map.get(asset, :node_id),
      name: Map.fetch!(asset, :name),
      label: Map.get(asset, :label),
      state: Map.get(asset, :state),
      content_type: Map.get(asset, :content_type),
      size: Map.get(asset, :size),
      download_count: Map.get(asset, :download_count),
      url: Map.get(asset, :url),
      browser_download_url: Map.get(asset, :browser_download_url),
      created_at: Map.get(asset, :created_at),
      updated_at: Map.get(asset, :updated_at),
      uploader: Map.get(asset, :uploader)
    }
    |> Data.compact()
  end
end
