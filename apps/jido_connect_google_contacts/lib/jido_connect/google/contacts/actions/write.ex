defmodule Jido.Connect.Google.Contacts.Actions.Write do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @contacts_scope "https://www.googleapis.com/auth/contacts"
  @scope_resolver Jido.Connect.Google.Contacts.ScopeResolver

  actions do
    action :create_contact do
      id("google.contacts.person.create")
      resource(:person)
      verb(:create)
      data_classification(:personal_data)
      label("Create contact")
      description("Create a Google Contacts person.")
      handler(Jido.Connect.Google.Contacts.Handlers.Actions.CreateContact)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@contacts_scope], resolver: @scope_resolver)
      end

      input do
        field(:display_name, :string)
        field(:given_name, :string)
        field(:family_name, :string)
        field(:names, {:array, :map})
        field(:email_addresses, {:array, :map})
        field(:phone_numbers, {:array, :map})
        field(:organizations, {:array, :map})
        field(:person_fields, :string)
        field(:fields, :string)
      end

      output do
        field(:person, :map)
      end
    end

    action :update_contact do
      id("google.contacts.person.update")
      resource(:person)
      verb(:update)
      data_classification(:personal_data)
      label("Update contact")
      description("Patch a Google Contacts person.")
      handler(Jido.Connect.Google.Contacts.Handlers.Actions.UpdateContact)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@contacts_scope], resolver: @scope_resolver)
      end

      input do
        field(:resource_name, :string, required?: true, example: "people/c123")
        field(:etag, :string, required?: true)
        field(:display_name, :string)
        field(:given_name, :string)
        field(:family_name, :string)
        field(:names, {:array, :map})
        field(:email_addresses, {:array, :map})
        field(:phone_numbers, {:array, :map})
        field(:organizations, {:array, :map})
        field(:update_person_fields, :string)
        field(:person_fields, :string)
        field(:fields, :string)
      end

      output do
        field(:person, :map)
      end
    end

    action :delete_contact do
      id("google.contacts.person.delete")
      resource(:person)
      verb(:delete)
      data_classification(:personal_data)
      label("Delete contact")
      description("Delete a Google Contacts person.")
      handler(Jido.Connect.Google.Contacts.Handlers.Actions.DeleteContact)
      effect(:destructive, confirmation: :always)

      access do
        auth(:user)
        scopes([@contacts_scope], resolver: @scope_resolver)
      end

      input do
        field(:resource_name, :string, required?: true, example: "people/c123")
      end

      output do
        field(:result, :map)
      end
    end

    action :create_contact_group do
      id("google.contacts.group.create")
      resource(:group)
      verb(:create)
      data_classification(:personal_data)
      label("Create contact group")
      description("Create a Google Contacts contact group.")
      handler(Jido.Connect.Google.Contacts.Handlers.Actions.CreateContactGroup)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@contacts_scope], resolver: @scope_resolver)
      end

      input do
        field(:name, :string, required?: true)
        field(:fields, :string)
      end

      output do
        field(:group, :map)
      end
    end

    action :update_contact_group do
      id("google.contacts.group.update")
      resource(:group)
      verb(:update)
      data_classification(:personal_data)
      label("Update contact group")
      description("Update a Google Contacts contact group name.")
      handler(Jido.Connect.Google.Contacts.Handlers.Actions.UpdateContactGroup)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@contacts_scope], resolver: @scope_resolver)
      end

      input do
        field(:resource_name, :string, required?: true, example: "contactGroups/friends")
        field(:name, :string, required?: true)
        field(:etag, :string)
        field(:update_group_fields, :string)
        field(:fields, :string)
      end

      output do
        field(:group, :map)
      end
    end
  end
end
