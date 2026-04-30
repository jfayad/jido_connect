defmodule Jido.Connect.Slack.Actions.Files do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
    action :search_files do
      id "slack.file.search"
      resource :file
      verb :search
      data_classification :workspace_content
      label "Search files"
      description "Search Slack files with query helpers and pagination."
      handler Jido.Connect.Slack.Handlers.Actions.SearchFiles
      effect :read

      access do
        auth :user
        policies [:workspace_access]
        scopes ["search:read"]
      end

      input do
        field :query, :string, required?: true

        field :in, :string,
          description:
            "Optional Slack search in: qualifier value, such as #general, group_name, or <@U012AB3CD>."

        field :from, :string,
          description:
            "Optional Slack search from: qualifier value, such as <@U012AB3CD> or botname."

        field :before, :string, description: "Optional Slack search before: date qualifier."
        field :after, :string, description: "Optional Slack search after: date qualifier."
        field :on, :string, description: "Optional Slack search on: date qualifier."
        field :has, :string, description: "Optional Slack search has: qualifier value."
        field :sort, :string, enum: ["score", "timestamp"], default: "score"
        field :sort_dir, :string, enum: ["asc", "desc"], default: "desc"
        field :count, :integer, default: 20
        field :page, :integer, default: 1
        field :cursor, :string
        field :highlight, :boolean, default: false
        field :team_id, :string
      end

      output do
        field :query, :string
        field :files, {:array, :map}
        field :total_count, :integer
        field :pagination, :map
        field :paging, :map
        field :next_cursor, :string
      end
    end

    action :upload_file do
      id "slack.file.upload"
      resource :file
      verb :upload
      data_classification :workspace_content
      label "Upload file"

      description """
      Upload a file to Slack using the external upload flow and share it in a
      channel or conversation.
      """

      handler Jido.Connect.Slack.Handlers.Actions.UploadFile
      effect :write, confirmation: :required_for_ai

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["files:write"]
      end

      input do
        field :channel_id, :string, required?: true, example: "C012AB3CD"
        field :filename, :string, required?: true, example: "report.txt"
        field :content, :string, required?: true
        field :title, :string
        field :initial_comment, :string
        field :thread_ts, :string, description: "Slack parent message timestamp."
        field :alt_txt, :string
        field :snippet_type, :string
      end

      output do
        field :file_id, :string
        field :files, {:array, :map}
      end
    end

    action :share_file do
      id "slack.file.share"
      resource :file
      verb :share
      data_classification :workspace_content
      label "Share file"

      description """
      Share an existing Slack file to one or more channels with an optional
      title and introductory comment.
      """

      handler Jido.Connect.Slack.Handlers.Actions.ShareFile
      effect :write, confirmation: :required_for_ai

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["files:write"]
      end

      input do
        field :file_id, :string, required?: true, example: "F012AB3CDE4"
        field :channels, :string, required?: true, example: "C012AB3CD,C987ZYXWV"
        field :title, :string
        field :initial_comment, :string
        field :thread_ts, :string, description: "Slack parent message timestamp."
      end

      output do
        field :file_id, :string
        field :files, {:array, :map}
      end
    end

    action :delete_file do
      id "slack.file.delete"
      resource :file
      verb :delete
      data_classification :workspace_content
      label "Delete file"

      description """
      Delete an existing Slack file by ID.
      """

      handler Jido.Connect.Slack.Handlers.Actions.DeleteFile
      effect :destructive, confirmation: :always

      access do
        auth :bot
        policies [:workspace_access]
        scopes ["files:write"]
      end

      input do
        field :file_id, :string, required?: true, example: "F012AB3CDE4"
      end

      output do
        field :file_id, :string
      end
    end
  end
end
