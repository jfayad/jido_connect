defmodule Jido.Connect.Gmail.Handlers.Actions.GetThread do
  @moduledoc false

  alias Jido.Connect.Gmail.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, thread} <-
           client.get_thread(normalize_input(input), Map.get(credentials, :access_token)) do
      {:ok, %{thread: public_map(thread)}}
    end
  end

  defp normalize_input(input), do: Map.put_new(input, :metadata_headers, [])

  defp fetch_client(%{gmail_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(map) when is_map(map), do: map
  defp public_map(value), do: value
end
