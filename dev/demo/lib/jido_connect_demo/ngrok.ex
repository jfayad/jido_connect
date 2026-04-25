defmodule Jido.Connect.Demo.Ngrok do
  @moduledoc false

  @api ~c"http://127.0.0.1:4040/api/tunnels"

  def public_base_url do
    case System.get_env("JIDO_CONNECT_PUBLIC_BASE_URL") do
      nil -> detect_ngrok_url()
      "" -> detect_ngrok_url()
      url -> url
    end
  end

  def github_urls(base_url \\ public_base_url()) do
    if base_url do
      %{
        base_url: base_url,
        oauth_callback: base_url <> "/integrations/github/oauth/callback",
        setup: base_url <> "/integrations/github/setup",
        setup_complete: base_url <> "/integrations/github/setup/complete",
        webhook: base_url <> "/integrations/github/webhook"
      }
    else
      %{}
    end
  end

  def slack_urls(base_url \\ public_base_url()) do
    if base_url do
      %{
        base_url: base_url,
        oauth_callback: base_url <> "/integrations/slack/oauth/callback",
        events: base_url <> "/integrations/slack/events",
        interactivity: base_url <> "/integrations/slack/interactivity"
      }
    else
      %{}
    end
  end

  defp detect_ngrok_url do
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)

    case :httpc.request(:get, {@api, []}, [], body_format: :binary) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        body
        |> Jason.decode!()
        |> Map.get("tunnels", [])
        |> Enum.find_value(fn tunnel ->
          url = Map.get(tunnel, "public_url")
          if is_binary(url) and String.starts_with?(url, "https://"), do: url
        end)

      _other ->
        nil
    end
  rescue
    _error -> nil
  end
end
