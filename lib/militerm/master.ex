defmodule Militerm.Master do
  @moduledoc ~S"""
  The Master module provides a central place to define the parts of the game engine.
  This includes the pipeline for processing commands, the different services used, and any
  components.
  """

  defmacro __using__(opts) do
    quote do
      import Militerm.Master
    end
  end

  defmacro component(name, module, opts \\ []) do
  end

  defmacro system(module, opts \\ []) do
  end
end
