defmodule Jido.Connect.Google.Sheets.Actions.ManageSheets do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @write_scope "https://www.googleapis.com/auth/spreadsheets"
  @scope_resolver Jido.Connect.Google.Sheets.ScopeResolver

  actions do
    action :add_sheet do
      id "google.sheets.sheet.add"
      resource :sheet
      verb :create
      data_classification :workspace_metadata
      label "Add sheet"
      description "Add a sheet/tab to a Google spreadsheet."
      handler Jido.Connect.Google.Sheets.Handlers.Actions.AddSheet
      effect :write, confirmation: :required_for_ai

      access do
        auth :user
        scopes [@write_scope], resolver: @scope_resolver
      end

      input do
        field :spreadsheet_id, :string, required?: true, example: "1abc..."
        field :title, :string, required?: true, example: "Budget"
        field :index, :integer
        field :row_count, :integer
        field :column_count, :integer
      end

      output do
        field :sheet, :map
      end
    end

    action :delete_sheet do
      id "google.sheets.sheet.delete"
      resource :sheet
      verb :delete
      data_classification :workspace_metadata
      label "Delete sheet"
      description "Delete a sheet/tab from a Google spreadsheet."
      handler Jido.Connect.Google.Sheets.Handlers.Actions.DeleteSheet
      effect :destructive, confirmation: :always

      access do
        auth :user
        scopes [@write_scope], resolver: @scope_resolver
      end

      input do
        field :spreadsheet_id, :string, required?: true, example: "1abc..."
        field :sheet_id, :integer, required?: true
      end

      output do
        field :result, :map
      end
    end

    action :rename_sheet do
      id "google.sheets.sheet.rename"
      resource :sheet
      verb :update
      data_classification :workspace_metadata
      label "Rename sheet"
      description "Rename a sheet/tab in a Google spreadsheet."
      handler Jido.Connect.Google.Sheets.Handlers.Actions.RenameSheet
      effect :write, confirmation: :required_for_ai

      access do
        auth :user
        scopes [@write_scope], resolver: @scope_resolver
      end

      input do
        field :spreadsheet_id, :string, required?: true, example: "1abc..."
        field :sheet_id, :integer, required?: true
        field :title, :string, required?: true, example: "Renamed Budget"
      end

      output do
        field :sheet, :map
      end
    end

    action :batch_update do
      id "google.sheets.batch_update"
      resource :spreadsheet
      verb :update
      data_classification :workspace_content
      label "Batch update spreadsheet"
      description "Run a validated Google Sheets batchUpdate request."
      handler Jido.Connect.Google.Sheets.Handlers.Actions.BatchUpdate
      effect :destructive, confirmation: :always

      access do
        auth :user
        scopes [@write_scope], resolver: @scope_resolver
      end

      input do
        field :spreadsheet_id, :string, required?: true, example: "1abc..."
        field :requests, {:array, :map}, required?: true
        field :include_spreadsheet_in_response, :boolean, default: false
        field :response_ranges, {:array, :string}, default: []
        field :response_include_grid_data, :boolean, default: false
      end

      output do
        field :batch_update, :map
      end
    end
  end
end
