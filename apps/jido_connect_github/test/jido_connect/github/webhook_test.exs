defmodule Jido.Connect.GitHub.WebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.GitHub.Webhook

  test "verifies valid signature" do
    body = ~s({"action":"opened"})
    signature = "sha256=" <> hmac("secret", body)

    assert :ok = Webhook.verify_signature(body, signature, "secret")
  end

  test "rejects missing and invalid signatures" do
    assert {:error, :missing_signature} = Webhook.verify_signature("{}", nil, "secret")
    assert {:error, :invalid_signature} = Webhook.verify_signature("{}", "sha256=bad", "secret")
  end

  test "normalizes GitHub issues event into poll signal shape" do
    payload = %{
      "repository" => %{"full_name" => "org/repo"},
      "issue" => %{
        "number" => 10,
        "title" => "Bug",
        "html_url" => "https://github.com/org/repo/issues/10"
      }
    }

    assert {:ok,
            %{
              repo: "org/repo",
              issue_number: 10,
              title: "Bug",
              url: "https://github.com/org/repo/issues/10"
            }} = Webhook.normalize_signal("issues", payload)
  end

  test "detects duplicate delivery ids from host-provided seen set" do
    assert Webhook.duplicate?("delivery-1", ["delivery-1"])
    refute Webhook.duplicate?("delivery-2", ["delivery-1"])
  end

  defp hmac(secret, body) do
    :hmac
    |> :crypto.mac(:sha256, secret, body)
    |> Base.encode16(case: :lower)
  end
end
