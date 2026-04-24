defmodule Jido.Connect.Dsl.AuthProfile do
  @moduledoc false

  defstruct [
    :id,
    :__identifier__,
    :__spark_metadata__,
    :kind,
    :owner,
    :subject,
    :label,
    :authorize_url,
    :token_url,
    :callback_path,
    :token_field,
    :refresh_token_field,
    scopes: [],
    default_scopes: [],
    fields: [],
    pkce?: false,
    refresh?: false,
    revoke?: false,
    default?: false,
    metadata: %{}
  ]
end

defmodule Jido.Connect.Dsl.Action do
  @moduledoc false

  defstruct [
    :name,
    :__identifier__,
    :__spark_metadata__,
    :id,
    :label,
    :description,
    :auth,
    :handler,
    input: [],
    output: [],
    scopes: [],
    mutation?: false,
    risk: :read,
    confirmation: :none,
    metadata: %{}
  ]
end

defmodule Jido.Connect.Dsl.Trigger do
  @moduledoc false

  defstruct [
    :name,
    :__identifier__,
    :__spark_metadata__,
    :id,
    :kind,
    :label,
    :description,
    :auth,
    :handler,
    config: [],
    signal: [],
    scopes: [],
    verification: %{kind: :none},
    dedupe: nil,
    checkpoint: nil,
    interval_ms: nil,
    metadata: %{}
  ]
end

defmodule Jido.Connect.Dsl.Field do
  @moduledoc false

  def transform(%Jido.Connect.Field{} = field), do: {:ok, field}
end

defmodule Jido.Connect.Dsl.FieldGroup do
  @moduledoc false

  defstruct [:__spark_metadata__, fields: []]
end
