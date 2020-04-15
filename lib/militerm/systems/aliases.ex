defmodule Militerm.Systems.Aliases do
  use Militerm.ECS.System

  alias Militerm.Systems.Entity

  defcommand alias_(arg),
    for: %{"this" => {:thing, entity_id} = this},
    as: "alias" do
    [word, definition] = String.split(arg, ~r{\s+}, parts: 2, trim: true)
    Militerm.Components.Aliases.set(entity_id, word, definition)
    Entity.receive_message(this, "cmd", "Added definition for #{word}.")
  end

  defcommand unalias(word), for: %{"this" => {:thing, entity_id} = this} do
    Militerm.Components.Aliases.remove(entity_id, word)
    Entity.receive_message(this, "cmd", "Removed definition of #{word}.")
  end

  defcommand aliases(_), for: %{"this" => {:thing, entity_id} = this} do
    case Militerm.Components.Aliases.get(entity_id) do
      nil ->
        Entity.receive_message(this, "cmd", "You have no aliases.")

      map when map_size(map) == 0 ->
        Entity.receive_message(this, "cmd", "You have no aliases.")

      map ->
        for {word, definition} <- map do
          Entity.receive_message(this, "cmd", "#{word} : #{definition}")
        end
    end
  end
end
