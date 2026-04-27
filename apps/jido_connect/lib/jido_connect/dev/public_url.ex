defmodule Jido.Connect.Dev.PublicUrl do
  @moduledoc "Resolves local-demo public base URLs from options, env, or ngrok."

  alias Jido.Connect.Dev.Ngrok
  alias Jido.Connect.Error

  @spec resolve(keyword(), [String.t()]) :: {:ok, String.t()} | {:error, Error.error()}
  def resolve(opts \\ [], env_keys \\ []) do
    case explicit_url(opts, env_keys) do
      nil -> Ngrok.public_url()
      url -> {:ok, String.trim_trailing(url, "/")}
    end
  end

  @spec resolve!(keyword(), [String.t()]) :: String.t()
  def resolve!(opts \\ [], env_keys \\ []) do
    case resolve(opts, env_keys) do
      {:ok, url} -> url
      {:error, error} -> raise error
    end
  end

  defp explicit_url(opts, env_keys) do
    opts[:url] ||
      Enum.find_value(env_keys, fn key ->
        case System.get_env(key) do
          nil -> nil
          "" -> nil
          value -> value
        end
      end)
  end
end
