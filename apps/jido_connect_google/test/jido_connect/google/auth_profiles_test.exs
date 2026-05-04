defmodule Jido.Connect.Google.AuthProfilesTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.{AuthProfile, AuthProfiles}

  test "models user and future service account auth profiles" do
    assert AuthProfiles.ids() == [:user, :service_account, :domain_delegated_service_account]

    assert %AuthProfile{
             id: :user,
             kind: :oauth2,
             owner: :app_user,
             subject: :user,
             default?: true,
             implemented?: true
           } = AuthProfiles.fetch!(:user)

    assert %AuthProfile{
             id: :service_account,
             kind: :service_account,
             implemented?: false
           } = AuthProfiles.fetch!(:service_account)

    assert %AuthProfile{
             id: :domain_delegated_service_account,
             kind: :domain_delegated_service_account,
             owner: :tenant,
             implemented?: false
           } = AuthProfiles.fetch!(:domain_delegated_service_account)
  end
end
