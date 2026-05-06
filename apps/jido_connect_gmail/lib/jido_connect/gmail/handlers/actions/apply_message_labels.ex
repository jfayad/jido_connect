defmodule Jido.Connect.Gmail.Handlers.Actions.ApplyMessageLabels do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Gmail.Client

  def run(input, %{credentials: credentials}) do
    input = normalize_input(input)

    with :ok <- validate_label_changes(input),
         {:ok, client} <- fetch_client(credentials),
         {:ok, message} <- client.apply_message_labels(input, Map.get(credentials, :access_token)) do
      {:ok, %{message: public_map(message)}}
    end
  end

  defp normalize_input(input) do
    input
    |> Map.put(:add_label_ids, normalize_label_ids(Data.get(input, :add_label_ids, [])))
    |> Map.put(:remove_label_ids, normalize_label_ids(Data.get(input, :remove_label_ids, [])))
  end

  defp validate_label_changes(input) do
    add_label_ids = Data.get(input, :add_label_ids, [])
    remove_label_ids = Data.get(input, :remove_label_ids, [])

    cond do
      not valid_label_ids?(add_label_ids) ->
        validation_error("Gmail add_label_ids must be label ids", :add_label_ids)

      not valid_label_ids?(remove_label_ids) ->
        validation_error("Gmail remove_label_ids must be label ids", :remove_label_ids)

      add_label_ids == [] and remove_label_ids == [] ->
        validation_error(
          "Gmail label mutation requires add_label_ids or remove_label_ids",
          :labels
        )

      true ->
        :ok
    end
  end

  defp valid_label_ids?(label_ids) when is_list(label_ids),
    do: Enum.all?(label_ids, &(is_binary(&1) and String.trim(&1) != ""))

  defp valid_label_ids?(_label_ids), do: false

  defp normalize_label_ids(label_ids) when is_list(label_ids) do
    Enum.map(label_ids, fn
      label_id when is_binary(label_id) -> String.trim(label_id)
      label_id -> label_id
    end)
  end

  defp normalize_label_ids(label_ids), do: label_ids

  defp validation_error(message, field) do
    {:error, Error.validation(message, reason: :invalid_label_mutation, details: %{field: field})}
  end

  defp fetch_client(%{gmail_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(map) when is_map(map), do: map
  defp public_map(value), do: value
end
