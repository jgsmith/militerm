defmodule Militerm.Command.Plugs.Aliases do
  def run(%{input: input, entity: entity} = request, _) do
    {:cont, %{request | input: Militerm.Services.Aliases.expand(entity, input)}}
  end

  def run(_, _), do: :cont
end
