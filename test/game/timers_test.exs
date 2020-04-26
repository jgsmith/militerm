defmodule Game.TimersTest do
  use Militerm.DataCase, async: false

  alias Militerm.Test.{Entity}

  setup do
    Militerm.Systems.Entity.whereis({:thing, "scene:test:area:start"})

    entity =
      Entity.new("std:character", %{
        detail: %{
          "default" => %{
            "short" => "a typical human",
            "nouns" => ["human", "sue"],
            "adjectives" => ["typical"]
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

    torch =
      Entity.new("std:torch", %{
        detail: %{
          "default" => %{
            "short" => "a torch",
            "nouns" => ["torch"]
          }
        },
        identity: %{
          "nominative" => "it",
          "possessive" => "its",
          "objective" => "it"
        }
      })

    Militerm.Services.Location.place(torch, {"in", {:thing, "scene:test:area:start", "default"}})

    {:ok, entity: entity, torch: torch}
  end

  describe "setup" do
    test "Scene is loaded and running" do
      assert not is_nil(Militerm.Systems.Entity.whereis({:thing, "scene:test:area:start"}))
    end
  end

  describe "look at the torch" do
    @tag diegetic: true
    test "matches something", %{entity: entity} do
      entity
      |> Entity.send_input("look at the torch")
      |> Entity.get_output()
    end
  end

  describe "light the torch" do
    @tag diegetic: true
    test "lights it", %{entity: entity, torch: torch} do
      entity
      |> Entity.send_input("light the torch")

      Process.sleep(2000)

      entity
      |> Entity.get_output()

      assert Militerm.Systems.Entity.property(torch, ~w[resource torch fuel], %{"this" => torch}) <
               100
    end

    @tag diegetic: true
    test "lights the scene", %{entity: entity, torch: torch} do
      scene = {:thing, "scene:test:area:start"}

      assert Militerm.Systems.Entity.is?(torch, "lit", %{"this" => torch}) != true

      assert Militerm.Systems.Entity.property(scene, ~w[flag is-darkened], %{"this" => scene}) ==
               true

      assert Militerm.Systems.Entity.is?(scene, "dark", %{"this" => scene}) == true

      entity
      |> Entity.send_input("light the torch")

      assert Militerm.Systems.Entity.is?(torch, "lit", %{"this" => torch})
      assert !Militerm.Systems.Entity.is?(scene, "dark", %{"this" => scene})
    end
  end
end
