defmodule Jido.Connect.DemoWeb.IntegrationHTML do
  @moduledoc false

  use Jido.Connect.DemoWeb, :html

  embed_templates "integration_html/*"

  def env_status(true), do: "set"
  def env_status(false), do: "missing"

  def result_value(value) do
    inspect(value, pretty: true, limit: 20)
  end
end
