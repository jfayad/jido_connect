defmodule Jido.Connect.Security do
  @moduledoc "Shared cryptographic helpers for provider protocol code."

  @spec hmac_sha256_hex(iodata(), iodata()) :: String.t()
  def hmac_sha256_hex(secret, payload) do
    :hmac
    |> :crypto.mac(:sha256, secret, payload)
    |> Base.encode16(case: :lower)
  end

  @spec secure_compare?(binary(), binary()) :: boolean()
  def secure_compare?(left, right)
      when is_binary(left) and is_binary(right) and byte_size(left) == byte_size(right) do
    left
    |> :binary.bin_to_list()
    |> Enum.zip(:binary.bin_to_list(right))
    |> Enum.reduce(0, fn {left_byte, right_byte}, acc ->
      :erlang.bor(acc, :erlang.bxor(left_byte, right_byte))
    end)
    |> Kernel.==(0)
  end

  def secure_compare?(_left, _right), do: false
end
