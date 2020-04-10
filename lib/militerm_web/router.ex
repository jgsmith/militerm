defmodule MilitermWeb.Router do
  use MilitermWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :auth do
    plug MilitermWeb.UserAuth.Pipeline
  end

  # We use ensure_auth to fail if there is no one logged in
  pipeline :ensure_auth do
    plug Guardian.Plug.EnsureAuthenticated
  end

  pipeline :ensure_admin do
  end

  scope "/", MilitermWeb do
    pipe_through [:browser, :auth]

    get "/", PageController, :index
    get "/auth/:provider", AuthController, :request
    get "/auth/:provider/callback", AuthController, :callback
    post "/auth/:provider/callback", AuthController, :callback
  end

  scope "/", MilitermWeb do
    pipe_through [:browser, :auth, :ensure_auth]

    resources "/game", CharacterController, only: [:index, :show, :new, :create]
    get "/game/:character/play", CharacterController, :play

    get "/game/auth/:session_id", SessionController, :auth_session

    post "/auth/logout", AuthController, :delete
  end

  scope "/admin", MilitermWeb do
    pipe_through [:browser, :auth, :ensure_auth, :ensure_admin]

    get "/", AdminController, :index

    resources "/domains", DomainController do
      resources "/areas", AreaController, only: [:new, :create]
    end

    resources "/areas", AreaController, only: [:show, :edit, :update, :delete] do
      resources "/scenes", SceneController, only: [:new, :create]
    end

    resources "/scenes", SceneController, only: [:show, :edit, :update, :delete]
  end

  # Other scopes may use custom stacks.
  # scope "/api", MilitermWeb do
  #   pipe_through :api
  # end
end
