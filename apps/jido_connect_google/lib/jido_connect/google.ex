defmodule Jido.Connect.Google do
  @moduledoc """
  Shared Google foundation helpers for Jido Connect provider packages.

  This module intentionally exposes only provider-family metadata. Product
  connectors such as Sheets, Gmail, Drive, and Calendar own their provider DSL
  declarations and endpoint handlers.
  """

  @provider :google

  @doc "Returns the shared provider family atom used by Google packages."
  @spec provider() :: :google
  def provider, do: @provider

  @doc "Returns auth profiles known to the shared Google foundation."
  @spec auth_profiles() :: [atom()]
  defdelegate auth_profiles, to: Jido.Connect.Google.AuthProfiles, as: :ids
end
