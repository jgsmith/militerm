defmodule MilitermWeb.AdminRouter do
  use MilitermWeb, :router

  scope "/admin", MilitermWeb do
    resources "/domains", DomainController do
      resources "/areas", AreaController, only: [:new, :create]
    end

    resources "/areas", AreaController, only: [:show, :edit, :update, :delete] do
      resources "/scenes", SceneController, only: [:new, :create]
    end

    resources "/scenes", SceneController, only: [:show, :edit, :update, :delete]
  end
end
