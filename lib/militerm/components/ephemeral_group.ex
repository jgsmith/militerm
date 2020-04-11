defmodule Militerm.Components.EphemeralGroup do
  use Militerm.ECS.Component, default: MapSet.new(), ephemeral: true

  @moduledoc """
  Ephemeral groups are used to determine if a player has permission to do something.
  These groups are only used for player characters. Only those groups to which the player belongs
  will be allowed to be set.
  """

  def set_value(_, ["players"], _), do: false

  def set_value(entity_id, [group], value) do
    if Militerm.Accounts.is_group_allowed?(entity_id, group) do
      if value do
        add_flag(entity_id, group)
      else
        remove_flag(entity_id, group)
      end
    end
  end

  def set_value(_, _, _), do: false

  def reset_value(entity_id, path), do: set_value(entity_id, path, false)

  def remove_value(entity_id, path), do: reset_value(entity_id, path)

  def get_value(entity_id, [group]), do: get_raw_value(entity_id, group)

  def get_value(_, _), do: false

  def get_raw_value(entity_id, group), do: flag_set?(entity_id, group)

  def get_groups(entity_id) do
    case get(entity_id) do
      nil -> []
      set -> ["players" | MapSet.to_list(set)]
    end
  end

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

  def remove_all_flags(entity_id) do
    update(entity_id, fn
      nil -> nil
      _ -> MapSet.new()
    end)
  end

  def flag_set?(entity_id, flag) do
    case get(entity_id) do
      nil -> false
      set -> MapSet.member?(set, flag)
    end
  end

  def hibernate(entity_id) do
    # removes all flags for the entity
    remove_all_flags(entity_id)
  end

  def unhibernate(_entity_id), do: :ok
end
