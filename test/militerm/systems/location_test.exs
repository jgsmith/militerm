defmodule Militerm.Systems.LocationTest do
  use Militerm.DataCase, async: false

  alias Militerm.Components
  alias Militerm.Systems.Location

  setup do
    Components.Details.clear()
    %{}
  end

  doctest Location
end
