defmodule Jido.Connect.Catalog do
  @moduledoc """
  Host-facing connector catalog metadata derived from integration specs.

  This gives demo apps and host UIs a stable, storage-free way to render
  available providers, auth modes, generated tools, and maturity metadata.
  """

  alias Jido.Connect.{ActionSpec, AuthProfile, ConnectorCapability, TriggerSpec}

  defmodule AuthProfileSummary do
    @moduledoc "Catalog-facing auth profile metadata."

    @schema Zoi.struct(
              __MODULE__,
              %{
                id: Zoi.atom(),
                kind: Zoi.atom(),
                label: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
                owner: Zoi.atom(),
                subject: Zoi.atom(),
                default?: Zoi.boolean() |> Zoi.default(false),
                scopes: Zoi.list(Zoi.string()) |> Zoi.default([]),
                default_scopes: Zoi.list(Zoi.string()) |> Zoi.default([])
              },
              coerce: true
            )

    @type t :: unquote(Zoi.type_spec(@schema))
    @enforce_keys Zoi.Struct.enforce_keys(@schema)
    defstruct Zoi.Struct.struct_fields(@schema)

    def schema, do: @schema
    def new!(attrs), do: Zoi.parse!(@schema, attrs)
    def new(attrs), do: Zoi.parse(@schema, attrs)
  end

  defmodule Tool do
    @moduledoc "Catalog-facing action or trigger metadata."

    @schema Zoi.struct(
              __MODULE__,
              %{
                type: Zoi.enum([:action, :trigger]),
                id: Zoi.string(),
                name: Zoi.atom(),
                label: Zoi.string(),
                description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
                module: Zoi.module() |> Zoi.nullish() |> Zoi.optional(),
                auth_profile: Zoi.atom(),
                auth_profiles: Zoi.list(Zoi.atom()) |> Zoi.default([]),
                scopes: Zoi.list(Zoi.string()) |> Zoi.default([]),
                risk: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
                confirmation: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
                trigger_kind: Zoi.atom() |> Zoi.nullish() |> Zoi.optional()
              },
              coerce: true
            )

    @type t :: unquote(Zoi.type_spec(@schema))
    @enforce_keys Zoi.Struct.enforce_keys(@schema)
    defstruct Zoi.Struct.struct_fields(@schema)

    def schema, do: @schema
    def new!(attrs), do: Zoi.parse!(@schema, attrs)
    def new(attrs), do: Zoi.parse(@schema, attrs)
  end

  defmodule Entry do
    @moduledoc "Catalog-facing integration metadata."

    @schema Zoi.struct(
              __MODULE__,
              %{
                id: Zoi.atom(),
                name: Zoi.string(),
                category: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
                package: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
                module: Zoi.module(),
                status: Zoi.atom() |> Zoi.default(:available),
                docs: Zoi.list(Zoi.string()) |> Zoi.default([]),
                capabilities: Zoi.list(ConnectorCapability.schema()) |> Zoi.default([]),
                auth_profiles: Zoi.list(AuthProfileSummary.schema()) |> Zoi.default([]),
                actions: Zoi.list(Tool.schema()) |> Zoi.default([]),
                triggers: Zoi.list(Tool.schema()) |> Zoi.default([]),
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
  end

  @spec entry(module(), keyword()) :: Entry.t()
  def entry(integration_module, opts \\ []) when is_atom(integration_module) do
    spec = integration_module.integration()
    projection = projection(integration_module)

    Entry.new!(%{
      id: spec.id,
      name: spec.name,
      category: spec.category,
      package: Map.get(spec.metadata, :package),
      module: integration_module,
      status: Keyword.get(opts, :status, Map.get(spec.metadata, :status, :available)),
      docs: spec.docs,
      capabilities: ConnectorCapability.from_spec(spec, integration_module),
      auth_profiles: Enum.map(spec.auth_profiles, &auth_summary/1),
      actions: Enum.map(spec.actions, &action_tool(&1, projection)),
      triggers: Enum.map(spec.triggers, &trigger_tool(&1, projection)),
      metadata: spec.metadata
    })
  end

  @spec entries([module()], keyword()) :: [Entry.t()]
  def entries(integration_modules, opts \\ []) when is_list(integration_modules) do
    Enum.map(integration_modules, &entry(&1, opts))
  end

  @spec configured_modules() :: [module()]
  def configured_modules do
    :jido_connect
    |> Application.get_env(:catalog_modules, [])
    |> normalize_modules()
  end

  @spec discover(keyword()) :: [Entry.t()]
  def discover(opts \\ []) do
    modules =
      opts
      |> Keyword.get(:modules, configured_modules())
      |> normalize_modules()

    modules
    |> Enum.flat_map(&safe_entry/1)
    |> filter(opts)
    |> search(Keyword.get(opts, :query, Keyword.get(opts, :q)))
  end

  @spec search([Entry.t()], String.t() | nil) :: [Entry.t()]
  def search(entries, query) when query in [nil, ""], do: entries

  def search(entries, query) when is_binary(query) do
    normalized_query = String.downcase(query)

    Enum.filter(entries, fn entry ->
      entry
      |> searchable_text()
      |> String.contains?(normalized_query)
    end)
  end

  @spec filter([Entry.t()], keyword()) :: [Entry.t()]
  def filter(entries, opts) do
    entries
    |> filter_equal(:status, Keyword.get(opts, :status))
    |> filter_equal(:category, Keyword.get(opts, :category))
    |> filter_auth_kind(Keyword.get(opts, :auth_kind))
    |> filter_tool(Keyword.get(opts, :tool))
  end

  @spec to_map(Entry.t()) :: map()
  def to_map(%Entry{} = entry) do
    %{
      id: entry.id,
      name: entry.name,
      category: entry.category,
      package: entry.package,
      module: inspect(entry.module),
      status: entry.status,
      docs: entry.docs,
      capabilities: Enum.map(entry.capabilities, &ConnectorCapability.to_map/1),
      auth_profiles: Enum.map(entry.auth_profiles, &auth_profile_to_map/1),
      actions: Enum.map(entry.actions, &tool_to_map/1),
      triggers: Enum.map(entry.triggers, &tool_to_map/1),
      metadata: entry.metadata
    }
  end

  defp auth_summary(%AuthProfile{} = auth_profile) do
    AuthProfileSummary.new!(%{
      id: auth_profile.id,
      kind: auth_profile.kind,
      label: auth_profile.label,
      owner: auth_profile.owner,
      subject: auth_profile.subject,
      default?: auth_profile.default?,
      scopes: auth_profile.scopes,
      default_scopes: auth_profile.default_scopes
    })
  end

  defp action_tool(%ActionSpec{} = action, projection) do
    Tool.new!(%{
      type: :action,
      id: action.id,
      name: action.name,
      label: action.label,
      description: action.description,
      module: projection_module(projection, :actions, action.id),
      auth_profile: action.auth_profile,
      auth_profiles: action.auth_profiles,
      scopes: action.scopes,
      risk: action.risk,
      confirmation: action.confirmation
    })
  end

  defp trigger_tool(%TriggerSpec{} = trigger, projection) do
    Tool.new!(%{
      type: :trigger,
      id: trigger.id,
      name: trigger.name,
      label: trigger.label,
      description: trigger.description,
      module: projection_module(projection, :sensors, trigger.id),
      auth_profile: trigger.auth_profile,
      auth_profiles: trigger.auth_profiles,
      scopes: trigger.scopes,
      trigger_kind: trigger.kind
    })
  end

  defp projection(integration_module) do
    if function_exported?(integration_module, :jido_projection, 0) do
      integration_module.jido_projection()
    end
  end

  defp projection_module(nil, _key, _id), do: nil

  defp projection_module(projection, :actions, id) do
    projection.actions
    |> Enum.find(&(&1.action_id == id))
    |> case do
      nil -> nil
      action -> action.module
    end
  end

  defp projection_module(projection, :sensors, id) do
    projection.sensors
    |> Enum.find(&(&1.trigger_id == id))
    |> case do
      nil -> nil
      sensor -> sensor.module
    end
  end

  defp normalize_modules(modules) do
    modules
    |> List.wrap()
    |> Enum.map(&normalize_module/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp normalize_module(module) when is_atom(module), do: module

  defp normalize_module("Elixir." <> _rest = module) do
    module
    |> String.replace_prefix("Elixir.", "")
    |> normalize_module()
  end

  defp normalize_module(module) when is_binary(module) do
    module
    |> String.split(".", trim: true)
    |> Module.concat()
  rescue
    _error -> nil
  end

  defp safe_entry(module) do
    with {:module, ^module} <- Code.ensure_loaded(module),
         true <- function_exported?(module, :integration, 0) do
      [entry(module)]
    else
      _other -> []
    end
  end

  defp filter_equal(entries, _field, value) when value in [nil, ""], do: entries

  defp filter_equal(entries, field, value) do
    value = normalize_filter_value(value)
    Enum.filter(entries, &(Map.fetch!(&1, field) == value))
  end

  defp filter_auth_kind(entries, kind) when kind in [nil, ""], do: entries

  defp filter_auth_kind(entries, kind) do
    kind = normalize_filter_value(kind)

    Enum.filter(entries, fn entry ->
      Enum.any?(entry.auth_profiles, &(&1.kind == kind))
    end)
  end

  defp filter_tool(entries, tool) when tool in [nil, ""], do: entries

  defp filter_tool(entries, tool) do
    tool = to_string(tool)

    Enum.filter(entries, fn entry ->
      Enum.any?(entry.actions, &(&1.id == tool)) or Enum.any?(entry.triggers, &(&1.id == tool))
    end)
  end

  defp normalize_filter_value(value) when is_atom(value), do: value

  defp normalize_filter_value(value) when is_binary(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> {:unknown, value}
  end

  defp searchable_text(%Entry{} = entry) do
    [
      entry.id,
      entry.name,
      entry.category,
      entry.package,
      entry.status,
      inspect(entry.module),
      Enum.map(entry.docs, & &1),
      Enum.map(entry.capabilities, &[&1.kind, &1.feature, &1.label]),
      Enum.map(entry.auth_profiles, &[&1.id, &1.kind, &1.label, &1.scopes, &1.default_scopes]),
      Enum.map(entry.actions, &tool_search_text/1),
      Enum.map(entry.triggers, &tool_search_text/1)
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.map_join(" ", &to_string/1)
    |> String.downcase()
  end

  defp tool_search_text(%Tool{} = tool) do
    [
      tool.type,
      tool.id,
      tool.name,
      tool.label,
      tool.description,
      inspect(tool.module),
      tool.auth_profile,
      tool.auth_profiles,
      tool.scopes,
      tool.risk,
      tool.confirmation,
      tool.trigger_kind
    ]
  end

  defp auth_profile_to_map(%AuthProfileSummary{} = auth_profile) do
    %{
      id: auth_profile.id,
      kind: auth_profile.kind,
      label: auth_profile.label,
      owner: auth_profile.owner,
      subject: auth_profile.subject,
      default?: auth_profile.default?,
      scopes: auth_profile.scopes,
      default_scopes: auth_profile.default_scopes
    }
  end

  defp tool_to_map(%Tool{} = tool) do
    %{
      type: tool.type,
      id: tool.id,
      name: tool.name,
      label: tool.label,
      description: tool.description,
      module: module_name(tool.module),
      auth_profile: tool.auth_profile,
      auth_profiles: tool.auth_profiles,
      scopes: tool.scopes,
      risk: tool.risk,
      confirmation: tool.confirmation,
      trigger_kind: tool.trigger_kind
    }
  end

  defp module_name(nil), do: nil
  defp module_name(module), do: inspect(module)
end
