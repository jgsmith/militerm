defmodule Militerm.Config do
  @components Map.new([
                {:entity, Militerm.Components.Entity}
                | Application.get_env(:militerm, :components, [])
              ])

  @repo Application.fetch_env!(:militerm, :repo)

  def components, do: @components

  def game_dir do
    game_dir =
      :militerm
      |> Application.fetch_env!(:game)
      |> Keyword.get(:dir)

    case game_dir do
      {app, path} ->
        Application.app_dir(app, path)

      <<"/" <> _::binary>> = path ->
        path

      path when is_binary(path) ->
        Application.app_dir(:militerm, path)
    end
  end

  def watch_game_files do
    :militerm
    |> Application.fetch_env!(:game)
    |> Keyword.get(:watch_files, false)
  end

  def character_finder do
    :militerm
    |> Application.fetch_env!(:game)
    |> Keyword.get(:character_finder)
  end

  def repo, do: @repo

  def post_events_async do
    Application.get_env(:militerm, :post_events_async, true)
  end

  def character_archetype do
    :militerm
    |> Application.fetch_env!(:game)
    |> Keyword.get(:character_archetype)
  end
end
