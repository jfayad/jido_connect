defmodule Jido.Connect.Gmail.Client do
  @moduledoc "Gmail API client facade."

  alias Jido.Connect.Gmail.Client.Users

  defdelegate get_profile(params, access_token), to: Users
  defdelegate list_labels(params, access_token), to: Users
end
