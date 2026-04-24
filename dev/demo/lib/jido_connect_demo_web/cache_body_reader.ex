defmodule Jido.Connect.DemoWeb.CacheBodyReader do
  @moduledoc false

  def read_body(conn, opts) do
    with {:ok, body, conn} <- Plug.Conn.read_body(conn, opts) do
      {:ok, body, Plug.Conn.assign(conn, :raw_body, body)}
    end
  end
end
