defmodule Jido.Connect.ConnectorCapability do
  @moduledoc """
  Catalog-facing connector feature metadata.

  Capabilities are intentionally coarse. Tool-level detail still belongs to
  action and trigger specs; capabilities answer "what kind of connector support
  exists here?" for discovery, UI grouping, and package comparisons.
  """

  alias Jido.Connect.AuthProfile

  @kinds [:auth, :actions, :triggers, :webhook, :poll, :mcp, :runtime, :setup]
  @statuses [:available, :planned, :experimental, :deprecated]

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(),
              provider: Zoi.atom(),
              kind: Zoi.enum(@kinds),
              feature: Zoi.atom(),
              label: Zoi.string(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              status: Zoi.enum(@statuses) |> Zoi.default(:available),
              module: Zoi.module() |> Zoi.nullish() |> Zoi.optional(),
              metadata: Zoi.map() |> Zoi.default(%{})
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema
  def new!(attrs), do: Zoi.parse!(@schema, attrs)
  def new(attrs), do: Zoi.parse(@schema, attrs)

  @doc "Derives aggregate capabilities from a connector spec."
  @spec from_spec(map(), module() | nil) :: [t()]
  def from_spec(spec, module \\ nil) when is_map(spec) do
    auth_capabilities(spec, module) ++
      action_capabilities(spec, module) ++
      trigger_capabilities(spec, module) ++
      declared_capabilities(spec, module) ++
      metadata_capabilities(spec, module)
  end

  @doc "Converts a capability to a JSON-safe map."
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = capability) do
    %{
      id: capability.id,
      provider: capability.provider,
      kind: capability.kind,
      feature: capability.feature,
      label: capability.label,
      description: capability.description,
      status: capability.status,
      module: module_name(capability.module),
      metadata: capability.metadata
    }
  end

  defp auth_capabilities(spec, module) do
    Enum.map(spec.auth_profiles, fn %AuthProfile{} = profile ->
      new!(%{
        id: "#{spec.id}.auth.#{profile.id}",
        provider: spec.id,
        kind: :auth,
        feature: profile.kind,
        label: profile.label || humanize(profile.id),
        status: status(spec),
        module: module,
        metadata: %{
          auth_profile: profile.id,
          owner: profile.owner,
          subject: profile.subject,
          scopes: profile.scopes,
          default_scopes: profile.default_scopes,
          default?: profile.default?
        }
      })
    end)
  end

  defp action_capabilities(%{actions: []}, _module), do: []

  defp action_capabilities(spec, module) do
    [
      new!(%{
        id: "#{spec.id}.actions",
        provider: spec.id,
        kind: :actions,
        feature: :generated_jido_actions,
        label: "Generated Jido actions",
        status: status(spec),
        module: module,
        metadata: %{
          count: length(spec.actions),
          action_ids: Enum.map(spec.actions, & &1.id),
          mutation_count: Enum.count(spec.actions, & &1.mutation?)
        }
      })
    ]
  end

  defp trigger_capabilities(%{triggers: []}, _module), do: []

  defp trigger_capabilities(spec, module) do
    spec.triggers
    |> Enum.group_by(& &1.kind)
    |> Enum.map(fn {kind, triggers} ->
      new!(%{
        id: "#{spec.id}.#{kind}",
        provider: spec.id,
        kind: kind,
        feature: trigger_feature(kind),
        label: trigger_label(kind),
        status: status(spec),
        module: module,
        metadata: %{
          count: length(triggers),
          trigger_ids: Enum.map(triggers, & &1.id)
        }
      })
    end)
  end

  defp declared_capabilities(spec, module) do
    Enum.map(spec.capabilities, fn %__MODULE__{} = capability ->
      %{
        capability
        | provider: spec.id,
          status: capability.status || status(spec),
          module: capability.module || module
      }
    end)
  end

  defp metadata_capabilities(spec, module) do
    spec.metadata
    |> Map.get(:capabilities, [])
    |> Enum.map(fn attrs ->
      attrs
      |> Map.new()
      |> Map.put_new(:provider, spec.id)
      |> Map.put_new(:status, status(spec))
      |> Map.put_new(:module, module)
      |> new!()
    end)
  end

  defp status(spec), do: spec.status || Map.get(spec.metadata, :status, :available)

  defp trigger_feature(:webhook), do: :webhook
  defp trigger_feature(:poll), do: :polling

  defp trigger_label(:webhook), do: "Webhook triggers"
  defp trigger_label(:poll), do: "Poll triggers"

  defp humanize(value) do
    value
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp module_name(nil), do: nil
  defp module_name(module), do: inspect(module)
end
