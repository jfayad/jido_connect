defmodule Jido.Connect.Google.Contacts.ClientTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Google.Contacts.{Client, Person}

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(
      :jido_connect_google_contacts,
      :google_contacts_api_base_url,
      "https://people.test"
    )

    Application.put_env(:jido_connect_google, :google_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_google_contacts, :google_contacts_api_base_url)
      Application.delete_env(:jido_connect_google, :google_req_options)
    end)
  end

  test "lists people connections" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1/people/me/connections"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer token"]
      assert conn.query_params["pageSize"] == "50"
      assert conn.query_params["requestSyncToken"] == "true"
      assert conn.query_params["sortOrder"] == "LAST_MODIFIED_DESCENDING"
      assert conn.query_params["personFields"] =~ "emailAddresses"
      assert conn.query_params["fields"] =~ "nextSyncToken"

      Req.Test.json(conn, %{
        "connections" => [
          person_payload()
        ],
        "nextPageToken" => "contacts-next",
        "nextSyncToken" => "contacts-sync",
        "totalItems" => 1
      })
    end)

    assert {:ok,
            %{
              people: [%Person{} = person],
              next_page_token: "contacts-next",
              next_sync_token: "contacts-sync",
              total_items: 1
            }} =
             Client.list_people(
               %{
                 resource_name: "people/me",
                 page_size: 50,
                 request_sync_token: true,
                 sort_order: "LAST_MODIFIED_DESCENDING"
               },
               "token"
             )

    assert person.resource_name == "people/c123"
    assert person.display_name == "Ada Lovelace"
    assert [%{value: "ada@example.com"}] = person.email_addresses
  end

  test "gets a person by resource name" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1/people/c123"
      assert conn.query_params["personFields"] =~ "names"
      assert conn.query_params["fields"] =~ "emailAddresses"

      Req.Test.json(conn, person_payload())
    end)

    assert {:ok, %Person{} = person} =
             Client.get_person(%{resource_name: "people/c123"}, "token")

    assert person.person_id == "c123"
    assert person.given_name == "Ada"
  end

  test "searches people contacts" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1/people:searchContacts"
      assert conn.query_params["query"] == "Ada"
      assert conn.query_params["pageSize"] == "10"
      assert conn.query_params["readMask"] =~ "phoneNumbers"
      assert conn.query_params["fields"] =~ "results"

      Req.Test.json(conn, %{
        "results" => [
          %{"person" => person_payload()}
        ]
      })
    end)

    assert {:ok, %{people: [%Person{} = person]}} =
             Client.search_people(%{query: "Ada", page_size: 10}, "token")

    assert person.resource_name == "people/c123"
  end

  test "creates contacts" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v1/people:createContact"
      assert conn.query_params["personFields"] =~ "organizations"
      assert conn.query_params["fields"] =~ "resourceName"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "names" => [
                 %{"givenName" => "Ada", "familyName" => "Lovelace"}
               ],
               "emailAddresses" => [
                 %{"value" => "ada@example.com", "type" => "work"}
               ],
               "phoneNumbers" => [
                 %{"value" => "+1 555 0100", "type" => "mobile"}
               ],
               "organizations" => [
                 %{"name" => "Analytical Engines", "title" => "Programmer"}
               ]
             }

      Req.Test.json(conn, person_payload())
    end)

    assert {:ok, %Person{} = person} =
             Client.create_contact(
               %{
                 given_name: "Ada",
                 family_name: "Lovelace",
                 email_addresses: [%{value: "ada@example.com", type: "work"}],
                 phone_numbers: [%{value: "+1 555 0100", type: "mobile"}],
                 organizations: [%{name: "Analytical Engines", title: "Programmer"}]
               },
               "token"
             )

    assert person.resource_name == "people/c123"
  end

  test "updates contacts" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/v1/people/c123:updateContact"
      assert conn.query_params["updatePersonFields"] == "names,emailAddresses"
      assert conn.query_params["personFields"] =~ "emailAddresses"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "resourceName" => "people/c123",
               "etag" => "etag123",
               "names" => [
                 %{"givenName" => "Ada"}
               ],
               "emailAddresses" => [
                 %{"value" => "ada@example.com"}
               ]
             }

      Req.Test.json(conn, Map.put(person_payload(), "etag", "etag456"))
    end)

    assert {:ok, %Person{} = person} =
             Client.update_contact(
               %{
                 resource_name: "people/c123",
                 etag: "etag123",
                 given_name: "Ada",
                 email_addresses: [%{value: "ada@example.com"}],
                 update_person_fields: "names,emailAddresses"
               },
               "token"
             )

    assert person.etag == "etag456"
  end

  test "deletes contacts" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v1/people/c123:deleteContact"

      Plug.Conn.resp(conn, 200, "")
    end)

    assert {:ok, %{resource_name: "people/c123", deleted?: true}} =
             Client.delete_contact(%{resource_name: "people/c123"}, "token")
  end

  test "returns provider errors for malformed people list items" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1/people/me/connections"

      Req.Test.json(conn, %{
        "connections" => [
          %{"names" => [%{"displayName" => "Missing resource"}]}
        ]
      })
    end)

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              provider: :google,
              reason: :invalid_response
            }} = Client.list_people(%{resource_name: "people/me"}, "token")
  end

  test "returns provider errors for malformed person get responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1/people/c123"

      Req.Test.json(conn, %{"names" => [%{"displayName" => "Missing resource"}]})
    end)

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              provider: :google,
              reason: :invalid_response
            }} = Client.get_person(%{resource_name: "people/c123"}, "token")
  end

  test "returns provider errors for malformed search results" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1/people:searchContacts"

      Req.Test.json(conn, %{"results" => [%{"metadata" => %{}}]})
    end)

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              provider: :google,
              reason: :invalid_response
            }} = Client.search_people(%{query: "Ada"}, "token")
  end

  defp person_payload do
    %{
      "resourceName" => "people/c123",
      "etag" => "etag123",
      "names" => [
        %{
          "displayName" => "Ada Lovelace",
          "givenName" => "Ada",
          "familyName" => "Lovelace",
          "metadata" => %{"primary" => true}
        }
      ],
      "emailAddresses" => [
        %{"value" => "ada@example.com", "type" => "work", "metadata" => %{"primary" => true}}
      ],
      "phoneNumbers" => [
        %{"value" => "+1 555 0100", "canonicalForm" => "+15550100"}
      ],
      "organizations" => [
        %{"name" => "Analytical Engines", "title" => "Programmer", "current" => true}
      ],
      "metadata" => %{"sources" => [%{"type" => "CONTACT"}]}
    }
  end
end
