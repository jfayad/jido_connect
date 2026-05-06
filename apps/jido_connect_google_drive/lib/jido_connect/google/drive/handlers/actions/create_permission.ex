defmodule Jido.Connect.Google.Drive.Handlers.Actions.CreatePermission do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Google.Drive.Client

  @permission_types ["user", "group", "domain", "anyone"]
  @permission_roles ["owner", "organizer", "fileOrganizer", "writer", "commenter", "reader"]

  def run(input, %{credentials: credentials}) do
    with :ok <- validate_permission(input),
         {:ok, client} <- fetch_client(credentials),
         {:ok, permission} <-
           client.create_permission(normalize_input(input), Map.get(credentials, :access_token)) do
      {:ok, %{permission: public_map(permission)}}
    end
  end

  defp validate_permission(input) do
    with :ok <- validate_member(:type, Data.get(input, :type), @permission_types),
         :ok <- validate_member(:role, Data.get(input, :role), @permission_roles),
         :ok <- validate_target(input),
         :ok <- validate_owner_transfer(input) do
      :ok
    end
  end

  defp validate_member(field, value, allowed) do
    if value in allowed do
      :ok
    else
      validation_error("Invalid Google Drive permission #{field}",
        field: field,
        value: value,
        allowed: allowed
      )
    end
  end

  defp validate_target(input) do
    case Data.get(input, :type) do
      type when type in ["user", "group"] ->
        require_present(input, :email_address, "#{type} permissions require an email address")

      "domain" ->
        require_present(input, :domain, "Domain permissions require a domain")

      _other ->
        :ok
    end
  end

  defp validate_owner_transfer(input) do
    if Data.get(input, :role) == "owner" and Data.get(input, :transfer_ownership) != true do
      validation_error("Owner permissions require transfer_ownership to be true",
        field: :transfer_ownership
      )
    else
      :ok
    end
  end

  defp require_present(input, field, message) do
    case Data.get(input, field) do
      value when is_binary(value) ->
        if String.trim(value) == "" do
          validation_error(message, field: field)
        else
          :ok
        end

      _missing ->
        validation_error(message, field: field)
    end
  end

  defp normalize_input(input) do
    input
    |> trim_string(:email_address)
    |> trim_string(:domain)
    |> Map.put_new(:transfer_ownership, false)
    |> Map.put_new(:supports_all_drives, false)
    |> Map.put_new(:use_domain_admin_access, false)
  end

  defp trim_string(input, field) do
    case Data.get(input, field) do
      value when is_binary(value) -> Map.put(input, field, String.trim(value))
      _other -> input
    end
  end

  defp validation_error(message, details) do
    {:error, Error.validation(message, reason: :invalid_permission, details: Map.new(details))}
  end

  defp fetch_client(%{google_drive_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(map) when is_map(map), do: map
  defp public_map(value), do: value
end
