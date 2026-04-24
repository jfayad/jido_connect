defmodule Jido.Connect.Demo.Store do
  @moduledoc false

  use Agent

  alias Jido.Connect

  def start_link(_opts) do
    Agent.start_link(
      fn -> %{connections: %{}, credentials: %{}, deliveries: %{}, results: []} end,
      name: __MODULE__
    )
  end

  def reset! do
    ensure_started()

    Agent.update(__MODULE__, fn _state ->
      %{connections: %{}, credentials: %{}, deliveries: %{}, results: []}
    end)
  end

  def list_connections(provider \\ :github) do
    ensure_started()

    Agent.get(__MODULE__, fn state ->
      state.connections
      |> Map.values()
      |> Enum.filter(&(&1.provider == provider))
      |> Enum.sort_by(& &1.id)
    end)
  end

  def get_connection(id) do
    ensure_started()
    Agent.get(__MODULE__, fn state -> Map.fetch(state.connections, id) end)
  end

  def put_connection(%Connect.Connection{} = connection) do
    ensure_started()

    Agent.update(__MODULE__, fn state ->
      put_in(state, [:connections, connection.id], connection)
    end)

    connection
  end

  def put_credential(ref, fields) when is_binary(ref) and is_map(fields) do
    ensure_started()

    Agent.update(__MODULE__, fn state ->
      put_in(state, [:credentials, ref], fields)
    end)
  end

  def get_credential(ref) when is_binary(ref) do
    ensure_started()
    Agent.get(__MODULE__, fn state -> Map.get(state.credentials, ref, %{}) end)
  end

  def put_delivery(delivery) when is_map(delivery) do
    ensure_started()

    delivery_id = Map.fetch!(delivery, :delivery_id)

    Agent.update(__MODULE__, fn state ->
      state
      |> put_in([:deliveries, delivery_id], delivery)
      |> update_in([:results], fn results ->
        [%{type: :webhook, status: :ok, value: delivery, at: DateTime.utc_now()} | results]
        |> Enum.take(25)
      end)
    end)

    delivery
  end

  def delivery_seen?(delivery_id) do
    ensure_started()
    Agent.get(__MODULE__, fn state -> Map.has_key?(state.deliveries, delivery_id) end)
  end

  def recent_deliveries do
    ensure_started()

    Agent.get(__MODULE__, fn state ->
      state.deliveries
      |> Map.values()
      |> Enum.sort_by(& &1.received_at, {:desc, DateTime})
    end)
  end

  def put_result(type, status, value) do
    ensure_started()

    result = %{type: type, status: status, value: value, at: DateTime.utc_now()}

    Agent.update(__MODULE__, fn state ->
      update_in(state, [:results], fn results -> [result | results] |> Enum.take(25) end)
    end)

    result
  end

  def recent_results do
    ensure_started()
    Agent.get(__MODULE__, fn state -> state.results end)
  end

  defp ensure_started do
    if Process.whereis(__MODULE__) do
      :ok
    else
      case start_link([]) do
        {:ok, _pid} -> :ok
        {:error, {:already_started, _pid}} -> :ok
      end
    end
  end
end
