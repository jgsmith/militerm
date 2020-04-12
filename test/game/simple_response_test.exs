defmodule Game.SimpleResponseTest do
  use Militerm.DataCase, async: false

  alias Militerm.Test.{Entity}
  alias Militerm.Systems.Entity, as: EntitySystem

  @elevator_id "scene:test:area:elevator"
  @elevator {:thing, @elevator_id}

  setup do
    Militerm.Systems.Entity.whereis(@elevator)

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

    Militerm.Services.Location.place(entity, {"in", {:thing, @elevator_id, "default"}})

    {:ok, entity: entity}
  end

  describe "setup" do
    test "Scene is loaded and running" do
      assert not is_nil(Militerm.Systems.Entity.whereis(@elevator))
    end

    test "calculates the exit" do
      assert EntitySystem.calculates?(@elevator, "detail:default:exits:out:target")

      assert EntitySystem.property(@elevator, ~w[trait elevator-level], %{"this" => @elevator}) ==
               "1"

      assert EntitySystem.property(@elevator, ~w[detail default exits out target], %{
               "this" => @elevator
             }) == {:thing, "scene:test:area:start", "default"}
    end
  end

  describe "the elevator hears things" do
    @tag diegetic: true
    test "saying a level", %{entity: entity} do
      entity
      |> Entity.send_input("say take me to level 2")
      |> Entity.await_event("action:done")
      |> Entity.get_output()
    end
  end
end
