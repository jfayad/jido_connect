defmodule Jido.Connect.GitHub.Handlers.Actions.CreatePullRequestReviewComment do
  @moduledoc false

  alias Jido.Connect.{Data, Error}

  @sides ["LEFT", "RIGHT"]

  def run(input, %{credentials: credentials}) do
    with :ok <- validate_location(input),
         {:ok, client} <- fetch_client(credentials),
         {:ok, comment} <-
           client.create_pull_request_review_comment(
             Map.fetch!(input, :repo),
             Map.fetch!(input, :pull_number),
             review_comment_attrs(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         id: Map.fetch!(comment, :id),
         url: Map.fetch!(comment, :url),
         body: Map.fetch!(comment, :body),
         path: Map.fetch!(comment, :path),
         position: Map.get(comment, :position),
         line: Map.get(comment, :line),
         side: Map.get(comment, :side),
         start_line: Map.get(comment, :start_line),
         start_side: Map.get(comment, :start_side)
       }
       |> Data.compact()}
    end
  end

  defp validate_location(input) do
    position = Map.get(input, :position)
    line = Map.get(input, :line)

    cond do
      present?(position) and present?(line) ->
        validation_error(
          "GitHub pull request review comment requires either position or line, not both",
          :ambiguous_location,
          :position
        )

      present?(position) ->
        validate_position_location(input)

      present?(line) ->
        validate_line_location(input)

      true ->
        validation_error(
          "GitHub pull request review comment requires position or line",
          :missing_location,
          :position
        )
    end
  end

  defp validate_position_location(input) do
    with :ok <- validate_positive_integer(Map.get(input, :position), :position),
         :ok <- reject_present(input, :side, :position),
         :ok <- reject_present(input, :start_line, :position),
         :ok <- reject_present(input, :start_side, :position) do
      :ok
    end
  end

  defp validate_line_location(input) do
    with :ok <- validate_positive_integer(Map.get(input, :line), :line),
         :ok <- validate_side(Map.get(input, :side), :side),
         :ok <- validate_optional_positive_integer(Map.get(input, :start_line), :start_line),
         :ok <- validate_optional_side(Map.get(input, :start_side), :start_side),
         :ok <- validate_start_line_pair(input),
         :ok <- validate_line_range(input) do
      :ok
    end
  end

  defp validate_positive_integer(value, _subject) when is_integer(value) and value > 0, do: :ok

  defp validate_positive_integer(_value, subject) do
    validation_error(
      "GitHub pull request review comment line positions must be positive integers",
      :invalid_location,
      subject
    )
  end

  defp validate_optional_positive_integer(nil, _subject), do: :ok

  defp validate_optional_positive_integer(value, subject) do
    validate_positive_integer(value, subject)
  end

  defp validate_side(side, _subject) when side in @sides, do: :ok

  defp validate_side(_side, subject) do
    validation_error(
      "GitHub pull request review comment side must be LEFT or RIGHT",
      :invalid_side,
      subject
    )
  end

  defp validate_optional_side(nil, _subject), do: :ok

  defp validate_optional_side(side, subject), do: validate_side(side, subject)

  defp validate_start_line_pair(%{start_line: start_line, start_side: start_side})
       when not is_nil(start_line) and not is_nil(start_side),
       do: :ok

  defp validate_start_line_pair(%{start_line: start_line}) when not is_nil(start_line) do
    validation_error(
      "GitHub pull request review comment start_side is required with start_line",
      :missing_start_side,
      :start_side
    )
  end

  defp validate_start_line_pair(%{start_side: start_side}) when not is_nil(start_side) do
    validation_error(
      "GitHub pull request review comment start_line is required with start_side",
      :missing_start_line,
      :start_line
    )
  end

  defp validate_start_line_pair(_input), do: :ok

  defp validate_line_range(%{start_line: start_line, line: line})
       when is_integer(start_line) and is_integer(line) and start_line > line do
    validation_error(
      "GitHub pull request review comment start_line must be before or equal to line",
      :invalid_line_range,
      :start_line
    )
  end

  defp validate_line_range(_input), do: :ok

  defp reject_present(input, key, subject) do
    if present?(Map.get(input, key)) do
      validation_error(
        "GitHub pull request review comment position cannot be combined with line fields",
        :ambiguous_location,
        subject
      )
    else
      :ok
    end
  end

  defp present?(value), do: not is_nil(value)

  defp review_comment_attrs(input) do
    %{
      body: Map.fetch!(input, :body),
      commit_id: Map.fetch!(input, :commit_id),
      path: Map.fetch!(input, :path),
      position: Map.get(input, :position),
      line: Map.get(input, :line),
      side: Map.get(input, :side),
      start_line: Map.get(input, :start_line),
      start_side: Map.get(input, :start_side)
    }
    |> Data.compact()
  end

  defp validation_error(message, reason, subject) do
    {:error, Error.validation(message, reason: reason, subject: subject)}
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end
end
