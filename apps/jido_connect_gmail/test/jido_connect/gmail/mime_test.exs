defmodule Jido.Connect.Gmail.MIMETest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Gmail.MIME

  test "builds base64url encoded text messages" do
    assert {:ok, raw} =
             MIME.build_raw(%{
               to: ["to@example.com"],
               cc: ["cc@example.com"],
               subject: "Hello",
               body_text: "Body"
             })

    assert {:ok, message} = Base.url_decode64(raw, padding: false)
    assert message =~ "To: to@example.com"
    assert message =~ "Cc: cc@example.com"
    assert message =~ "Subject: Hello"
    assert message =~ "Content-Type: text/plain; charset=UTF-8"
    assert message =~ "\r\n\r\nBody"
  end

  test "builds html messages" do
    assert {:ok, raw} =
             MIME.build_raw(%{
               to: ["to@example.com"],
               subject: "Hello",
               body_html: "<p>Body</p>"
             })

    assert {:ok, message} = Base.url_decode64(raw, padding: false)
    assert message =~ "Content-Type: text/html; charset=UTF-8"
    assert message =~ "<p>Body</p>"
  end

  test "rejects invalid recipients" do
    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_recipient,
              details: %{field: :to}
            }} =
             MIME.build_raw(%{
               to: ["not-an-email"],
               subject: "Hello",
               body_text: "Body"
             })
  end

  test "requires message body" do
    assert {:error, %Connect.Error.ValidationError{reason: :missing_body}} =
             MIME.build_raw(%{to: ["to@example.com"], subject: "Hello"})
  end
end
