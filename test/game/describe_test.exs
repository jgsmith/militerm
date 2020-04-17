defmodule Game.DescribeTest do
  use Militerm.DataCase, async: false

  alias Militerm.Test.{Entity}

  setup do
    Militerm.Systems.Entity.whereis({:thing, "scene:test:area:start"})
    Militerm.Systems.Entity.whereis({:thing, "scene:test:area:north"})

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

    Militerm.Systems.Entity.event(entity, "enter:game", "actor", %{
      "this" => entity,
      "actor" => [entity]
    })

    {:ok, entity: entity}
  end

  describe "setup" do
    test "in the right location", %{entity: entity} do
      assert Militerm.Services.Location.where(entity) ==
               {"in", {:thing, "scene:test:area:start", "default"}}
    end

    test "triggers the scan:env:brief event", %{entity: entity} do
      entity
      |> Entity.await_event("scan:env:brief")
      |> Entity.get_output()
    end

    @tag unreliable: true
    test "with a north exit", %{entity: entity} do
      assert Militerm.Systems.Location.find_exits(entity) == ["north"]
    end

    test "with right entity metadata", %{entity: {:thing, entity_id}} do
      assert Militerm.Components.Entity.module(entity_id) == {:ok, Entity}
      assert Militerm.Components.Entity.archetype(entity_id) == {:ok, "std:character"}
    end
  end

  describe "look" do
    @tag diegetic: true
    test "gets the right event", %{entity: entity} do
      entity
      |> Entity.send_input("look")
      |> Entity.await_event("action:done")
      |> Entity.get_output()
    end
  end

  describe "go north" do
    @tag diegetic: true
    test "moves to the right scene", %{entity: entity} do
      entity
      |> Entity.send_input("go north")
      |> Entity.await_event("action:done")

      assert Militerm.Services.Location.where(entity) ==
               {"in", {:thing, "scene:test:area:north", "default"}}
    end
  end

  describe "caclculates foo:bar" do
    test "as 'Foo is Bar'", %{entity: entity} do
      assert Militerm.Systems.Entity.calculate(entity, "foo:bar", %{}) == "Foo is Bar"
    end
  end

  describe "caclculates trait:foo:bar from a mixin in an ur type" do
    test "as 'Trait Foo Bar'", %{entity: entity} do
      assert Militerm.Systems.Entity.calculate(entity, "trait:foo:bar", %{}) == "Trait Foo Bar"
    end
  end

  describe "calculates trait:allowed:positions" do
    test "as the default list", %{entity: entity} do
      assert Militerm.Systems.Entity.property(entity, ~w[trait allowed positions], %{
               "this" => entity
             }) == ~w[standing sitting kneeling crouching]
    end
  end
end
