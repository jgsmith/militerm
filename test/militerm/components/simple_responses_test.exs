defmodule Militerm.Components.SimpleResponsesTest do
  use Militerm.DataCase, async: false

  alias Militerm.Components.{SimpleResponses}
  alias Militerm.Data.SimpleResponses, as: SRRecord

  import Ecto.Query

  setup do
    SimpleResponses.reset()
    %{}
  end

  doctest SimpleResponses

  describe "setting response mapping" do
    test "setting the mapping adds the regex" do
      regex = Militerm.Parsers.SimpleResponse.parse("$_* hello $y*")

      SimpleResponses.set("foo", %{
        "test" => [
          %{"pattern" => "$_* hello $y*", "event" => "convo:greet"}
        ]
      })

      assert SimpleResponses.get_set("foo", "test") == [
               %{"pattern" => "$_* hello $y*", "event" => "convo:greet", "regex" => regex}
             ]
    end

    test "setting the mapping doesn't put the regex in the database" do
      SimpleResponses.set("foo", %{
        "test" => [
          %{"pattern" => "$x* hello $y*", "event" => "convo:greet"}
        ]
      })

      found_keys =
        SRRecord
        |> where([q], q.entity_id == "foo")
        |> Militerm.Repo.one!()
        |> Map.get(:data)
        |> Map.get("test")
        |> Enum.map(fn m -> m |> Map.keys() |> Enum.sort() end)

      assert found_keys == [~w[event pattern]]
    end
  end
end
