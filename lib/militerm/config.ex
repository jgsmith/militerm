defmodule Militerm.Config do
  @components Map.new([
                {:entity, Militerm.Components.Entity}
                | Application.get_env(:militerm, :components, [])
              ])

  @game Application.fetch_env!(:militerm, :game)

  @repo Application.fetch_env!(:militerm, :repo)

  def components, do: @components

  def game_dir do
    case Keyword.get(@game, :dir) do
      {app, path} -> Application.app_dir(app, path)
      path when is_binary(path) -> Application.app_dir(:militerm, path)
    end
  end

  def character_finder, do: Keyword.get(@game, :character_finder)

  def repo, do: @repo

  def post_events_async do
    Application.get_env(:militerm, :post_events_async, true)
  end
end
