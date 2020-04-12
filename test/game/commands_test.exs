defmodule Game.CommandsTest do
  use Militerm.DataCase, async: false

  alias Militerm.Test.{Entity}

  setup do
    Militerm.Systems.Entity.whereis({:thing, "scene:test:area:start"})

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
    test "Scene is loaded and running" do
      assert not is_nil(Militerm.Systems.Entity.whereis({:thing, "scene:test:area:start"}))
    end
  end

  describe "look at the floor" do
    test "matches something", %{entity: entity} do
      entity
      |> Entity.send_input("look at the floor")
      |> Entity.await_event("pre-finish:verb")
      |> Entity.get_output()
    end
  end

  describe "move near the table" do
    test "moves", %{entity: entity} do
      entity
      |> Entity.send_input("move near the table")
      |> Entity.await_event("pre-finish:verb")
      |> Entity.get_output()

      final_location = Militerm.Services.Location.where(entity)
      assert final_location == {"near", {:thing, "scene:test:area:start", "table"}}
    end
  end
end
