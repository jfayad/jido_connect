defmodule Jido.Connect.Google.Contacts.Handlers.Actions.DeleteContact do
  @moduledoc false

  alias Jido.Connect.Google.Contacts.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, result} <- client.delete_contact(input, Map.get(credentials, :access_token)) do
      {:ok, %{result: result}}
    end
  end

  defp fetch_client(%{google_contacts_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
