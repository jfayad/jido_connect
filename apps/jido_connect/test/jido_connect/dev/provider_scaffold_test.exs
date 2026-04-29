defmodule Jido.Connect.Dev.ProviderScaffoldTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Dev.ProviderScaffold

  test "provider scaffold returns conventional package files" do
    files = ProviderScaffold.files("google_sheets")
    paths = Enum.map(files, & &1.path)

    assert "jido_connect_google_sheets/mix.exs" in paths

    assert "jido_connect_google_sheets/lib/jido_connect/google_sheets/integration.ex" in paths
    assert "jido_connect_google_sheets/lib/jido_connect/google_sheets/actions/example.ex" in paths

    integration_file =
      Enum.find(files, &(&1.path =~ "integration.ex"))

    assert integration_file.contents =~ "defmodule Jido.Connect.GoogleSheets"
    assert integration_file.contents =~ "use Jido.Connect,"
    assert integration_file.contents =~ "catalog do"
    assert integration_file.contents =~ "policies do"

    action_file =
      Enum.find(files, &(&1.path =~ "actions/example.ex"))

    assert action_file.contents =~ "use Spark.Dsl.Fragment, of: Jido.Connect"
    assert action_file.contents =~ "data_classification :workspace_metadata"
  end
end
