defmodule Mix.Tasks.Jido.Connect.Gen.Provider do
  @moduledoc """
  Generates a minimal Jido Connect provider package scaffold.

      mix jido.connect.gen.provider google_sheets

  By default files are written under `apps/`, matching the umbrella layout.
  """

  use Mix.Task

  alias Jido.Connect.Dev.ProviderScaffold

  @shortdoc "Generates a Jido Connect provider scaffold"

  @impl Mix.Task
  def run(args) do
    case args do
      [provider] ->
        paths = ProviderScaffold.write!("apps", provider)
        Enum.each(paths, &Mix.shell().info("created #{&1}"))

      _other ->
        Mix.raise(
          "expected provider name, for example: mix jido.connect.gen.provider google_sheets"
        )
    end
  end
end
