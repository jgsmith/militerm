defmodule Militerm.Services.LocationTest do
  use Militerm.DataCase, async: false

  alias Militerm.Components.Details
  alias Militerm.Components.Location, as: LocationComponent
  alias Militerm.Services.Location

  setup do
    Details.clear()
    %{}
  end

  doctest Location
end
