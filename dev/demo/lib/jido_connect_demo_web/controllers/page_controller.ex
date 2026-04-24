defmodule Jido.Connect.DemoWeb.PageController do
  use Jido.Connect.DemoWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
