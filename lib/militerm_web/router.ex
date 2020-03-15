defmodule MilitermWeb.Router do
  use MilitermWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MilitermWeb do
    pipe_through :browser

    get "/", PageController, :index
    resources "/game", CharacterController, only: [:index, :show, :new, :create]
    live "/game/:character/play", GameLive

    forward "/", AdminRouter
  end

  # Other scopes may use custom stacks.
  # scope "/api", MilitermWeb do
  #   pipe_through :api
  # end
end
