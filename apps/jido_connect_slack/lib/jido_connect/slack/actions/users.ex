defmodule Jido.Connect.Slack.Actions.Users do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
    action :list_users do
      id "slack.user.list"
      resource :user
      verb :list
      data_classification :identity
      label "List users"
      description "List Slack workspace users visible to the installed app."
      handler Jido.Connect.Slack.Handlers.Actions.ListUsers
      effect :read

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["users:read"]
      end

      input do
        field :limit, :integer, default: 100
        field :cursor, :string
        field :team_id, :string
        field :include_locale, :boolean, default: false
      end

      output do
        field :users, {:array, :map}
        field :next_cursor, :string
      end
    end
  end
end
