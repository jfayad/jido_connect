defmodule Jido.Connect.Google.Sheets.Handlers.Actions.ValueWrite do
  @moduledoc false

  defmacro __using__(operation: operation) do
    quote bind_quoted: [operation: operation] do
      alias Jido.Connect.Google.Sheets.Client

      @operation operation

      def run(input, %{credentials: credentials}) do
        with {:ok, client} <- fetch_client(credentials),
             {:ok, update} <-
               apply(client, @operation, [
                 normalize_input(input),
                 Map.get(credentials, :access_token)
               ]) do
          {:ok, %{update: public_map(update)}}
        end
      end

      defp normalize_input(input) do
        input
        |> Map.put_new(:major_dimension, "ROWS")
        |> Map.put_new(:value_input_option, "RAW")
        |> Map.put_new(:include_values_in_response, false)
      end

      defp fetch_client(%{google_sheets_client: client}) when is_atom(client), do: {:ok, client}
      defp fetch_client(_credentials), do: {:ok, Client}

      defp public_map(struct) when is_struct(struct),
        do: struct |> Map.from_struct() |> public_map()

      defp public_map(map) when is_map(map), do: map
      defp public_map(value), do: value
    end
  end
end
