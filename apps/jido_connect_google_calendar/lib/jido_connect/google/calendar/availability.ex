defmodule Jido.Connect.Google.Calendar.Availability do
  @moduledoc "Computes candidate availability windows from Google Calendar free/busy data."

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Google.Calendar.FreeBusy

  @doc "Returns candidate windows that fit inside free gaps across all busy calendars."
  def candidate_windows(%FreeBusy{} = free_busy, opts) do
    with :ok <- reject_free_busy_errors(free_busy),
         {:ok, range_start} <- parse_datetime(Data.get(opts, :time_min), :time_min),
         {:ok, range_end} <- parse_datetime(Data.get(opts, :time_max), :time_max),
         :ok <- validate_range(range_start, range_end),
         {:ok, duration_seconds} <- positive_minutes(opts, :duration_minutes, 30),
         {:ok, step_seconds} <- positive_minutes(opts, :slot_step_minutes, duration_seconds / 60),
         {:ok, max_windows} <- positive_integer(opts, :max_windows, 10),
         {:ok, busy_intervals} <- busy_intervals(free_busy) do
      windows =
        range_start
        |> free_gaps(range_end, busy_intervals)
        |> candidate_windows(duration_seconds, step_seconds, max_windows)

      {:ok, windows}
    end
  end

  def candidate_windows(_free_busy, _opts) do
    validation_error("Availability requires a normalized freebusy response",
      reason: :invalid_availability,
      field: :free_busy
    )
  end

  defp reject_free_busy_errors(%FreeBusy{errors: []}), do: :ok

  defp reject_free_busy_errors(%FreeBusy{errors: errors}) do
    {:error,
     Error.provider("Google Calendar freebusy response contained errors",
       provider: :google,
       reason: :partial_response,
       details: %{errors: errors}
     )}
  end

  defp busy_intervals(%FreeBusy{busy: busy}) do
    busy
    |> Enum.reduce_while({:ok, []}, fn window, {:ok, acc} ->
      with {:ok, start_time} <- parse_datetime(Data.get(window, :start), :busy_start),
           {:ok, end_time} <- parse_datetime(Data.get(window, :end), :busy_end),
           :ok <- validate_range(start_time, end_time) do
        {:cont, {:ok, [{start_time, end_time} | acc]}}
      else
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, intervals} -> {:ok, merge_intervals(Enum.reverse(intervals))}
      {:error, error} -> {:error, error}
    end
  end

  defp merge_intervals(intervals) do
    intervals
    |> Enum.sort_by(fn {start_time, _end_time} -> DateTime.to_unix(start_time, :microsecond) end)
    |> Enum.reduce([], fn interval, acc ->
      merge_interval(interval, acc)
    end)
    |> Enum.reverse()
  end

  defp merge_interval(interval, []), do: [interval]

  defp merge_interval({start_time, end_time}, [{last_start, last_end} | rest]) do
    if DateTime.compare(start_time, last_end) in [:lt, :eq] do
      [{last_start, max_datetime(last_end, end_time)} | rest]
    else
      [{start_time, end_time}, {last_start, last_end} | rest]
    end
  end

  defp free_gaps(range_start, range_end, busy_intervals) do
    {cursor, gaps} =
      Enum.reduce(busy_intervals, {range_start, []}, fn {busy_start, busy_end}, {cursor, gaps} ->
        cond do
          DateTime.compare(busy_end, cursor) in [:lt, :eq] ->
            {cursor, gaps}

          DateTime.compare(busy_start, range_end) in [:gt, :eq] ->
            {cursor, gaps}

          DateTime.compare(busy_start, cursor) == :gt ->
            gap_end = min_datetime(busy_start, range_end)
            {max_datetime(cursor, busy_end), [{cursor, gap_end} | gaps]}

          true ->
            {max_datetime(cursor, busy_end), gaps}
        end
      end)

    gaps =
      if DateTime.compare(cursor, range_end) == :lt do
        [{cursor, range_end} | gaps]
      else
        gaps
      end

    Enum.reverse(gaps)
  end

  defp candidate_windows(gaps, duration_seconds, step_seconds, max_windows) do
    gaps
    |> Enum.reduce_while([], fn gap, acc ->
      windows = gap_windows(gap, duration_seconds, step_seconds, max_windows - length(acc))
      acc = acc ++ windows

      if length(acc) >= max_windows do
        {:halt, Enum.take(acc, max_windows)}
      else
        {:cont, acc}
      end
    end)
  end

  defp gap_windows(_gap, _duration_seconds, _step_seconds, remaining) when remaining <= 0, do: []

  defp gap_windows({gap_start, gap_end}, duration_seconds, step_seconds, remaining) do
    do_gap_windows(gap_start, gap_end, duration_seconds, step_seconds, remaining, [])
  end

  defp do_gap_windows(_slot_start, _gap_end, _duration_seconds, _step_seconds, 0, acc) do
    Enum.reverse(acc)
  end

  defp do_gap_windows(slot_start, gap_end, duration_seconds, step_seconds, remaining, acc) do
    slot_end = DateTime.add(slot_start, duration_seconds, :second)

    if DateTime.compare(slot_end, gap_end) in [:lt, :eq] do
      window = %{
        start: DateTime.to_iso8601(slot_start),
        end: DateTime.to_iso8601(slot_end),
        duration_minutes: div(duration_seconds, 60)
      }

      slot_start
      |> DateTime.add(step_seconds, :second)
      |> do_gap_windows(gap_end, duration_seconds, step_seconds, remaining - 1, [window | acc])
    else
      Enum.reverse(acc)
    end
  end

  defp parse_datetime(value, field) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} ->
        {:ok, datetime}

      {:error, _reason} ->
        validation_error("Google Calendar availability times must be RFC3339 datetimes",
          reason: :invalid_availability_time,
          field: field,
          value: value
        )
    end
  end

  defp parse_datetime(value, field) do
    validation_error("Google Calendar availability times must be strings",
      reason: :invalid_availability_time,
      field: field,
      value: value
    )
  end

  defp validate_range(start_time, end_time) do
    if DateTime.compare(end_time, start_time) == :gt do
      :ok
    else
      validation_error("Google Calendar availability end must be after start",
        reason: :invalid_availability_time,
        field: :time_max
      )
    end
  end

  defp positive_minutes(opts, field, default) do
    case Data.get(opts, field, default) do
      value when is_integer(value) and value > 0 ->
        {:ok, value * 60}

      value when is_float(value) and value > 0 ->
        {:ok, round(value * 60)}

      value ->
        validation_error("Google Calendar availability minutes must be positive",
          reason: :invalid_availability,
          field: field,
          value: value
        )
    end
  end

  defp positive_integer(opts, field, default) do
    case Data.get(opts, field, default) do
      value when is_integer(value) and value > 0 ->
        {:ok, value}

      value ->
        validation_error("Google Calendar availability limits must be positive integers",
          reason: :invalid_availability,
          field: field,
          value: value
        )
    end
  end

  defp max_datetime(left, right) do
    if DateTime.compare(left, right) == :lt, do: right, else: left
  end

  defp min_datetime(left, right) do
    if DateTime.compare(left, right) == :gt, do: right, else: left
  end

  defp validation_error(message, opts) do
    {reason, details} = Keyword.pop!(opts, :reason)
    {:error, Error.validation(message, reason: reason, details: Map.new(details))}
  end
end
