defmodule Jido.Connect.Google.Contacts.Client.Response do
  @moduledoc "Google People API response handling for Contacts."

  alias Jido.Connect.Data
  alias Jido.Connect.Google.Contacts.{Client.Transport, Normalizer}

  def handle_person_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, people} <-
           normalize_items(
             body,
             "connections",
             &Normalizer.person/1,
             "Google Contacts person list response was invalid"
           ) do
      {:ok,
       %{
         people: people,
         next_page_token: Data.get(body, "nextPageToken"),
         next_sync_token: Data.get(body, "nextSyncToken"),
         total_items: Data.get(body, "totalItems")
       }
       |> Data.compact()}
    end
  end

  def handle_person_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Contacts person list response was invalid", body)
  end

  def handle_person_list_response(response), do: Transport.handle_error_response(response)

  def handle_person_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.person/1, "Google Contacts person response was invalid")
  end

  def handle_person_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Contacts person response was invalid", body)
  end

  def handle_person_response(response), do: Transport.handle_error_response(response)

  def handle_person_search_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, people} <-
           normalize_items(
             body,
             "results",
             &normalize_search_result/1,
             "Google Contacts person search response was invalid"
           ) do
      {:ok, %{people: people}}
    end
  end

  def handle_person_search_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Contacts person search response was invalid", body)
  end

  def handle_person_search_response(response), do: Transport.handle_error_response(response)

  def handle_contact_delete_response({:ok, %{status: status}}, params) when status in 200..299 do
    {:ok,
     %{
       resource_name: Data.get(params, :resource_name),
       deleted?: true
     }}
  end

  def handle_contact_delete_response(response, _params),
    do: Transport.handle_error_response(response)

  def handle_contact_group_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, groups} <-
           normalize_items(
             body,
             "contactGroups",
             &Normalizer.group/1,
             "Google Contacts contact group list response was invalid"
           ) do
      {:ok,
       %{
         groups: groups,
         next_page_token: Data.get(body, "nextPageToken"),
         next_sync_token: Data.get(body, "nextSyncToken")
       }
       |> Data.compact()}
    end
  end

  def handle_contact_group_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response(
      "Google Contacts contact group list response was invalid",
      body
    )
  end

  def handle_contact_group_list_response(response), do: Transport.handle_error_response(response)

  def handle_contact_group_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.group/1, "Google Contacts contact group response was invalid")
  end

  def handle_contact_group_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Contacts contact group response was invalid", body)
  end

  def handle_contact_group_response(response), do: Transport.handle_error_response(response)

  defp normalize_one(body, normalizer, message) do
    case normalizer.(body) do
      {:ok, item} -> {:ok, item}
      {:error, _error} -> Transport.invalid_success_response(message, body)
    end
  end

  defp normalize_items(body, key, normalizer, message) do
    case Data.get(body, key, []) do
      items when is_list(items) ->
        items
        |> Enum.reduce_while({:ok, []}, fn payload, {:ok, acc} ->
          case normalizer.(payload) do
            {:ok, item} -> {:cont, {:ok, [item | acc]}}
            {:error, _error} -> {:halt, Transport.invalid_success_response(message, body)}
          end
        end)
        |> case do
          {:ok, items} -> {:ok, Enum.reverse(items)}
          {:error, error} -> {:error, error}
        end

      _invalid ->
        Transport.invalid_success_response(message, body)
    end
  end

  defp normalize_search_result(result) do
    case Data.get(result, "person") do
      person when is_map(person) -> Normalizer.person(person)
      _missing -> {:error, :missing_person}
    end
  end
end
