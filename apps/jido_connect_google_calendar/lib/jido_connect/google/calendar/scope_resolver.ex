defmodule Jido.Connect.Google.Calendar.ScopeResolver do
  @moduledoc """
  Resolves Google Calendar scopes.

  Calendar-list reads and event reads use separate narrow Google scopes. Broader
  Calendar grants are accepted when hosts already have them.
  """

  @calendar_scope "https://www.googleapis.com/auth/calendar"
  @calendar_readonly_scope "https://www.googleapis.com/auth/calendar.readonly"
  @calendar_list_scope "https://www.googleapis.com/auth/calendar.calendarlist.readonly"
  @freebusy_scope "https://www.googleapis.com/auth/calendar.freebusy"
  @events_readonly_scope "https://www.googleapis.com/auth/calendar.events.readonly"
  @events_scope "https://www.googleapis.com/auth/calendar.events"
  @calendar_list_actions ["google.calendar.calendar.list"]
  @freebusy_actions [
    "google.calendar.freebusy.query",
    "google.calendar.availability.find"
  ]
  @write_actions [
    "google.calendar.event.create",
    "google.calendar.event.update",
    "google.calendar.event.delete"
  ]

  def required_scopes(operation, _input, connection) do
    operation
    |> operation_id()
    |> required_for_operation(connection)
  end

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @calendar_list_actions and is_list(scopes) do
    cond do
      @calendar_scope in scopes -> [@calendar_scope]
      @calendar_readonly_scope in scopes -> [@calendar_readonly_scope]
      @calendar_list_scope in scopes -> [@calendar_list_scope]
      true -> [@calendar_list_scope]
    end
  end

  defp required_for_operation(operation_id, _connection)
       when operation_id in @calendar_list_actions do
    [@calendar_list_scope]
  end

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @freebusy_actions and is_list(scopes) do
    cond do
      @calendar_scope in scopes -> [@calendar_scope]
      @calendar_readonly_scope in scopes -> [@calendar_readonly_scope]
      @freebusy_scope in scopes -> [@freebusy_scope]
      true -> [@freebusy_scope]
    end
  end

  defp required_for_operation(operation_id, _connection)
       when operation_id in @freebusy_actions do
    [@freebusy_scope]
  end

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @write_actions and is_list(scopes) do
    cond do
      @calendar_scope in scopes -> [@calendar_scope]
      @events_scope in scopes -> [@events_scope]
      true -> [@events_scope]
    end
  end

  defp required_for_operation(operation_id, _connection)
       when operation_id in @write_actions do
    [@events_scope]
  end

  defp required_for_operation(_operation_id, %{scopes: scopes}) when is_list(scopes) do
    cond do
      @calendar_scope in scopes -> [@calendar_scope]
      @calendar_readonly_scope in scopes -> [@calendar_readonly_scope]
      @events_scope in scopes -> [@events_scope]
      true -> [@events_readonly_scope]
    end
  end

  defp required_for_operation(_operation_id, _connection), do: [@events_readonly_scope]

  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(operation), do: Map.get(operation, :id)
end
