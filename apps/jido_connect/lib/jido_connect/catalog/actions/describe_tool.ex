defmodule Jido.Connect.Catalog.Actions.DescribeTool do
  @moduledoc "Describe one installed Jido Connect catalog tool."

  use Jido.Action,
    name: "connect_catalog_describe",
    description: "Describe one Jido Connect catalog tool",
    category: "catalog",
    tags: ["jido_connect", "catalog", "describe"],
    schema: %{
      "type" => "object",
      "required" => ["tool_id"],
      "properties" => %{
        "tool_id" => %{"type" => "string"},
        "provider" => %{"type" => "string"},
        "filters" => %{"type" => "object"},
        "pack" => %{}
      }
    },
    output_schema: %{
      "type" => "object",
      "properties" => %{"descriptor" => %{"type" => "object"}}
    }

  alias Jido.Connect.Catalog
  alias Jido.Connect.Catalog.Input

  @impl true
  def run(params, context) do
    with {:ok, tool_ref, opts} <- Input.describe_params(params, context),
         {:ok, descriptor} <- Catalog.describe_tool(tool_ref, opts) do
      {:ok, %{descriptor: Catalog.to_map(descriptor)}}
    end
  end
end
