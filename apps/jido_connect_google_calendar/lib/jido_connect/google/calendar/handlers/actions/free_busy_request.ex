defmodule Jido.Connect.Google.Calendar.Handlers.Actions.FreeBusyRequest do
  @moduledoc false

  alias Jido.Connect.{Data, Error}

  def validate(input) do
    with :ok <- validate_calendar_ids(input),
         :ok <- validate_time_range(input) do
      :ok
    end
  end

  def normalize(input) do
    input
    |> normalize_calendar_ids()
    |> trim_string(:time_min)
    |> trim_string(:time_max)
    |> trim_string(:time_zone)
  end

  defp validate_calendar_ids(input) do
    case Data.get(input, :calendar_ids) do
      calendar_ids when is_list(calendar_ids) and calendar_ids != [] ->
        if Enum.all?(calendar_ids, &present_string?/1) do
          :ok
        else
          validation_error("Google Calendar freebusy calendar_ids must be non-empty strings",
            reason: :invalid_freebusy_request,
            field: :calendar_ids
          )
        end

      _invalid ->
        validation_error("Google Calendar freebusy requires calendar_ids",
          reason: :invalid_freebusy_request,
          field: :calendar_ids
        )
    end
  end

  defp validate_time_range(input) do
    with {:ok, start_time} <- parse_datetime(Data.get(input, :time_min), :time_min),
         {:ok, end_time} <- parse_datetime(Data.get(input, :time_max), :time_max) do
      if DateTime.compare(end_time, start_time) == :gt do
        :ok
      else
        validation_error("Google Calendar freebusy time_max must be after time_min",
          reason: :invalid_freebusy_request,
          field: :time_max
        )
      end
    end
  end

  defp parse_datetime(value, field) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} ->
        {:ok, datetime}

      {:error, _reason} ->
        validation_error("Google Calendar freebusy times must be RFC3339 datetimes",
          reason: :invalid_freebusy_request,
          field: field,
          value: value
        )
    end
  end

  defp parse_datetime(value, field) do
    validation_error("Google Calendar freebusy times must be strings",
      reason: :invalid_freebusy_request,
      field: field,
      value: value
    )
  end

  defp normalize_calendar_ids(input) do
    case Data.get(input, :calendar_ids) do
      calendar_ids when is_list(calendar_ids) ->
        Map.put(input, :calendar_ids, Enum.map(calendar_ids, &String.trim/1))

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

  defp present_string?(value) when is_binary(value), do: String.trim(value) != ""
  defp present_string?(_value), do: false

  defp validation_error(message, opts) do
    {reason, details} = Keyword.pop!(opts, :reason)
    {:error, Error.validation(message, reason: reason, details: Map.new(details))}
  end
end
