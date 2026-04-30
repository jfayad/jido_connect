defmodule Jido.Connect.Slack.Client.FacadeTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Slack.Client

  test "compatibility facade keeps the original public client surface" do
    assert_exported(Client, :list_channels, 2)
    assert_exported(Client, :post_message, 2)
    assert_exported(Client, :upload_file, 2)
    assert_exported(Client, :add_reaction, 2)
    assert_exported(Client, :list_pins, 2)
    assert_exported(Client, :lookup_user_by_email, 2)
    assert_exported(Client, :auth_test, 1)
  end

  test "API-area modules expose focused client boundaries" do
    assert_exported(Client.Conversations, :list_channels, 2)
    assert_exported(Client.Messages, :get_thread_replies, 2)
    assert_exported(Client.Files, :share_file, 2)
    assert_exported(Client.Reactions, :get_reactions, 2)
    assert_exported(Client.Pins, :add_pin, 2)
    assert_exported(Client.Users, :user_info, 2)
    assert_exported(Client.Identity, :team_info, 2)
  end

  defp assert_exported(module, function, arity) do
    assert {:module, ^module} = Code.ensure_loaded(module)
    assert function_exported?(module, function, arity)
  end
end
