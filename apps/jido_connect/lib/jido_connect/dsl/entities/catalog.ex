defmodule Jido.Connect.Dsl.Entities.Catalog do
  @moduledoc false

  alias Jido.Connect.Dsl

  def integration_section do
    %Spark.Dsl.Section{
      name: :integration,
      schema: [
        id: [type: :atom, required: true],
        name: [type: :string, required: true],
        description: [type: :string],
        category: [type: :atom],
        docs: [type: {:list, :string}, default: []],
        metadata: [type: :map, default: %{}]
      ]
    }
  end

  def catalog_section do
    %Spark.Dsl.Section{
      name: :catalog,
      entities: [capability()],
      schema: [
        package: [type: :atom],
        status: [type: :atom, default: :available],
        tags: [type: {:list, :atom}, default: []],
        visibility: [type: :atom, default: :public],
        description: [type: :string],
        metadata: [type: :map, default: %{}]
      ]
    }
  end

  def policies_section do
    %Spark.Dsl.Section{
      name: :policies,
      entities: [policy()]
    }
  end

  defp capability do
    %Spark.Dsl.Entity{
      name: :capability,
      target: Dsl.Capability,
      args: [:name],
      identifier: :name,
      schema: [
        name: [type: :atom, required: true],
        id: [type: :string],
        kind: [type: :atom, required: true],
        feature: [type: :atom],
        label: [type: :string],
        description: [type: :string],
        status: [type: :atom, default: :available],
        metadata: [type: :map, default: %{}]
      ]
    }
  end

  defp policy do
    %Spark.Dsl.Entity{
      name: :policy,
      target: Dsl.PolicyRequirement,
      args: [:name],
      identifier: :name,
      schema: [
        name: [type: :atom, required: true],
        id: [type: :atom],
        label: [type: :string],
        description: [type: :string],
        subject: [type: :any],
        owner: [type: :any],
        decision: [type: :atom, default: :allow_operation],
        metadata: [type: :map, default: %{}]
      ]
    }
  end
end
