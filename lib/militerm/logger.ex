defmodule Militerm.Logger do
  require Logger

  @levels ~w[emergancy alert critical error warning notice info debug]a

  def debug(msg), do: Logger.debug(msg)

  def debug(entity, class, msg) do
    maybe_log(:debug, class, entity, msg)
  end

  def debug(class, msg) do
    maybe_log(:debug, class, nil, msg)
  end

  def entity_id(binary) when is_binary(binary), do: binary
  def entity_id({:thing, id}), do: id
  def entity_id({:thing, id, _}), do: id
  def entity_id(nil), do: "-"

  defp maybe_log(level, class, entity, f) when is_function(f) do
    if logging_class?(class) do
      Logger.bare_log(level, fn ->
        msg =
          case f.() do
            list when is_list(list) -> list
            s when is_binary(s) -> [s]
            otherwise -> [inspect(otherwise)]
          end

        [class, "//", entity_id(entity), ": ", msg]
      end)
    end
  end

  defp maybe_log(level, class, entity, msg) do
    if logging_class?(class) do
      Logger.bare_log(level, fn ->
        [class, "//", entity_id(entity), ": ", msg]
      end)
    end
  end

  defp logging_class?(class) do
    logging_class?(class, true, Militerm.Config.get_debug_classes())
  end

  defp logging_class?(_, default, config) when map_size(config) == 0, do: default

  defp logging_class?(class, default, config) do
    cond do
      Map.has_key?(config, class) ->
        Map.get(config, class)

      String.contains?(class, ":") ->
        class
        |> String.replace(~r{:[^:]*$}, global: false)
        |> logging_class?(default, config)

      :else ->
        default
    end
  end
end
