defmodule Game.TraitsTest do
  use Militerm.DataCase, async: false

  alias Militerm.Test.{Entity, Scene}

  setup do
    Scene.new("scene:test:area:start", "std:scene", %{
      detail: %{
        "default" => %{
          "short" => "a short place",
          "sight" => "A short place with not much stature.",
          "exits" => %{
            "north" => %{
              "target" => "scene:test:area:north"
            }
          }
        },
        "floor" => %{
          "short" => "the floor",
          "sight" => "Broad planks of wood form a solid floor."
        }
      }
    })

    Scene.new("scene:test:area:north", "std:scene", %{
      detail: %{
        "default" => %{
          "short" => "a tall place",
          "sight" => "A tall place with much stature.",
          "exits" => %{
            "south" => %{
              "target" => "scene:test:area:start"
            }
          }
        }
      }
    })

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

  describe "is player" do
    test "is true for the character", %{entity: entity} do
      assert true == Militerm.Systems.Entity.is?(entity, "player")
    end
  end

  describe "is living" do
    test "has the flag set for a character", %{entity: entity} do
      assert true == Militerm.Systems.Entity.property(entity, ~w"flag living", %{})
    end

    test "is true for the character", %{entity: entity} do
      assert true == Militerm.Systems.Entity.is?(entity, "living")
    end

    test "is false for a scene" do
      assert false == Militerm.Systems.Entity.is?({:thing, "scene:test:area:start"}, "living")
    end
  end
end
