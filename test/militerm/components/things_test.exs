defmodule Militerm.Components.ThingsTest do
  use Militerm.DataCase, async: false

  alias Militerm.Components.{Things}

  setup do
    Things.reset()
    %{}
  end

  doctest Things

  describe "setting things" do
    test "setting a path to a single entity allows retrieval of that single entity" do
      Things.set_value("foo", ["owner"], {:thing, "bar"})
      assert Things.get_value("foo", ["owner"]) == {:thing, "bar"}
    end
  end
end
