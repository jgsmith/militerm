defmodule Militerm.Systems.Script do
  alias Militerm.Services

  require Logger

  def call_function(function_name, args, objects) do
    arity = Enum.count(args)

    case Services.Script.function_handler(function_name, arity) do
      {:ok, {module, fctn, extra_args}} ->
        apply(module, fctn, args ++ [objects] ++ extra_args)

      _ ->
        Logger.warn("Unable to find #{function_name}/#{arity}")
        nil
    end
  end
end
