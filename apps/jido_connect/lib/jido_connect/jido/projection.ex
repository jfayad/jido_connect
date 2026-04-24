defmodule Jido.Connect.Jido.ActionProjection do
  @moduledoc "Compile-time projection for one generated `Jido.Action` module."

  @enforce_keys [
    :module,
    :integration_module,
    :integration_id,
    :action_id,
    :name,
    :description,
    :input_schema,
    :output_schema,
    :auth_profile,
    :scopes,
    :risk,
    :confirmation
  ]
  defstruct [
    :module,
    :integration_module,
    :integration_id,
    :action_id,
    :name,
    :description,
    :input_schema,
    :output_schema,
    :auth_profile,
    :scopes,
    :risk,
    :confirmation
  ]
end

defmodule Jido.Connect.Jido.SensorProjection do
  @moduledoc "Compile-time projection for one generated `Jido.Sensor` module."

  @enforce_keys [
    :module,
    :integration_module,
    :integration_id,
    :trigger_id,
    :name,
    :description,
    :kind,
    :config_schema,
    :signal_schema,
    :signal_type,
    :signal_source,
    :auth_profile,
    :scopes,
    :interval_ms
  ]
  defstruct [
    :module,
    :integration_module,
    :integration_id,
    :trigger_id,
    :name,
    :description,
    :kind,
    :config_schema,
    :signal_schema,
    :signal_type,
    :signal_source,
    :auth_profile,
    :scopes,
    :interval_ms
  ]
end

defmodule Jido.Connect.Jido.PluginProjection do
  @moduledoc "Compile-time projection for one generated `Jido.Plugin` module."

  @enforce_keys [
    :module,
    :integration_module,
    :integration_id,
    :name,
    :description,
    :actions,
    :sensors
  ]
  defstruct [
    :module,
    :integration_module,
    :integration_id,
    :name,
    :description,
    :actions,
    :sensors
  ]
end

defmodule Jido.Connect.Jido.ToolAvailability do
  @moduledoc "Host-facing generated tool availability."

  @enforce_keys [:tool, :state]
  defstruct [
    :tool,
    :state,
    :connection_id,
    :connection_selector,
    missing_scopes: []
  ]
end
