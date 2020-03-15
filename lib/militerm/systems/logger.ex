defmodule Militerm.Systems.Logger do
  require Logger
  use Militerm.ECS.System

  alias Militerm.Systems.Entity

  @doc """
  Puts a string in the system debug log. Someday, this will send the message to a debug
  channel for the controlling user.
  """
  defscript debug(message), for: objects do
    if is_binary(message) do
      Logger.debug(message, to_keywords(objects))
    else
      Logger.debug(inspect(message), to_keywords(objects))
    end

    true
  end

  defscript info(message), for: objects do
    Logger.info(message, to_keywords(objects))
    true
  end

  defscript warn(message), for: objects do
    Logger.warn(message, to_keywords(objects))
    true
  end

  defscript error(message), for: objects do
    Logger.error(message, to_keywords(objects))
    true
  end

  defcommand debug(str), for: %{"this" => this} = args do
    Entity.receive_message(this, "cmd", "Switch debugging to #{str}", args)
  end

  defp to_keywords(objects) do
    objects
    |> Enum.map(fn
      {k, v} when is_atom(k) -> {k, v}
      {k, v} when is_binary(k) -> {String.to_atom(k), v}
    end)
  end
end
