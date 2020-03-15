defmodule Militerm.Systems.IdentityTest do
  use Militerm.DataCase, async: false

  alias Militerm.Components
  alias Militerm.Systems.Identity

  setup do
    Components.Details.clear()
    %{}
  end

  doctest Identity
end
