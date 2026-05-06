defmodule Jido.Connect.Gmail.Handlers.Actions.CreateDraft do
  @moduledoc false

  alias Jido.Connect.Gmail.{Client, MIME}

  def run(input, %{credentials: credentials}) do
    with {:ok, raw} <- MIME.build_raw(input),
         {:ok, client} <- fetch_client(credentials),
         {:ok, draft} <-
           client.create_draft(Map.put(input, :raw, raw), Map.get(credentials, :access_token)) do
      {:ok, %{draft: public_map(draft)}}
    end
  end

  defp fetch_client(%{gmail_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(map) when is_map(map), do: map
  defp public_map(value), do: value
end
