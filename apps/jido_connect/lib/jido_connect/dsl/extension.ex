defmodule Jido.Connect.Dsl.Extension do
  @moduledoc false

  alias Jido.Connect.Dsl

  @field_schema [
    name: [type: :atom, required: true],
    type: [type: :any, required: true],
    required?: [type: :boolean, default: false],
    default: [type: :any],
    enum: [type: {:list, :any}],
    example: [type: :any],
    description: [type: :string],
    metadata: [type: :map, default: %{}]
  ]

  @field %Spark.Dsl.Entity{
    name: :field,
    target: Jido.Connect.Field,
    args: [:name, :type],
    schema: @field_schema,
    transform: {Dsl.Field, :transform, []}
  }

  @input %Spark.Dsl.Entity{
    name: :input,
    target: Dsl.FieldGroup,
    entities: [fields: [@field]],
    schema: []
  }

  @output %Spark.Dsl.Entity{
    name: :output,
    target: Dsl.FieldGroup,
    entities: [fields: [@field]],
    schema: []
  }

  @config %Spark.Dsl.Entity{
    name: :config,
    target: Dsl.FieldGroup,
    entities: [fields: [@field]],
    schema: []
  }

  @signal %Spark.Dsl.Entity{
    name: :signal,
    target: Dsl.FieldGroup,
    entities: [fields: [@field]],
    schema: []
  }

  @named_schema %Spark.Dsl.Entity{
    name: :schema,
    target: Dsl.NamedSchema,
    args: [:name],
    identifier: :name,
    entities: [fields: [@field]],
    schema: [
      name: [type: :atom, required: true],
      label: [type: :string],
      description: [type: :string],
      metadata: [type: :map, default: %{}]
    ]
  }

  @capability_schema [
    name: [type: :atom, required: true],
    id: [type: :string],
    kind: [type: :atom, required: true],
    feature: [type: :atom],
    label: [type: :string],
    description: [type: :string],
    status: [type: :atom, default: :available],
    metadata: [type: :map, default: %{}]
  ]

  @capability %Spark.Dsl.Entity{
    name: :capability,
    target: Dsl.Capability,
    args: [:name],
    identifier: :name,
    schema: @capability_schema
  }

  @policy_schema [
    name: [type: :atom, required: true],
    id: [type: :atom],
    label: [type: :string],
    description: [type: :string],
    subject: [type: :any],
    owner: [type: :any],
    decision: [type: :atom, default: :allow_operation],
    metadata: [type: :map, default: %{}]
  ]

  @policy %Spark.Dsl.Entity{
    name: :policy,
    target: Dsl.PolicyRequirement,
    args: [:name],
    identifier: :name,
    schema: @policy_schema
  }

  @auth_profiles %Spark.Dsl.Entity{
    name: :auth_profiles,
    target: Dsl.AuthProfiles,
    args: [:profiles],
    schema: [
      profiles: [type: {:list, :atom}, required: true],
      default: [type: :atom]
    ]
  }

  @access_auth %Spark.Dsl.Entity{
    name: :auth,
    target: Dsl.AuthProfiles,
    args: [:profiles],
    schema: [
      profiles: [type: :any, required: true],
      default: [type: :atom]
    ]
  }

  @access_scopes %Spark.Dsl.Entity{
    name: :scopes,
    target: Dsl.ScopeRequirements,
    args: [:scopes],
    schema: [
      scopes: [type: {:list, :string}, required: true],
      resolver: [type: :module]
    ]
  }

  @access %Spark.Dsl.Entity{
    name: :access,
    target: Dsl.Access,
    entities: [
      auth: [@access_auth],
      scopes: [@access_scopes]
    ],
    schema: [
      policies: [type: {:list, :atom}, default: []]
    ],
    singleton_entity_keys: [:auth, :scopes]
  }

  @effect %Spark.Dsl.Entity{
    name: :effect,
    target: Dsl.Effect,
    args: [:risk],
    schema: [
      risk: [type: :atom, required: true],
      mutation?: [type: :boolean],
      confirmation: [type: :atom]
    ]
  }

  @requirements %Spark.Dsl.Entity{
    name: :requirements,
    target: Dsl.Requirements,
    schema: [
      scopes: [type: {:list, :string}, default: []],
      dynamic_scopes: [type: :module]
    ]
  }

  @action_schema [
    name: [type: :atom, required: true],
    id: [type: :string],
    label: [type: :string],
    description: [type: :string],
    resource: [type: :atom],
    verb: [type: :atom],
    data_classification: [type: :atom],
    policies: [type: {:list, :atom}, default: []],
    input_schema: [type: :atom],
    output_schema: [type: :atom],
    mutation?: [type: :boolean, default: false],
    risk: [type: :atom, default: :read],
    confirmation: [type: :atom, default: :none],
    handler: [type: :module, required: true],
    metadata: [type: :map, default: %{}]
  ]

  @action %Spark.Dsl.Entity{
    name: :action,
    target: Dsl.Action,
    args: [:name],
    identifier: :name,
    schema: @action_schema,
    entities: [
      access: [@access],
      effect: [@effect],
      auth_profiles: [@auth_profiles],
      requirements: [@requirements],
      input: [@input],
      output: [@output]
    ],
    singleton_entity_keys: [:access, :effect, :auth_profiles, :requirements, :input, :output]
  }

  @oauth2_schema [
    id: [type: :atom, required: true],
    default?: [type: :boolean, default: false],
    owner: [type: :atom, required: true],
    subject: [type: :atom, required: true],
    label: [type: :string],
    authorize_url: [type: :string, required: true],
    token_url: [type: :string, required: true],
    callback_path: [type: :string],
    token_field: [type: :atom],
    refresh_token_field: [type: :atom],
    setup: [type: :atom],
    credential_fields: [type: {:list, :atom}, default: []],
    lease_fields: [type: {:list, :atom}, default: []],
    scopes: [type: {:list, :string}, default: []],
    default_scopes: [type: {:list, :string}, default: []],
    optional_scopes: [type: {:list, :string}, default: []],
    pkce?: [type: :boolean, default: false],
    refresh?: [type: :boolean, default: false],
    revoke?: [type: :boolean, default: false],
    metadata: [type: :map, default: %{}]
  ]

  @oauth2 %Spark.Dsl.Entity{
    name: :oauth2,
    target: Dsl.AuthProfile,
    args: [:id],
    identifier: :id,
    auto_set_fields: [kind: :oauth2],
    schema: @oauth2_schema
  }

  @api_key_schema [
    id: [type: :atom, required: true],
    label: [type: :string],
    owner: [type: :atom, required: true],
    subject: [type: :atom, required: true],
    credential_fields: [type: {:list, :atom}, default: []],
    lease_fields: [type: {:list, :atom}, default: []],
    setup: [type: :atom],
    scopes: [type: {:list, :string}, default: []],
    default_scopes: [type: {:list, :string}, default: []],
    optional_scopes: [type: {:list, :string}, default: []],
    default?: [type: :boolean, default: false],
    metadata: [type: :map, default: %{}]
  ]

  @api_key %Spark.Dsl.Entity{
    name: :api_key,
    target: Dsl.AuthProfile,
    args: [:id],
    identifier: :id,
    auto_set_fields: [kind: :api_key],
    schema: @api_key_schema
  }

  @app_installation_schema [
    id: [type: :atom, required: true],
    label: [type: :string],
    owner: [type: :atom, required: true],
    subject: [type: :atom, required: true],
    credential_fields: [type: {:list, :atom}, default: []],
    lease_fields: [type: {:list, :atom}, default: []],
    setup: [type: :atom],
    scopes: [type: {:list, :string}, default: []],
    default_scopes: [type: {:list, :string}, default: []],
    optional_scopes: [type: {:list, :string}, default: []],
    default?: [type: :boolean, default: false],
    metadata: [type: :map, default: %{}]
  ]

  @app_installation %Spark.Dsl.Entity{
    name: :app_installation,
    target: Dsl.AuthProfile,
    args: [:id],
    identifier: :id,
    auto_set_fields: [kind: :app_installation],
    schema: @app_installation_schema
  }

  @poll_schema [
    name: [type: :atom, required: true],
    id: [type: :string],
    label: [type: :string],
    description: [type: :string],
    resource: [type: :atom],
    verb: [type: :atom],
    data_classification: [type: :atom],
    policies: [type: {:list, :atom}, default: []],
    config_schema: [type: :atom],
    signal_schema: [type: :atom],
    interval_ms: [type: :pos_integer],
    checkpoint: [type: :atom],
    dedupe: [type: :map],
    handler: [type: :module, required: true],
    metadata: [type: :map, default: %{}]
  ]

  @poll %Spark.Dsl.Entity{
    name: :poll,
    target: Dsl.Trigger,
    args: [:name],
    identifier: :name,
    auto_set_fields: [kind: :poll],
    schema: @poll_schema,
    entities: [
      access: [@access],
      auth_profiles: [@auth_profiles],
      requirements: [@requirements],
      config: [@config],
      signal: [@signal]
    ],
    singleton_entity_keys: [:access, :auth_profiles, :requirements, :config, :signal]
  }

  @webhook_schema [
    name: [type: :atom, required: true],
    id: [type: :string],
    label: [type: :string],
    description: [type: :string],
    resource: [type: :atom],
    verb: [type: :atom],
    data_classification: [type: :atom],
    policies: [type: {:list, :atom}, default: []],
    config_schema: [type: :atom],
    signal_schema: [type: :atom],
    verification: [type: :map, required: true],
    handler: [type: :module, required: true],
    metadata: [type: :map, default: %{}]
  ]

  @webhook %Spark.Dsl.Entity{
    name: :webhook,
    target: Dsl.Trigger,
    args: [:name],
    identifier: :name,
    auto_set_fields: [kind: :webhook],
    schema: @webhook_schema,
    entities: [
      access: [@access],
      auth_profiles: [@auth_profiles],
      requirements: [@requirements],
      config: [@config],
      signal: [@signal]
    ],
    singleton_entity_keys: [:access, :auth_profiles, :requirements, :config, :signal]
  }

  @integration %Spark.Dsl.Section{
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

  @catalog %Spark.Dsl.Section{
    name: :catalog,
    entities: [@capability],
    schema: [
      package: [type: :atom],
      status: [type: :atom, default: :available],
      tags: [type: {:list, :atom}, default: []],
      visibility: [type: :atom, default: :public],
      description: [type: :string],
      metadata: [type: :map, default: %{}]
    ]
  }

  @schemas %Spark.Dsl.Section{
    name: :schemas,
    entities: [@named_schema]
  }

  @auth %Spark.Dsl.Section{
    name: :auth,
    entities: [@oauth2, @api_key, @app_installation]
  }

  @policies %Spark.Dsl.Section{
    name: :policies,
    entities: [@policy]
  }

  @actions %Spark.Dsl.Section{
    name: :actions,
    entities: [@action]
  }

  @triggers %Spark.Dsl.Section{
    name: :triggers,
    entities: [@poll, @webhook]
  }

  use Spark.Dsl.Extension,
    sections: [@integration, @catalog, @schemas, @auth, @policies, @actions, @triggers],
    verifiers: [Jido.Connect.Dsl.Verifiers.ValidateOperations],
    transformers: [Jido.Connect.Dsl.Transformers.BuildSpec]
end
