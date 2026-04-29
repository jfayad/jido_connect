defmodule Jido.Connect.Provider do
  @moduledoc """
  Read-only provider introspection contract for Jido Connect packages.

  Connector authors should not hand-maintain these callbacks. `use Jido.Connect`
  generates them from the Spark DSL so the compiled spec remains the only
  source of truth.
  """

  alias Jido.Connect.{Callback, Error, Spec}
  alias Jido.Connect.Catalog.{Builder, Manifest}

  @type generated_modules :: %{
          actions: [module()],
          sensors: [module()],
          plugin: module() | nil
        }

  @callback integration() :: Spec.t()
  @callback jido_connect_manifest() :: Jido.Connect.Catalog.Manifest.t()
  @callback jido_connect_modules() :: generated_modules()

  @optional_callbacks jido_connect_manifest: 0, jido_connect_modules: 0

  @spec spec(module() | Spec.t()) :: {:ok, Spec.t()} | {:error, Error.error()}
  def spec(%Spec{} = spec), do: {:ok, spec}

  def spec(module) when is_atom(module) do
    with {:module, ^module} <- Code.ensure_loaded(module),
         true <- function_exported?(module, :integration, 0),
         {:ok, %Spec{} = spec} <-
           Callback.run(fn -> module.integration() end,
             phase: :provider_integration,
             details: %{module: module}
           ) do
      {:ok, spec}
    else
      {:ok, other} ->
        {:error, Error.invalid_integration(module, other)}

      {:error, %_{} = error} ->
        {:error, error}

      {:error, _reason} ->
        {:error, Error.unknown_integration(module)}

      false ->
        {:error, Error.unknown_integration(module)}

      other ->
        {:error, Error.invalid_integration(module, other)}
    end
  end

  def spec(integration_ref), do: {:error, Error.unknown_integration(integration_ref)}

  @spec manifest(module()) :: {:ok, Jido.Connect.Catalog.Manifest.t()} | {:error, Error.error()}
  def manifest(module) when is_atom(module) do
    with {:module, ^module} <- Code.ensure_loaded(module),
         true <- function_exported?(module, :integration, 0) do
      if function_exported?(module, :jido_connect_manifest, 0) do
        with {:ok, %Manifest{} = manifest} <-
               Callback.run(fn -> module.jido_connect_manifest() end,
                 phase: :provider_manifest,
                 details: %{module: module}
               ) do
          {:ok, manifest}
        else
          {:ok, other} -> {:error, Error.invalid_provider_manifest(module, other)}
          {:error, %_{} = error} -> {:error, error}
        end
      else
        with {:ok, spec} <- spec(module) do
          {:ok, Builder.manifest_from_spec(spec, module, projection(module))}
        end
      end
    else
      {:error, _reason} -> {:error, Error.unknown_integration(module)}
      false -> {:error, Error.unknown_integration(module)}
      other -> {:error, Error.invalid_integration(module, other)}
    end
  end

  def manifest(integration_ref), do: {:error, Error.unknown_integration(integration_ref)}

  @spec generated_modules(module()) :: {:ok, generated_modules()} | {:error, Error.error()}
  def generated_modules(module) when is_atom(module) do
    with {:module, ^module} <- Code.ensure_loaded(module) do
      cond do
        function_exported?(module, :jido_connect_modules, 0) ->
          with {:ok, modules} <-
                 Callback.run(fn -> module.jido_connect_modules() end,
                   phase: :provider_modules,
                   details: %{module: module}
                 ) do
            normalize_generated_modules(module, modules)
          end

        function_exported?(module, :jido_action_modules, 0) ->
          with {:ok, modules} <-
                 Callback.run(
                   fn ->
                     %{
                       actions: module.jido_action_modules(),
                       sensors: legacy_sensor_modules(module),
                       plugin: legacy_plugin_module(module)
                     }
                   end,
                   phase: :provider_modules,
                   details: %{module: module}
                 ) do
            normalize_generated_modules(module, modules)
          end

        true ->
          {:ok, %{actions: [], sensors: [], plugin: nil}}
      end
    else
      {:error, _reason} -> {:error, Error.unknown_integration(module)}
    end
  end

  def generated_modules(integration_ref), do: {:error, Error.unknown_integration(integration_ref)}

  defp normalize_generated_modules(module, %{actions: actions, sensors: sensors, plugin: plugin})
       when is_list(actions) and is_list(sensors) and (is_atom(plugin) or is_nil(plugin)) do
    if Enum.all?(actions ++ sensors, &is_atom/1) do
      {:ok, %{actions: actions, sensors: sensors, plugin: plugin}}
    else
      {:error,
       Error.invalid_provider_modules(module, %{
         actions: actions,
         sensors: sensors,
         plugin: plugin
       })}
    end
  end

  defp normalize_generated_modules(module, other) do
    {:error, Error.invalid_provider_modules(module, other)}
  end

  defp projection(module) do
    if function_exported?(module, :jido_projection, 0) do
      module.jido_projection()
    end
  end

  defp legacy_sensor_modules(module) do
    if function_exported?(module, :jido_sensor_modules, 0) do
      module.jido_sensor_modules()
    else
      []
    end
  end

  defp legacy_plugin_module(module) do
    if function_exported?(module, :jido_plugin_module, 0) do
      module.jido_plugin_module()
    end
  end
end
