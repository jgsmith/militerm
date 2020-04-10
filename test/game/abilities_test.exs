defmodule Game.AbilitiesTest do
  use Militerm.DataCase, async: false

  alias Militerm.Test.{Entity}

  setup do
    entity =
      Entity.new("std:character", %{
        detail: %{
          "default" => %{
            "short" => "a typical human",
            "noun" => ["human", "sue"],
            "adjective" => ["typical"]
          }
        },
        identity: %{
          "name" => "Sue",
          "nominative" => "she",
          "possessive" => "her",
          "objective" => "her"
        }
      })

    Militerm.Services.Location.place(entity, {"in", {:thing, "scene:test:area:start", "default"}})

    {:ok, entity: entity}
  end

  describe "setup" do
    test "has the living flag set", %{entity: {:thing, entity_id} = _entity} do
      assert true == Militerm.Components.Flags.flag_set?(entity_id, "living")
    end
  end

  describe "is living" do
    test "has the flag set for a character", %{entity: entity} do
      assert true == Militerm.Systems.Entity.property(entity, ~w"flag living", %{})
    end

    test "is true for the character", %{entity: entity} do
      assert true == Militerm.Systems.Entity.is?(entity, "living")
    end
  end

  describe "can sit" do
    test "is true for the character", %{entity: entity} do
      assert true == Militerm.Systems.Entity.can?(entity, "sit", "actor", %{})
    end
  end
end
