defmodule Jido.Connect.Gmail.Handlers.Actions.CreateLabel do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Gmail.Client

  def run(input, %{credentials: credentials}) do
    with :ok <- validate_name(Data.get(input, :name)),
         {:ok, client} <- fetch_client(credentials),
         {:ok, label} <- client.create_label(input, Map.get(credentials, :access_token)) do
      {:ok, %{label: public_map(label)}}
    end
  end

  defp validate_name(name) when is_binary(name) do
    if String.trim(name) == "" do
      validation_error("Gmail label name must not be blank", :name)
    else
      :ok
    end
  end

  defp validate_name(_name), do: validation_error("Gmail label name is required", :name)

  defp validation_error(message, field) do
    {:error, Error.validation(message, reason: :invalid_label, details: %{field: field})}
  end

  defp fetch_client(%{gmail_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(map) when is_map(map), do: map
  defp public_map(value), do: value
end
