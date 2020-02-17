defmodule Militerm.Components.EphemeralFlag do
  use Militerm.ECS.Component, default: MapSet.new(), ephemeral: true

  @moduledoc """
  Ephemeral flags are used during run-time and aren't appropriate for saving across restarts.
  These are useful to coordinate command execution.
  """

  def set_value(entity_id, path, value, _args) do
    {path, sense} =
      Enum.reduce(path, {[], if(value, do: true, else: false)}, fn p, {ps, s} ->
        case p do
          "not_" <> f -> {[f | ps], !s}
          f -> {[f | ps], s}
        end
      end)

    path = path |> Enum.reverse() |> Enum.join(":")

    if sense do
      add_flag(entity_id, path)
    else
      remove_flag(entity_id, path)
    end
  end

  def reset_value(entity_id, path, args) do
    set_value(entity_id, path, false, args)
  end

  def get_value(entity_id, path, _args) do
    {path, sense} =
      Enum.reduce(path, {[], true}, fn p, {ps, s} ->
        case p do
          "not_" <> f -> {[f | ps], !s}
          f -> {[f | ps], s}
        end
      end)

    if get_raw_value(entity_id, path |> Enum.reverse() |> Enum.join(":")), do: sense, else: !sense
  end

  def get_raw_value(entity_id, flag), do: flag_set?(entity_id, flag)

  def add_flag(entity_id, flags) when is_list(flags) do
    update(entity_id, fn
      nil -> MapSet.new(flags)
      set -> Enum.reduce(flags, set, fn f, s -> MapSet.put(s, f) end)
    end)
  end

  def add_flag(entity_id, flag) do
    update(entity_id, fn
      nil -> MapSet.new([flag])
      set -> MapSet.put(set, flag)
    end)
  end

  def remove_flag(entity_id, flags) when is_list(flags) do
    update(entity_id, fn
      nil -> nil
      set -> Enum.reduce(flags, set, fn f, s -> MapSet.delete(s, f) end)
    end)
  end

  def remove_flag(entity_id, flag) do
    update(entity_id, fn
      nil -> nil
      set -> MapSet.delete(set, flag)
    end)
  end

  def flag_set?(entity_id, flag) do
    case get(entity_id) do
      nil -> false
      set -> MapSet.member?(set, flag)
    end
  end

  def hibernate(_entity_id), do: :ok
  def unhibernate(_entity_id), do: :ok
end
