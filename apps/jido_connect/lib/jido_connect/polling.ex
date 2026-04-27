defmodule Jido.Connect.Polling do
  @moduledoc """
  Small helpers for provider poll triggers and checkpoint handling.
  """

  alias Jido.Connect.Data

  @spec put_checkpoint_param(keyword(), atom(), term()) :: keyword()
  def put_checkpoint_param(params, _key, checkpoint) when checkpoint in [nil, ""], do: params
  def put_checkpoint_param(params, key, checkpoint), do: Keyword.put(params, key, checkpoint)

  @spec latest_checkpoint([map()], atom() | String.t(), term()) :: term()
  def latest_checkpoint([], _field, fallback), do: fallback

  def latest_checkpoint(items, field, fallback) when is_list(items) do
    items
    |> Enum.map(&Data.get(&1, field))
    |> Enum.reject(&is_nil/1)
    |> Enum.sort(:desc)
    |> List.first()
    |> case do
      nil -> fallback
      checkpoint -> checkpoint
    end
  end
end
