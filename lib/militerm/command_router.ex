defmodule Militerm.CommandRouter do
  @moduledoc ~S"""
  Provides a plan for how to route command handling.

  For example, to add a command handler for things starting with an "@":
      scope "@" do
        handler CommandHandler
      end

  Handling modules are called in the order declared.
  """

  defmacro __using__(opts) do
    quote do
      import Militerm.CommandRouter
    end
  end

  defmacro handler(module, opts \\ []) do
  end

  defmacro scope(prefix, opts \\ []) do
  end
end
