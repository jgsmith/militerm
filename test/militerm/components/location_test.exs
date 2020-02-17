defmodule Militerm.Components.LocationTest do
  use Militerm.DataCase, async: false

  alias Militerm.Components.{Details, Location}
  alias Militerm.Services.Location, as: LocationService

  setup do
    Details.reset()
    Location.reset()
    %{}
  end

  doctest Location
end
