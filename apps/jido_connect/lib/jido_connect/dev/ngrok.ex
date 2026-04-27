defmodule Jido.Connect.Dev.Ngrok do
  @moduledoc """
  Local-development helpers for detecting ngrok public HTTPS tunnels.
  """

  alias Jido.Connect.Error

  @api ~c"http://127.0.0.1:4040/api/tunnels"

  @spec public_url() :: {:ok, String.t()} | {:error, Error.error()}
  def public_url do
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)

    case :httpc.request(:get, {@api, []}, [], body_format: :binary) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        body
        |> Jason.decode!()
        |> Map.get("tunnels", [])
        |> Enum.find_value(fn tunnel ->
          url = Map.get(tunnel, "public_url")
          if is_binary(url) and String.starts_with?(url, "https://"), do: {:ok, url}
        end)
        |> case do
          {:ok, url} -> {:ok, url}
          nil -> {:error, Error.config("No HTTPS ngrok tunnel found", key: :ngrok)}
        end

      {:ok, {{_, status, _}, _headers, body}} ->
        {:error,
         Error.config("Unable to inspect ngrok tunnels",
           key: :ngrok,
           details: %{status: status, body: body}
         )}

      {:error, reason} ->
        {:error,
         Error.config("Unable to inspect ngrok tunnels", key: :ngrok, details: %{reason: reason})}
    end
  rescue
    error ->
      {:error,
       Error.config("Unable to inspect ngrok tunnels", key: :ngrok, details: %{error: error})}
  end

  @spec public_url!() :: String.t()
  def public_url! do
    case public_url() do
      {:ok, url} -> url
      {:error, error} -> raise error
    end
  end
end
