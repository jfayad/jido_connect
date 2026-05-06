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

  @default_update_person_fields [
    "names",
    "emailAddresses",
    "phoneNumbers",
    "organizations"
  ]

  @doc "Default People API person fields used by Contacts read actions."
  def default_person_fields, do: Enum.join(@default_person_fields, ",")

  @doc "Default People API update mask for Contacts mutation actions."
  def default_update_person_fields, do: Enum.join(@default_update_person_fields, ",")

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

  @doc "Builds query params for `people.createContact`."
  def create_contact_params(params) do
    %{
      personFields: Data.get(params, :person_fields, default_person_fields()),
      fields: Data.get(params, :fields, person_response_fields())
    }
    |> Data.compact()
  end

  @doc "Builds query params for `people.updateContact`."
  def update_contact_params(params) do
    %{
      updatePersonFields: Data.get(params, :update_person_fields, default_update_person_fields()),
      personFields: Data.get(params, :person_fields, default_person_fields()),
      fields: Data.get(params, :fields, person_response_fields())
    }
    |> Data.compact()
  end

  @doc "Builds a Google People API contact mutation body."
  def contact_body(params) do
    %{
      resourceName: Data.get(params, :resource_name),
      etag: Data.get(params, :etag),
      names: names_body(params),
      emailAddresses: contact_detail_body(params, :email_addresses, &email_body/1),
      phoneNumbers: contact_detail_body(params, :phone_numbers, &phone_body/1),
      organizations: contact_detail_body(params, :organizations, &organization_body/1)
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

  defp names_body(params) do
    case Data.get(params, :names) do
      names when is_list(names) ->
        Enum.map(names, &name_body/1)

      _missing ->
        inferred_name_body(params)
    end
  end

  defp inferred_name_body(params) do
    name =
      %{
        displayName: Data.get(params, :display_name),
        givenName: Data.get(params, :given_name),
        familyName: Data.get(params, :family_name)
      }
      |> Data.compact()

    if map_size(name) == 0, do: nil, else: [name]
  end

  defp name_body(name) do
    %{
      displayName: Data.get(name, :display_name),
      givenName: Data.get(name, :given_name),
      familyName: Data.get(name, :family_name),
      middleName: Data.get(name, :middle_name),
      honorificPrefix: Data.get(name, :honorific_prefix),
      honorificSuffix: Data.get(name, :honorific_suffix)
    }
    |> Data.compact()
  end

  defp contact_detail_body(params, field, mapper) do
    case Data.get(params, field) do
      details when is_list(details) -> Enum.map(details, mapper)
      _missing -> nil
    end
  end

  defp email_body(email) do
    %{
      value: Data.get(email, :value),
      type: Data.get(email, :type),
      displayName: Data.get(email, :display_name)
    }
    |> Data.compact()
  end

  defp phone_body(phone) do
    %{
      value: Data.get(phone, :value),
      canonicalForm: Data.get(phone, :canonical_form),
      type: Data.get(phone, :type)
    }
    |> Data.compact()
  end

  defp organization_body(organization) do
    %{
      name: Data.get(organization, :name),
      title: Data.get(organization, :title),
      department: Data.get(organization, :department),
      symbol: Data.get(organization, :symbol),
      domain: Data.get(organization, :domain),
      type: Data.get(organization, :type),
      current: Data.get(organization, :current)
    }
    |> Data.compact()
  end
end
