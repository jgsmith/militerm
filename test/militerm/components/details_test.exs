defmodule Militerm.Components.DetailsTest do
  use Militerm.DataCase, async: false

  alias Militerm.Components.{Details, Location}

  setup do
    Details.reset()
    Location.reset()
    %{}
  end

  doctest Details
end
