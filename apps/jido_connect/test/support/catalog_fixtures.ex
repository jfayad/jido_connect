defmodule Jido.Connect.CatalogFixtures do
  alias Jido.Connect

  defmodule Integration do
    def integration do
      field = Connect.Field.new!(%{name: :id, type: :string, required?: true})

      auth =
        Connect.AuthProfile.new!(%{
          id: :user,
          kind: :oauth2,
          owner: :app_user,
          subject: :user,
          label: "User OAuth",
          scopes: ["read"],
          default_scopes: ["read"],
          default?: true
        })

      action =
        Connect.ActionSpec.new!(%{
          id: "catalog.item.get",
          name: :get_item,
          label: "Get item",
          resource: :item,
          verb: :get,
          data_classification: :workspace_metadata,
          auth_profile: :user,
          policies: [:item_access],
          handler: __MODULE__,
          input: [field],
          output: [field],
          input_schema: Zoi.object(%{id: Zoi.string()}),
          output_schema: Zoi.object(%{id: Zoi.string()}),
          scopes: ["read"]
        })

      trigger =
        Connect.TriggerSpec.new!(%{
          id: "catalog.item.created",
          name: :item_created,
          kind: :poll,
          label: "Item created",
          resource: :item,
          verb: :watch,
          data_classification: :workspace_metadata,
          auth_profile: :user,
          policies: [:item_access],
          handler: __MODULE__,
          config: [field],
          signal: [field],
          config_schema: Zoi.object(%{id: Zoi.string()}),
          signal_schema: Zoi.object(%{id: Zoi.string()}),
          scopes: ["read"],
          interval_ms: 1_000,
          checkpoint: :updated_at,
          dedupe: %{field: :id}
        })

      Connect.Spec.new!(%{
        id: :catalog,
        name: "Catalog",
        category: :test,
        package: :jido_connect_catalog,
        tags: [:catalog_test],
        docs: ["https://example.test/docs"],
        metadata: %{package: :jido_connect_catalog},
        policies: [
          Connect.PolicyRequirement.new!(%{
            id: :item_access,
            label: "Item access",
            decision: :allow_operation
          })
        ],
        auth_profiles: [auth],
        actions: [action],
        triggers: [trigger]
      })
    end
  end

  defmodule RaisingIntegration do
    def integration, do: raise("catalog exploded")
  end

  defmodule InvalidIntegration do
    def integration, do: %{id: :not_a_spec}
  end
end
