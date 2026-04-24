defmodule Mix.Tasks.Jido.Connect.Github.App.Convert do
  @moduledoc """
  Converts a GitHub App manifest code into local demo credentials.

      mix jido.connect.github.app.convert CODE
      mix jido.connect.github.app.convert CODE --env .env --secrets-dir .secrets

  Requires `gh` to be installed and authenticated.
  """

  use Mix.Task

  @shortdoc "Converts a GitHub App manifest code into .env credentials"

  @impl Mix.Task
  def run(args) do
    {opts, argv, invalid} =
      OptionParser.parse(args,
        strict: [
          env: :string,
          secrets_dir: :string
        ]
      )

    if invalid != [] do
      Mix.raise("invalid options: #{inspect(invalid)}")
    end

    code = List.first(argv) || Mix.raise("usage: mix jido.connect.github.app.convert CODE")
    env_path = Keyword.get(opts, :env, ".env")
    secrets_dir = Keyword.get(opts, :secrets_dir, ".secrets")

    unless System.find_executable("gh") do
      Mix.raise("gh was not found on PATH")
    end

    conversion = convert_manifest!(code)

    File.mkdir_p!(secrets_dir)

    json_path = Path.join(secrets_dir, "github-app.json")
    pem_path = Path.join(secrets_dir, "github-app.pem")

    File.write!(json_path, Jason.encode!(conversion, pretty: true))
    File.write!(pem_path, Map.fetch!(conversion, "pem"))
    File.chmod!(pem_path, 0o600)

    upsert_env!(env_path, %{
      "GITHUB_APP_ID" => to_string(Map.fetch!(conversion, "id")),
      "GITHUB_CLIENT_ID" => Map.fetch!(conversion, "client_id"),
      "GITHUB_CLIENT_SECRET" => Map.fetch!(conversion, "client_secret"),
      "GITHUB_WEBHOOK_SECRET" => Map.fetch!(conversion, "webhook_secret"),
      "GITHUB_PRIVATE_KEY_PATH" => pem_path
    })

    Mix.shell().info("""
    Converted GitHub App manifest.

    Raw response: #{json_path}
    Private key:  #{pem_path}
    Env file:     #{env_path}

    Next:
    set -a && source #{env_path} && set +a
    """)
  end

  defp convert_manifest!(code) do
    case System.cmd("gh", ["api", "-X", "POST", "/app-manifests/#{code}/conversions"],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        Jason.decode!(output)

      {output, status} ->
        Mix.raise("gh api conversion failed with status #{status}:\n#{output}")
    end
  end

  defp upsert_env!(env_path, updates) do
    existing =
      if File.exists?(env_path) do
        File.read!(env_path)
      else
        File.read!(".env.example")
      end

    update_keys = updates |> Map.keys() |> MapSet.new()

    lines =
      existing
      |> String.split("\n", trim: false)
      |> Enum.map(fn line ->
        case String.split(line, "=", parts: 2) do
          [key, _value] ->
            if MapSet.member?(update_keys, key) do
              "#{key}=#{Map.fetch!(updates, key)}"
            else
              line
            end

          _other ->
            line
        end
      end)

    present_keys =
      lines
      |> Enum.flat_map(fn line ->
        case String.split(line, "=", parts: 2) do
          [key, _value] -> [key]
          _other -> []
        end
      end)
      |> MapSet.new()

    missing_lines =
      updates
      |> Enum.reject(fn {key, _value} -> MapSet.member?(present_keys, key) end)
      |> Enum.map(fn {key, value} -> "#{key}=#{value}" end)

    output =
      lines
      |> append_missing_lines(missing_lines)
      |> Enum.join("\n")
      |> String.trim_trailing()

    File.write!(env_path, output <> "\n")
  end

  defp append_missing_lines(lines, []), do: lines

  defp append_missing_lines(lines, missing_lines),
    do: lines ++ ["", "# GitHub App manifest output"] ++ missing_lines
end
