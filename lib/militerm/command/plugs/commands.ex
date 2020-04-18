defmodule Militerm.Command.Plugs.Commands do
  def run(%{entity: entity, input: <<"@", input::binary>>, context: context} = info, _) do
    {command, rest} =
      case String.split(input, " ", parts: 2) do
        [command] -> {command, ""}
        [command, rest] -> {command, rest}
      end

    case Militerm.Services.Commands.command_handler(command) do
      {:ok, {module, function, args}} ->
        apply(module, function, [rest, %{"this" => entity}])
        :handled

      _ ->
        {:cont, Map.put(info, :error, "Unknown command: #{input}")}
    end
  end

  def run(_, _), do: :cont
end
