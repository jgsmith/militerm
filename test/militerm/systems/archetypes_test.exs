defmodule Militerm.Systems.ArchetypesTest do
  use Militerm.DataCase, async: false

  alias Militerm.Components
  alias Militerm.Systems.Archetypes
  alias Militerm.Entities.Thing

  setup do
    Components.Entity.clear()
    Thing.create("test1", "std:test1", [])
    %{}
  end

  doctest Archetypes

  describe "has_event?" do
    test "is true when archetype has the event" do
      assert Archetypes.has_event?("test1", "some:event", "actor")
    end

    test "is true when archetype has the parent event" do
      assert Archetypes.has_event?("test1", "some:event:foo", "actor")
    end
  end

  describe "has_exact_event?" do
    test "is true when the archetype has the event exactly" do
      assert true == Archetypes.has_exact_event?("test1", "some:event", "actor")
    end

    test "is false when the archetype doesn't have the exact event" do
      assert false == Archetypes.has_exact_event?("test1", "some:event:foo", "actor")
    end

    test "is true when a mixin has the exact event" do
      assert true == Archetypes.has_exact_event?("test1", "some:other:event", "actor")
    end
  end

  describe "execute_event" do
    test "exact event handler runs" do
      assert "Some Event" == Archetypes.execute_event("test1", "some:event", "actor", %{})
    end

    test "exact event handler in mixin runs" do
      assert "Some Other Event" ==
               Archetypes.execute_event("test1", "some:other:event", "actor", %{})
    end

    test "parent event handler runs" do
      assert "Some Event" == Archetypes.execute_event("test1", "some:event:foo", "actor", %{})
    end
  end

  describe "has_ability?" do
    test "is true when a mixin has the ability" do
      assert true == Archetypes.has_ability?("test1", "toot", "actor")
    end

    test "is true when a mixin has a parent ability" do
      assert true == Archetypes.has_ability?("test1", "toot:far:and:wide", "direct")
    end
  end

  describe "ability" do
    test "is true for toot" do
      assert true == Archetypes.ability("test1", "toot", "actor", %{})
    end

    test "is true for toot:far:and:wide" do
      assert true == Archetypes.ability("test1", "toot:far:and:wide", "direct", %{})
    end
  end

  describe "inheritence" do
    test "sees traits in ur archetype" do
      assert true == Archetypes.ability("test1", "boat", "actor", %{})
    end
  end
end
