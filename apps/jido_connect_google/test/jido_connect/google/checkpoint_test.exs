defmodule Jido.Connect.Google.CheckpointTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Error
  alias Jido.Connect.Google.Checkpoint

  test "builds normalized expired checkpoint errors with reset guidance" do
    provider_error =
      Error.provider("Google API request failed",
        provider: :google,
        reason: :http_error,
        status: 410,
        details: %{message: "Sync token is no longer valid"}
      )

    assert {:error,
            %Error.ProviderError{
              provider: :google,
              reason: :checkpoint_expired,
              status: 410,
              details: %{
                checkpoint: "sync-1",
                checkpoint_reset: %{
                  action: :clear_checkpoint,
                  behavior: :initialize_without_replay
                },
                provider_reason: :http_error,
                provider_details: %{message: "Sync token is no longer valid"}
              }
            }} = Checkpoint.expired("Google Calendar event sync token", "sync-1", provider_error)
  end

  test "builds normalized invalid checkpoint response errors with reset guidance" do
    assert {:error,
            %Error.ProviderError{
              provider: :google,
              reason: :invalid_response,
              details: %{
                next_page_token: "loop",
                checkpoint_reset: %{
                  action: :clear_checkpoint,
                  behavior: :initialize_without_replay
                }
              }
            }} =
             Checkpoint.invalid_response("Google response repeated nextPageToken", %{
               next_page_token: "loop"
             })
  end

  test "detects provider errors that require checkpoint reset" do
    assert Checkpoint.expired_provider_error?(
             Error.provider("Gone", provider: :google, reason: :http_error, status: 410)
           )

    assert Checkpoint.expired_provider_error?(
             Error.provider("Missing", provider: :google, reason: :http_error, status: 404)
           )

    refute Checkpoint.expired_provider_error?(
             Error.provider("Rate limited", provider: :google, reason: :http_error, status: 429)
           )
  end
end
