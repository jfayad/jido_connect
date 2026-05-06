defmodule Jido.Connect.Google.CalendarTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Calendar

  test "declares Google Calendar provider metadata" do
    spec = Calendar.integration()

    assert spec.id == :google_calendar
    assert spec.package == :jido_connect_google_calendar
    assert spec.name == "Google Calendar"
    assert spec.category == :calendar
    assert spec.tags == [:google, :workspace, :calendar, :productivity]
    assert spec.actions == []
    assert spec.triggers == []

    assert [%{id: :user, kind: :oauth2, refresh?: true, pkce?: true} = profile] =
             spec.auth_profiles

    assert "openid" in profile.default_scopes
    assert "https://www.googleapis.com/auth/calendar.freebusy" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/calendar.events.readonly" in profile.optional_scopes
    assert "https://www.googleapis.com/auth/calendar.events" in profile.optional_scopes
  end
end
