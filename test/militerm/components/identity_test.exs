defmodule Militerm.Components.IdentityTest do
  use Militerm.DataCase, async: false

  alias Militerm.Components.{Identity}

  setup do
    Identity.reset()
    %{}
  end

  doctest Identity
end
