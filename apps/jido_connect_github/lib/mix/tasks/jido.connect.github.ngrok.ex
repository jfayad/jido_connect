defmodule Mix.Tasks.Jido.Connect.Github.Ngrok do
  @moduledoc """
  Starts an ngrok tunnel for the local demo host and prints GitHub URLs.

      mix jido.connect.github.ngrok
      mix jido.connect.github.ngrok --port 4001

  This is a convenience wrapper around `mix jido.connect.ngrok --provider github`.
  """

  use Mix.Task

  @shortdoc "Starts an ngrok tunnel for GitHub integration demos"

  @impl Mix.Task
  def run(args) do
    Mix.Tasks.Jido.Connect.Ngrok.run(["--provider", "github" | args])
  end
end
