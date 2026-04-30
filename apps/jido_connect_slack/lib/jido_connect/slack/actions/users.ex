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

    action :user_info do
      id "slack.user.info"
      resource :user
      verb :read
      data_classification :identity
      label "Get user info"
      description "Return normalized Slack user or bot identity and profile details."
      handler Jido.Connect.Slack.Handlers.Actions.UserInfo
      effect :read

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["users:read"]
      end

      input do
        field :user, :string
        field :include_locale, :boolean, default: false
      end

      output do
        field :user_id, :string
        field :team_id, :string
        field :name, :string
        field :real_name, :string
        field :tz, :string
        field :deleted, :boolean
        field :is_bot, :boolean
        field :is_app_user, :boolean
        field :user_type, :string
        field :bot_id, :string
        field :updated, :integer
        field :profile, :map
        field :user, :map
      end
    end

    action :lookup_user_by_email do
      id "slack.user.lookup_by_email"
      resource :user
      verb :read
      data_classification :identity
      label "Lookup user by email"

      description "Return normalized Slack user identity and profile details for an email address."

      handler Jido.Connect.Slack.Handlers.Actions.LookupUserByEmail
      effect :read

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["users:read.email"]
      end

      input do
        field :email, :string
      end

      output do
        field :user_id, :string
        field :team_id, :string
        field :name, :string
        field :real_name, :string
        field :tz, :string
        field :deleted, :boolean
        field :is_bot, :boolean
        field :is_app_user, :boolean
        field :user_type, :string
        field :bot_id, :string
        field :updated, :integer
        field :profile, :map
        field :user, :map
      end
    end
  end
end
