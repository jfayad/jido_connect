defmodule Jido.Connect.Google.Contacts.Client do
  @moduledoc "Google People API client facade for Contacts."

  alias Jido.Connect.Google.Contacts.Client.People

  defdelegate list_people(params, access_token), to: People
  defdelegate get_person(params, access_token), to: People
  defdelegate search_people(params, access_token), to: People
  defdelegate create_contact(params, access_token), to: People
  defdelegate update_contact(params, access_token), to: People
  defdelegate delete_contact(params, access_token), to: People
end
