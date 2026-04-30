defmodule Jido.Connect.Slack.Actions.Files do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
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
  end
end
