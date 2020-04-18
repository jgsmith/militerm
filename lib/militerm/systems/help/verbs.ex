defmodule Militerm.Systems.Help.Verbs do
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

  def call(request), do: request

  def get_document(request), do: request

  def fulfill_request([], _word, request), do: request

  def fulfill_request([category | rest], word, request) do
    case Militerm.Services.Verbs.get_syntaxes(category, word) do
      nil ->
        fulfill_request(rest, word, request)

      [] ->
        fulfill_request(rest, word, request)

      syntaxes ->
        syntax_patterns =
          syntaxes
          |> Enum.map(fn %{short: short} -> [word, " ", short] end)
          |> Enum.intersperse(" ; ")

        %{request | handled: true, text: ["Syntaxes:\n\n", syntax_patterns]}
    end
  end
end
