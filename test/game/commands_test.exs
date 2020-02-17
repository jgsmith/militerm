defmodule Game.CommandsTest do
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
          "sight" => "Broad planks of wood form a solid floor.",
          "related_to" => "default",
          "related_by" => "in",
          "nouns" => ["floor"],
          "adjectives" => []
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
  end

  describe "look at the floor" do
    test "matches something", %{entity: entity} do
      entity
      |> Entity.send_input("look at the floor")
      |> Entity.await_event("post-scan:item:brief")
      |> Entity.get_output()
      |> IO.inspect()
    end
  end
end
