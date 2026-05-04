defmodule Jido.Connect.Catalog.Actions.CallTool do
  @moduledoc "Call one Jido Connect catalog action through the core runtime boundary."

  use Jido.Action,
    name: "connect_catalog_call",
    description: "Call one Jido Connect catalog action",
    category: "catalog",
    tags: ["jido_connect", "catalog", "call"],
    schema: %{
      "type" => "object",
      "required" => ["tool_id", "input"],
      "properties" => %{
        "tool_id" => %{"type" => "string"},
        "provider" => %{"type" => "string"},
        "input" => %{"type" => "object"},
        "filters" => %{"type" => "object"},
        "pack" => %{}
      }
    },
    output_schema: %{
      "type" => "object",
      "properties" => %{"result" => %{}}
    }

  alias Jido.Connect.Catalog
  alias Jido.Connect.Catalog.Input

  @impl true
  def run(params, context) do
    with {:ok, tool_ref, input, opts} <- Input.call_params(params, context),
         {:ok, result} <- Catalog.call_tool(tool_ref, input, opts) do
      {:ok, %{result: result}}
    end
  end
end
