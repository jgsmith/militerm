defmodule Militerm.Config do
  @repo Application.fetch_env!(:militerm, :repo)

  def components, do: master.components()

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

  def character_archetype do
    :militerm
    |> Application.fetch_env!(:game)
    |> Keyword.get(:character_archetype)
  end

  def character_start_data do
    :militerm
    |> Application.fetch_env!(:game)
    |> Keyword.get(:character_start_data)
  end

  def character_start_location do
    :militerm
    |> Application.fetch_env!(:game)
    |> Keyword.get(:character_start_location)
  end

  def master do
    Application.get_env(:militerm, :master, Militerm.Master.Default)
  end
end
