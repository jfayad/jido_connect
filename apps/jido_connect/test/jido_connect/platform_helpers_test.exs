defmodule Jido.Connect.PlatformHelpersTest do
  use ExUnit.Case, async: false

  alias Jido.Connect
  alias Jido.Connect.{Catalog, Http, OAuth, Polling, ProviderResponse, Webhook, WebhookDelivery}
  alias Jido.Connect.Dev.ProviderScaffold

  defmodule CatalogIntegration do
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

  test "OAuth helpers build URLs and require configured secrets" do
    url =
      OAuth.authorize_url("https://provider.test/oauth/authorize",
        client_id: "client",
        redirect_uri: "https://demo.test/callback",
        scope: "read write",
        empty: "",
        missing: nil
      )

    params = url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

    assert params == %{
             "client_id" => "client",
             "redirect_uri" => "https://demo.test/callback",
             "scope" => "read write"
           }

    System.put_env("JIDO_CONNECT_TEST_SECRET", "secret")

    on_exit(fn ->
      System.delete_env("JIDO_CONNECT_TEST_SECRET")
    end)

    assert OAuth.fetch_required!([], :client_secret, "JIDO_CONNECT_TEST_SECRET") == "secret"
    assert %Req.Request{} = OAuth.req(base_url: "https://provider.test/token")
  end

  test "HTTP helpers normalize provider response failures" do
    assert %Req.Request{} = Http.bearer_request("https://provider.test", "token")

    assert {:ok, %{"ok" => true}} =
             Http.handle_map_response({:ok, %{status: 200, body: %{"ok" => true}}},
               provider: :demo
             )

    assert {:error,
            %Connect.Error.ProviderError{
              provider: :demo,
              reason: :http_error,
              status: 429,
              details: %{message: "rate limited", response: %{status: 429, retryable?: true}}
            }} =
             Http.provider_error({:ok, %{status: 429, body: %{"message" => "rate limited"}}},
               provider: :demo,
               message: "Demo API request failed"
             )

    assert {:error, %Connect.Error.ProviderError{provider: :demo, reason: :request_error}} =
             Http.provider_error({:error, :timeout}, provider: :demo)

    response =
      ProviderResponse.from_result!(
        :demo,
        {:ok, %{status: 503, headers: [{"retry-after", "30"}], body: %{"api_key" => "secret"}}}
      )

    assert response.retry_after == 30
    assert ProviderResponse.retryable?(response)
    assert ProviderResponse.to_public_map(response).body["api_key"] == "[redacted]"
    refute inspect(response) =~ "secret"
  end

  test "webhook helpers verify HMACs and decode JSON" do
    body = ~s({"ok":true})
    signature = "sha256=" <> Connect.Security.hmac_sha256_hex("secret", body)

    assert :ok =
             Webhook.verify_hmac_sha256(body, signature, "secret",
               prefix: "sha256=",
               invalid_signature_reason: :bad_signature
             )

    assert {:error, %Connect.Error.AuthError{reason: :bad_signature}} =
             Webhook.verify_hmac_sha256(body, "sha256=bad", "secret",
               prefix: "sha256=",
               invalid_signature_reason: :bad_signature
             )

    assert {:error, %Connect.Error.AuthError{reason: :missing_secret}} =
             Webhook.verify_hmac_sha256(body, signature, nil)

    assert {:ok, %{"ok" => true}} = Webhook.decode_json(body, provider: :demo)

    assert {:error, %Connect.Error.ProviderError{reason: :invalid_payload}} =
             Webhook.decode_json("not-json", provider: :demo)

    assert Webhook.header(%{"x-demo-header" => "value"}, "X-Demo-Header") == "value"
    assert Webhook.duplicate?("delivery_1", ["delivery_1"])

    delivery =
      WebhookDelivery.verified!(:demo,
        delivery_id: "delivery_1",
        event: "demo.created",
        headers: %{"authorization" => "secret"},
        payload: %{"ok" => true},
        metadata: %{token: "secret"}
      )
      |> WebhookDelivery.mark_duplicate()
      |> WebhookDelivery.put_signal(%{id: "signal_1"})

    assert delivery.duplicate?
    assert WebhookDelivery.to_public_map(delivery).headers["authorization"] == "[redacted]"
    assert WebhookDelivery.to_public_map(delivery).metadata["token"] == "[redacted]"
    refute inspect(delivery) =~ "secret"
  end

  test "polling helpers manage checkpoint params" do
    assert Polling.put_checkpoint_param([state: "all"], :since, nil) == [state: "all"]

    assert Polling.put_checkpoint_param([state: "all"], :since, "cursor") == [
             since: "cursor",
             state: "all"
           ]

    assert Polling.latest_checkpoint(
             [%{updated_at: "2026-04-24T20:00:00Z"}, %{updated_at: "2026-04-24T21:00:00Z"}],
             :updated_at,
             nil
           ) == "2026-04-24T21:00:00Z"

    assert Polling.latest_checkpoint([], :updated_at, "fallback") == "fallback"
  end

  test "connection selectors model shared credential lookup intent" do
    assert {:ok,
            %Connect.ConnectionSelector{
              provider: :github,
              strategy: :per_actor,
              tenant_id: "tenant_1",
              actor_id: "user_1",
              owner_type: :user,
              owner_id: "user_1"
            } = per_actor} =
             Connect.ConnectionSelector.per_actor(:github, "tenant_1", "user_1", profile: :user)

    assert {:ok,
            %Connect.ConnectionSelector{
              strategy: :tenant_default,
              owner_type: :tenant,
              owner_id: "tenant_1"
            }} =
             Connect.ConnectionSelector.tenant_default(:slack, "tenant_1", profile: :bot)

    assert {:ok,
            %Connect.ConnectionSelector{
              strategy: :org_default,
              owner_type: :org,
              owner_id: "org_1"
            }} =
             Connect.ConnectionSelector.org_default(:github, "tenant_1", "org_1",
               profile: :installation
             )

    assert {:ok,
            %Connect.ConnectionSelector{
              strategy: :installation,
              owner_type: :installation,
              owner_id: "installation_1"
            }} =
             Connect.ConnectionSelector.installation(:github, "tenant_1", "installation_1",
               profile: :installation
             )

    assert {:ok, %Connect.ConnectionSelector{strategy: :system, owner_type: :system}} =
             Connect.ConnectionSelector.system(:stripe, profile: :api_key)

    assert {:ok, %Connect.ConnectionSelector{strategy: :explicit, connection_id: "conn_1"}} =
             Connect.ConnectionSelector.explicit(:github, "conn_1", profile: :user)

    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :github,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :user,
        owner_id: "user_1",
        status: :connected,
        scopes: ["repo"]
      })

    assert {:ok, ^connection} =
             Connect.ConnectionSelector.resolve(per_actor, fn ^per_actor -> connection end)

    assert Connect.ConnectionSelector.matches_connection?(per_actor, connection)
    assert Connect.ConnectionSelector.selector_mismatch(per_actor, connection) == nil
    assert Connect.ConnectionSelector.missing_scopes(per_actor, connection) == []

    assert {:ok, explicit_selector} = Connect.ConnectionSelector.from_connection(connection)
    assert explicit_selector.strategy == :explicit
    assert explicit_selector.connection_id == "conn_1"
    assert Connect.ConnectionSelector.matches_connection?(explicit_selector, connection)

    missing_scope_selector = %{per_actor | required_scopes: ["repo", "admin:org"]}

    assert Connect.ConnectionSelector.missing_scopes(missing_scope_selector, connection) == [
             "admin:org"
           ]

    assert Connect.ConnectionSelector.selector_mismatch(missing_scope_selector, connection) ==
             {:required_scopes, ["admin:org"], ["repo"]}

    assert Connect.ConnectionSelector.selector_mismatch(
             %{per_actor | owner_id: "other"},
             connection
           ) ==
             {:owner_id, "other", "user_1"}

    assert {:ok, ^per_actor} = Connect.ConnectionSelector.normalize(Map.from_struct(per_actor))
  end

  test "catalog entries derive host-facing metadata from specs" do
    entry = Catalog.entry(CatalogIntegration)

    assert %Catalog.Entry{
             id: :catalog,
             package: :jido_connect_catalog,
             tags: [:catalog_test],
             policies: [%{id: :item_access}]
           } = entry

    assert Enum.any?(entry.capabilities, &(&1.feature == :oauth2))
    assert Enum.any?(entry.capabilities, &(&1.feature == :generated_jido_actions))
    assert Enum.any?(entry.capabilities, &(&1.feature == :polling))
    assert [%Catalog.AuthProfileSummary{id: :user, kind: :oauth2}] = entry.auth_profiles

    assert [%Catalog.Tool{id: "catalog.item.get", type: :action, resource: :item, verb: :get}] =
             entry.actions

    assert [
             %Catalog.Tool{
               id: "catalog.item.created",
               type: :trigger,
               trigger_kind: :poll,
               resource: :item,
               verb: :watch
             }
           ] =
             entry.triggers

    assert [%Catalog.Entry{id: :catalog}] = Catalog.entries([CatalogIntegration])
  end

  test "catalog discovery searches and filters configured modules" do
    previous = Application.get_env(:jido_connect, :catalog_modules)
    Application.put_env(:jido_connect, :catalog_modules, [CatalogIntegration])

    on_exit(fn ->
      if is_nil(previous) do
        Application.delete_env(:jido_connect, :catalog_modules)
      else
        Application.put_env(:jido_connect, :catalog_modules, previous)
      end
    end)

    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover()
    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover(query: "item")
    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover(status: :available)
    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover(auth_kind: "oauth2")
    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover(auth_profile: "user")
    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover(scope: "read")
    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover(package: "jido_connect_catalog")
    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover(tag: "catalog_test")
    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover(capability_kind: "auth")
    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover(capability: "polling")
    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover(tool: "catalog.item.get")
    assert [] = Catalog.discover(query: "missing")
    assert [] = Catalog.discover(status: "unknown_status")

    assert %{
             id: :catalog,
             module: "Jido.Connect.PlatformHelpersTest.CatalogIntegration",
             capabilities: [%{provider: :catalog} | _],
             policies: [%{id: :item_access}],
             actions: [%{id: "catalog.item.get"}]
           } = Catalog.discover() |> hd() |> Catalog.to_map()

    assert [
             %Catalog.ToolEntry{
               provider: :catalog,
               type: :action,
               id: "catalog.item.get",
               auth_kinds: [:oauth2]
             },
             %Catalog.ToolEntry{
               provider: :catalog,
               type: :trigger,
               id: "catalog.item.created"
             }
           ] = Catalog.tools()

    assert [%Catalog.ToolEntry{id: "catalog.item.get"}] = Catalog.tools(type: :action)

    assert [%Catalog.ToolEntry{id: "catalog.item.get"}] =
             Catalog.tools(resource: :item, verb: :get)

    assert [%Catalog.ToolEntry{id: "catalog.item.created"}] = Catalog.tools(query: "created")
    assert [%Catalog.ToolEntry{id: "catalog.item.get"}] = Catalog.tools(tool: "catalog.item.get")

    assert [
             %Catalog.ToolEntry{id: "catalog.item.get"},
             %Catalog.ToolEntry{id: "catalog.item.created"}
           ] = Catalog.tools(auth_kind: :oauth2)

    assert %{
             provider: :catalog,
             integration_module: "Jido.Connect.PlatformHelpersTest.CatalogIntegration",
             id: "catalog.item.get",
             auth_kinds: [:oauth2],
             policies: [:item_access],
             resource: :item,
             verb: :get
           } = Catalog.tools(type: :action) |> hd() |> Catalog.to_map()
  end

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
