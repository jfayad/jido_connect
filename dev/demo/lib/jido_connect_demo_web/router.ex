defmodule Jido.Connect.DemoWeb.Router do
  use Jido.Connect.DemoWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {Jido.Connect.DemoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Jido.Connect.DemoWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/integrations/github/setup", IntegrationController, :github_setup
    get "/integrations/github/setup/complete", IntegrationController, :github_setup_complete
    get "/integrations/github/oauth/start", IntegrationController, :github_oauth_start
    get "/integrations/github/oauth/callback", IntegrationController, :github_oauth_callback
  end

  scope "/", Jido.Connect.DemoWeb do
    pipe_through :api

    get "/health", IntegrationController, :health
    get "/integrations", IntegrationController, :index
    post "/integrations/github/webhook", IntegrationController, :github_webhook
  end
end
