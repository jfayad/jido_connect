defmodule Jido.Connect.Google.Calendar.PrivacyAuditTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Calendar
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  test "classifies every Calendar action and trigger privacy boundary" do
    ConnectorContracts.assert_privacy_matrix(
      Calendar,
      [
        action("google.calendar.calendar.list", :personal_data, :read, :none),
        action("google.calendar.event.list", :personal_data, :read, :none),
        action("google.calendar.event.get", :personal_data, :read, :none),
        action("google.calendar.event.create", :personal_data, :write, :required_for_ai),
        action("google.calendar.event.update", :personal_data, :write, :required_for_ai),
        action("google.calendar.event.delete", :personal_data, :destructive, :always),
        action("google.calendar.freebusy.query", :personal_data, :read, :none,
          text_includes: ["freebusy"]
        ),
        action("google.calendar.availability.find", :personal_data, :read, :none,
          text_includes: ["availability"]
        )
      ],
      [
        trigger("google.calendar.event.changed", :personal_data,
          text_includes: ["event", "changed"]
        )
      ]
    )
  end

  defp action(id, classification, risk, confirmation, opts \\ []) do
    %{
      id: id,
      classification: classification,
      risk: risk,
      confirmation: confirmation,
      text_includes: Keyword.get(opts, :text_includes, [])
    }
  end

  defp trigger(id, classification, opts) do
    %{
      id: id,
      classification: classification,
      text_includes: Keyword.get(opts, :text_includes, [])
    }
  end
end
