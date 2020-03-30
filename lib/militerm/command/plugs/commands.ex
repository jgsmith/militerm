defmodule Militerm.Command.Plugs.Commands do
  def run(%{entity: entity, input: <<"@", input::binary>>, context: context} = info, _) do
    with [command | rest] <- String.split(input, " ", parts: 2),
         {:ok, {module, function, args}} <- Militerm.Services.Commands.command_handler(command) do
      apply(module, function, [rest, %{"this" => entity}])
      :handled
    else
      _ ->
        {:cont, Map.put(info, :error, "Unknown command: #{input}")}
    end
  end

  def run(_, _), do: :cont
end
