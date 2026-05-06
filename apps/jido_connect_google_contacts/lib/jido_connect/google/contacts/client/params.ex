defmodule Jido.Connect.Google.Contacts.Client.Params do
  @moduledoc "Google People API request parameter helpers for Contacts."

  alias Jido.Connect.Data

  @default_person_fields [
    "names",
    "emailAddresses",
    "phoneNumbers",
    "organizations",
    "memberships",
    "photos",
    "addresses",
    "birthdays",
    "urls",
    "metadata"
  ]

  @doc "Default People API person fields used by Contacts read actions."
  def default_person_fields, do: Enum.join(@default_person_fields, ",")

  @doc "Builds query params for `people.connections.list`."
  def list_people_params(params) do
    %{
      pageSize: Data.get(params, :page_size, 100),
      pageToken: Data.get(params, :page_token),
      personFields: Data.get(params, :person_fields, default_person_fields()),
      fields: Data.get(params, :fields, people_list_fields()),
      sortOrder: Data.get(params, :sort_order),
      sources: Data.get(params, :sources),
      requestSyncToken: Data.get(params, :request_sync_token),
      syncToken: Data.get(params, :sync_token)
    }
    |> Data.compact()
  end

  @doc "Builds query params for `people.get`."
  def get_person_params(params) do
    %{
      personFields: Data.get(params, :person_fields, default_person_fields()),
      fields: Data.get(params, :fields, person_response_fields()),
      sources: Data.get(params, :sources)
    }
    |> Data.compact()
  end

  @doc "Builds query params for `people.searchContacts`."
  def search_people_params(params) do
    %{
      query: Data.get(params, :query),
      pageSize: Data.get(params, :page_size, 10),
      readMask: Data.get(params, :read_mask, default_person_fields()),
      fields: Data.get(params, :fields, people_search_fields()),
      sources: Data.get(params, :sources)
    }
    |> Data.compact()
  end

  defp people_list_fields do
    "nextPageToken,nextSyncToken,totalItems,connections(#{person_response_fields()})"
  end

  defp people_search_fields do
    "results(person(#{person_response_fields()}))"
  end

  defp person_response_fields do
    "resourceName,etag,#{default_person_fields()}"
  end
end
