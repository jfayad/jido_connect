defmodule Jido.Connect.DemoWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use Jido.Connect.DemoWeb, :html

  embed_templates "page_html/*"

  def status_label(:available), do: "Available"
  def status_label(:planned), do: "Planned"
  def status_label(status), do: status |> to_string() |> String.capitalize()
end
