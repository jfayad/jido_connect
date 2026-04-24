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

  @action_schema [
    name: [type: :atom, required: true],
    id: [type: :string],
    label: [type: :string],
    description: [type: :string],
    auth: [type: :atom],
    scopes: [type: {:list, :string}, default: []],
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
    entities: [input: [@input], output: [@output]],
    singleton_entity_keys: [:input, :output]
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
    scopes: [type: {:list, :string}, default: []],
    default_scopes: [type: {:list, :string}, default: []],
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
    fields: [type: {:list, :atom}, default: []],
    scopes: [type: {:list, :string}, default: []],
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

  @poll_schema [
    name: [type: :atom, required: true],
    id: [type: :string],
    label: [type: :string],
    description: [type: :string],
    auth: [type: :atom],
    scopes: [type: {:list, :string}, default: []],
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
    entities: [config: [@config], signal: [@signal]],
    singleton_entity_keys: [:config, :signal]
  }

  @integration %Spark.Dsl.Section{
    name: :integration,
    schema: [
      id: [type: :atom, required: true],
      name: [type: :string, required: true],
      category: [type: :atom],
      docs: [type: {:list, :string}, default: []],
      metadata: [type: :map, default: %{}]
    ]
  }

  @auth %Spark.Dsl.Section{
    name: :auth,
    entities: [@oauth2, @api_key]
  }

  @actions %Spark.Dsl.Section{
    name: :actions,
    entities: [@action]
  }

  @triggers %Spark.Dsl.Section{
    name: :triggers,
    entities: [@poll]
  }

  use Spark.Dsl.Extension,
    sections: [@integration, @auth, @actions, @triggers],
    transformers: [Jido.Connect.Dsl.Transformers.BuildSpec]
end
