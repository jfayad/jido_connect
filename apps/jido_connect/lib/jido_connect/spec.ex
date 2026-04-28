defmodule Jido.Connect.Spec do
  @moduledoc "Complete integration provider contract."

  alias Jido.Connect.{
    ActionSpec,
    AuthProfile,
    ConnectorCapability,
    NamedSchema,
    PolicyRequirement,
    TriggerSpec
  }

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.atom(),
              name: Zoi.string(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              category: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              package: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              status: Zoi.atom() |> Zoi.default(:available),
              tags: Zoi.list(Zoi.atom()) |> Zoi.default([]),
              visibility: Zoi.atom() |> Zoi.default(:public),
              docs: Zoi.list(Zoi.string()) |> Zoi.default([]),
              capabilities: Zoi.list(ConnectorCapability.schema()) |> Zoi.default([]),
              policies: Zoi.list(PolicyRequirement.schema()) |> Zoi.default([]),
              schemas: Zoi.list(NamedSchema.schema()) |> Zoi.default([]),
              auth_profiles: Zoi.list(AuthProfile.schema()) |> Zoi.default([]),
              actions: Zoi.list(ActionSpec.schema()) |> Zoi.default([]),
              triggers: Zoi.list(TriggerSpec.schema()) |> Zoi.default([]),
              metadata: Zoi.map() |> Zoi.default(%{})
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema
  def new!(attrs), do: Zoi.parse!(@schema, attrs) |> Jido.Connect.validate_spec!()

  def new(attrs) do
    {:ok, new!(attrs)}
  rescue
    error -> {:error, error}
  end
end
