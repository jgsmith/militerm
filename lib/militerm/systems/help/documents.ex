defmodule Militerm.Systems.Help.Documents do
  @moduledoc """
  Provides help documents based on static text files.
  """

  def call(%{arg: [word], actor: {:thing, actor_id}, handled: false} = request) do
    fulfill_request(Militerm.Components.EphemeralGroup.get_groups(actor_id), word, request)
  end

  def call(%{arg: [category, word], actor: {:thing, actor_id}, handled: false} = request) do
    if Militerm.Components.EphemeralGroup.get_value(actor_id, [category]) do
      fulfill_request([category], word, request)
    else
      request
    end
  end

  def get_document(request), do: request

  def fulfill_request([], _word, request), do: request

  def fulfill_request([category | rest], word, request) do
    path = Path.join([Militerm.Config.game_dir(), "docs", category, word])
    ext = Enum.find([".md", ".nroff", ".txt"], &File.exists?(path <> &1))

    if is_nil(ext) do
      fulfill_request(rest, word, request)
    else
      case File.read(path <> ext) do
        {:ok, contents} ->
          case ext do
            ".md" ->
              %{request | handled: true, markdown: contents}

            ".nroff" ->
              %{request | handled: true, nroff: contents}

            ".txt" ->
              %{request | handled: true, text: contents}
          end

        _ ->
          fulfill_request(rest, word, request)
      end
    end
  end
end
