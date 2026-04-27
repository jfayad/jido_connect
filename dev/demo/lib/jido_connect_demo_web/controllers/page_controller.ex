defmodule Jido.Connect.DemoWeb.PageController do
  use Jido.Connect.DemoWeb, :controller

  def home(conn, params) do
    query = Map.get(params, "q", "")

    render(conn, :home,
      integrations: Jido.Connect.Demo.Integrations.all(query: query),
      query: query
    )
  end
end
