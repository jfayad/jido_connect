defmodule Jido.Connect.Google.Calendar.Handlers.Actions.EventMutation do
  @moduledoc false

  alias Jido.Connect.{Data, Error}

  @attendee_statuses ["needsAction", "declined", "tentative", "accepted"]
  @recurrence_prefixes ["RRULE:", "EXRULE:", "RDATE:", "EXDATE:"]
  @send_updates ["all", "externalOnly", "none"]

  def validate_create(input) do
    with :ok <- validate_time_pair(input, required?: true),
         :ok <- validate_attendees(input),
         :ok <- validate_recurrence(input),
         :ok <- validate_recurrence_timezone(input),
         :ok <- validate_send_updates(input) do
      :ok
    end
  end

  def validate_update(input) do
    with :ok <- validate_time_pair(input, required?: false),
         :ok <- validate_attendees(input),
         :ok <- validate_recurrence(input),
         :ok <- validate_recurrence_timezone(input),
         :ok <- validate_send_updates(input) do
      :ok
    end
  end

  def normalize_create(input) do
    input
    |> normalize_common()
    |> Map.put_new(:attendees, [])
    |> Map.put_new(:recurrence, [])
    |> Map.put_new(:all_day, false)
  end

  def normalize_update(input), do: normalize_common(input)

  defp validate_time_pair(input, opts) do
    start = Data.get(input, :start)
    finish = Data.get(input, :end)

    cond do
      Keyword.fetch!(opts, :required?) and blank?(start) ->
        validation_error("Google Calendar events require a start time",
          reason: :invalid_event_time,
          field: :start
        )

      Keyword.fetch!(opts, :required?) and blank?(finish) ->
        validation_error("Google Calendar events require an end time",
          reason: :invalid_event_time,
          field: :end
        )

      blank?(start) and blank?(finish) ->
        :ok

      blank?(start) or blank?(finish) ->
        validation_error("Google Calendar event time updates must include start and end",
          reason: :invalid_event_time,
          field: :start_end
        )

      Data.get(input, :all_day, false) ->
        validate_date_range(start, finish)

      true ->
        validate_datetime_range(start, finish, input)
    end
  end

  defp validate_date_range(start, finish) do
    with {:ok, start_date} <- parse_date(start, :start),
         {:ok, end_date} <- parse_date(finish, :end) do
      if Date.compare(end_date, start_date) == :gt do
        :ok
      else
        validation_error("Google Calendar event end date must be after start date",
          reason: :invalid_event_time,
          field: :end
        )
      end
    end
  end

  defp validate_datetime_range(start, finish, input) do
    with {:ok, start_datetime} <-
           parse_datetime(start, :start, effective_time_zone(input, :start)),
         {:ok, end_datetime} <- parse_datetime(finish, :end, effective_time_zone(input, :end)),
         {:ok, order} <- compare_datetimes(start_datetime, end_datetime) do
      if order == :gt do
        :ok
      else
        validation_error("Google Calendar event end time must be after start time",
          reason: :invalid_event_time,
          field: :end
        )
      end
    end
  end

  defp parse_date(value, field) when is_binary(value) do
    case value |> String.trim() |> Date.from_iso8601() do
      {:ok, date} ->
        {:ok, date}

      {:error, _reason} ->
        validation_error("Google Calendar all-day event dates must use ISO8601 dates",
          reason: :invalid_event_time,
          field: field,
          value: value
        )
    end
  end

  defp parse_date(value, field) do
    validation_error("Google Calendar all-day event dates must be strings",
      reason: :invalid_event_time,
      field: field,
      value: value
    )
  end

  defp parse_datetime(value, field, time_zone) when is_binary(value) do
    value = String.trim(value)

    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} ->
        {:ok, {:instant, datetime}}

      {:error, _reason} ->
        parse_local_datetime(value, field, time_zone)
    end
  end

  defp parse_datetime(value, field, _time_zone) do
    validation_error("Google Calendar event times must be strings",
      reason: :invalid_event_time,
      field: field,
      value: value
    )
  end

  defp parse_local_datetime(value, field, time_zone) do
    if present_string?(time_zone) do
      case NaiveDateTime.from_iso8601(value) do
        {:ok, datetime} ->
          {:ok, {:local, datetime, String.trim(time_zone)}}

        {:error, _reason} ->
          validation_error("Google Calendar event times must be RFC3339 datetimes",
            reason: :invalid_event_time,
            field: field,
            value: value
          )
      end
    else
      validation_error("Google Calendar event times require an offset or explicit time zone",
        reason: :invalid_event_time,
        field: field,
        value: value
      )
    end
  end

  defp compare_datetimes({:instant, start_time}, {:instant, end_time}) do
    {:ok, DateTime.compare(end_time, start_time)}
  end

  defp compare_datetimes({:local, start_time, time_zone}, {:local, end_time, time_zone}) do
    {:ok, NaiveDateTime.compare(end_time, start_time)}
  end

  defp compare_datetimes({:local, _start_time, _start_zone}, {:local, _end_time, _end_zone}) do
    validation_error("Google Calendar local event times must use the same time zone",
      reason: :invalid_event_time,
      field: :time_zone
    )
  end

  defp compare_datetimes(_start_time, _end_time) do
    validation_error(
      "Google Calendar event start and end must both use offsets or both use local times with time zones",
      reason: :invalid_event_time,
      field: :start_end
    )
  end

  defp validate_attendees(input) do
    case Data.get(input, :attendees) do
      nil ->
        :ok

      attendees when is_list(attendees) ->
        attendees
        |> Enum.with_index()
        |> Enum.reduce_while(:ok, fn {attendee, index}, :ok ->
          case validate_attendee(attendee, index) do
            :ok -> {:cont, :ok}
            {:error, error} -> {:halt, {:error, error}}
          end
        end)

      _invalid ->
        validation_error("Google Calendar attendees must be a list",
          reason: :invalid_event_attendee,
          field: :attendees
        )
    end
  end

  defp validate_attendee(attendee, index) when is_map(attendee) do
    with :ok <- require_attendee_email(attendee, index),
         :ok <- validate_attendee_status(attendee, index),
         :ok <- validate_additional_guests(attendee, index) do
      :ok
    end
  end

  defp validate_attendee(_attendee, index) do
    validation_error("Google Calendar attendees must be maps",
      reason: :invalid_event_attendee,
      field: :attendees,
      index: index
    )
  end

  defp require_attendee_email(attendee, index) do
    case Data.get(attendee, :email) do
      email when is_binary(email) ->
        if String.trim(email) == "" do
          attendee_error(:email, index, email)
        else
          :ok
        end

      value ->
        attendee_error(:email, index, value)
    end
  end

  defp validate_attendee_status(attendee, index) do
    case Data.get(attendee, :response_status) do
      nil ->
        :ok

      status when status in @attendee_statuses ->
        :ok

      status ->
        validation_error("Invalid Google Calendar attendee response status",
          reason: :invalid_event_attendee,
          field: :response_status,
          index: index,
          value: status,
          allowed: @attendee_statuses
        )
    end
  end

  defp validate_additional_guests(attendee, index) do
    case Data.get(attendee, :additional_guests) do
      nil ->
        :ok

      guests when is_integer(guests) and guests >= 0 ->
        :ok

      guests ->
        validation_error("Google Calendar attendee additional guests must be non-negative",
          reason: :invalid_event_attendee,
          field: :additional_guests,
          index: index,
          value: guests
        )
    end
  end

  defp validate_recurrence(input) do
    case Data.get(input, :recurrence) do
      nil ->
        :ok

      recurrence when is_list(recurrence) ->
        recurrence
        |> Enum.with_index()
        |> Enum.reduce_while(:ok, fn {line, index}, :ok ->
          case validate_recurrence_line(line, index) do
            :ok -> {:cont, :ok}
            {:error, error} -> {:halt, {:error, error}}
          end
        end)

      _invalid ->
        validation_error("Google Calendar recurrence must be a list",
          reason: :invalid_event_recurrence,
          field: :recurrence
        )
    end
  end

  defp validate_recurrence_line(line, index) when is_binary(line) do
    normalized = String.upcase(String.trim(line))

    if Enum.any?(@recurrence_prefixes, &String.starts_with?(normalized, &1)) do
      :ok
    else
      validation_error("Invalid Google Calendar recurrence line",
        reason: :invalid_event_recurrence,
        field: :recurrence,
        index: index,
        value: line,
        allowed_prefixes: @recurrence_prefixes
      )
    end
  end

  defp validate_recurrence_line(line, index) do
    validation_error("Google Calendar recurrence lines must be strings",
      reason: :invalid_event_recurrence,
      field: :recurrence,
      index: index,
      value: line
    )
  end

  defp validate_recurrence_timezone(input) do
    if Data.get(input, :all_day, false) or not recurrence_present?(input) do
      :ok
    else
      cond do
        present_string?(Data.get(input, :time_zone)) ->
          :ok

        present_string?(Data.get(input, :start_time_zone)) and
            present_string?(Data.get(input, :end_time_zone)) ->
          :ok

        true ->
          validation_error("Google Calendar recurring timed events require an explicit time zone",
            reason: :invalid_event_time,
            field: :time_zone
          )
      end
    end
  end

  defp validate_send_updates(input) do
    case Data.get(input, :send_updates) do
      nil ->
        :ok

      value when value in @send_updates ->
        :ok

      value ->
        validation_error("Invalid Google Calendar send_updates value",
          reason: :invalid_event_mutation,
          field: :send_updates,
          value: value,
          allowed: @send_updates
        )
    end
  end

  defp normalize_common(input) do
    input
    |> trim_string(:calendar_id)
    |> trim_string(:event_id)
    |> trim_string(:start)
    |> trim_string(:end)
    |> trim_string(:time_zone)
    |> trim_string(:start_time_zone)
    |> trim_string(:end_time_zone)
    |> normalize_attendees()
    |> normalize_recurrence()
  end

  defp normalize_attendees(input) do
    case Data.get(input, :attendees) do
      attendees when is_list(attendees) ->
        Map.put(input, :attendees, Enum.map(attendees, &normalize_attendee/1))

      _other ->
        input
    end
  end

  defp normalize_attendee(attendee) do
    attendee
    |> trim_string(:email)
    |> trim_string(:display_name)
    |> trim_string(:response_status)
    |> trim_string(:comment)
  end

  defp normalize_recurrence(input) do
    case Data.get(input, :recurrence) do
      recurrence when is_list(recurrence) ->
        Map.put(input, :recurrence, Enum.map(recurrence, &String.trim/1))

      _other ->
        input
    end
  end

  defp trim_string(input, field) do
    case Data.get(input, field) do
      value when is_binary(value) -> Map.put(input, field, String.trim(value))
      _other -> input
    end
  end

  defp attendee_error(field, index, value) do
    validation_error("Google Calendar attendees require email addresses",
      reason: :invalid_event_attendee,
      field: field,
      index: index,
      value: value
    )
  end

  defp recurrence_present?(input) do
    case Data.get(input, :recurrence) do
      recurrence when is_list(recurrence) -> recurrence != []
      _other -> false
    end
  end

  defp effective_time_zone(input, :start) do
    Data.get(input, :start_time_zone) || Data.get(input, :time_zone)
  end

  defp effective_time_zone(input, :end) do
    Data.get(input, :end_time_zone) || Data.get(input, :time_zone)
  end

  defp present_string?(value) when is_binary(value), do: String.trim(value) != ""
  defp present_string?(_value), do: false

  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(value), do: is_nil(value)

  defp validation_error(message, opts) do
    {reason, details} = Keyword.pop!(opts, :reason)
    {:error, Error.validation(message, reason: reason, details: Map.new(details))}
  end
end
