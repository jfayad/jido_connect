defmodule Jido.Connect.Google.Contacts.Actions.Read do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @contacts_readonly_scope "https://www.googleapis.com/auth/contacts.readonly"
  @profile_scope "profile"
  @scope_resolver Jido.Connect.Google.Contacts.ScopeResolver

  actions do
    action :list_people do
      id("google.contacts.person.list")
      resource(:person)
      verb(:list)
      data_classification(:personal_data)
      label("List contacts")
      description("List the authenticated user's Google Contacts people.")
      handler(Jido.Connect.Google.Contacts.Handlers.Actions.ListPeople)
      effect(:read)

      access do
        auth(:user)
        scopes([@contacts_readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:resource_name, :string, default: "people/me")
        field(:page_size, :integer, default: 100)
        field(:page_token, :string)
        field(:person_fields, :string)
        field(:fields, :string)

        field(:sort_order, :string,
          enum: [
            "LAST_MODIFIED_ASCENDING",
            "LAST_MODIFIED_DESCENDING",
            "FIRST_NAME_ASCENDING",
            "LAST_NAME_ASCENDING"
          ]
        )

        field(:sources, {:array, :string})
        field(:request_sync_token, :boolean, default: false)
        field(:sync_token, :string)
      end

      output do
        field(:people, {:array, :map})
        field(:next_page_token, :string)
        field(:next_sync_token, :string)
        field(:total_items, :integer)
      end
    end

    action :get_person do
      id("google.contacts.person.get")
      resource(:person)
      verb(:get)
      data_classification(:personal_data)
      label("Get person")
      description("Fetch a Google People API person by resource name.")
      handler(Jido.Connect.Google.Contacts.Handlers.Actions.GetPerson)
      effect(:read)

      access do
        auth(:user)
        scopes([@profile_scope, @contacts_readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:resource_name, :string, required?: true, example: "people/me")
        field(:person_fields, :string)
        field(:fields, :string)
        field(:sources, {:array, :string})
      end

      output do
        field(:person, :map)
      end
    end

    action :search_people do
      id("google.contacts.person.search")
      resource(:person)
      verb(:search)
      data_classification(:personal_data)
      label("Search contacts")
      description("Search the authenticated user's Google Contacts people.")
      handler(Jido.Connect.Google.Contacts.Handlers.Actions.SearchPeople)
      effect(:read)

      access do
        auth(:user)
        scopes([@contacts_readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:query, :string, required?: true, example: "Ada")
        field(:page_size, :integer, default: 10)
        field(:read_mask, :string)
        field(:fields, :string)
        field(:sources, {:array, :string})
      end

      output do
        field(:people, {:array, :map})
      end
    end

    action :list_contact_groups do
      id("google.contacts.group.list")
      resource(:group)
      verb(:list)
      data_classification(:personal_data)
      label("List contact groups")
      description("List Google Contacts contact groups.")
      handler(Jido.Connect.Google.Contacts.Handlers.Actions.ListContactGroups)
      effect(:read)

      access do
        auth(:user)
        scopes([@contacts_readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:page_size, :integer, default: 30)
        field(:page_token, :string)
        field(:sync_token, :string)
        field(:group_fields, :string)
        field(:fields, :string)
      end

      output do
        field(:groups, {:array, :map})
        field(:next_page_token, :string)
        field(:next_sync_token, :string)
      end
    end
  end
end
