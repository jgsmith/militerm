defmodule Militerm.Systems.Commands do
  @moduledoc """
  The Commands system parses user input in two categories: commands, starting with an
  at symbol (@), and narrative, not starting with an at symbol. Narrative commands
  start with a verb and take place within the game storyline. Commands take place outside
  of the game world.

  For example, consulting a map could be considered an in-game action if it is based on
  information or inventory of the character. If it's considered a free feature that everyone
  has regardless of in-game experience, then it might be an out-of-game command.

  On the other hand, managing a terminal's colors is an out-of-game (or out-of-character)
  action, and thus a command rather than a verb.
  """

  alias Militerm.Command.Pipeline

  require Logger

  def perform(entity, input, context) do
    debug(entity, [": perform [", input, "]"])

    %{input: normalize(input), entity: entity, context: context}
    |> Pipeline.run_pipeline(Pipeline.pipeline(:players))
    |> interpret_pipeline_results()
  end

  def interpret_pipeline_results(%{error: message, entity: entity, state: state} = result)
      when state in ~w[unhandled error]a do
    debug(entity, [": perform ", to_string(state), " - ", inspect(message)])

    Militerm.Systems.Entity.receive_message(
      entity,
      "error:command",
      "{red}{{message}}{/red}",
      %{"message" => message}
    )

    result
  end

  def interpret_pipeline_results(result), do: result

  def debug({:thing, entity_id}, msg) do
    Logger.debug([entity_id, msg])
  end

  def debug({:thing, entity_id, _}, msg) do
    Logger.debug([entity_id, msg])
  end

  defp normalize(string) do
    string
    |> String.trim()
    |> String.downcase()
    |> String.split(~r{\s+}, trim: true)
    |> Enum.join(" ")
  end
end
