defmodule Militerm.Systems.Archetypes do
  @moduledoc """
  The Archetypes system manages running code defined in an archetype and inspecting aspects
  of the archetype.

  The public API uses the entity_id rather than an archetype name. The system expects
  the archetype for the entity to be available from the Entity component.
  """

  alias Militerm.Services.Archetypes
  alias Militerm.Systems.Mixins

  def list_archetypes() do
    Militerm.Services.Archetypes.list_archetypes()
  end

  def execute_event(entity_id, event, role, args) when is_binary(event) do
    path = event |> String.split(":", trim: true) |> Enum.reverse()
    execute_event(entity_id, path, role, args)
  end

  def execute_event(entity_id, event, role, args) when is_binary(entity_id) do
    with {:ok, {_archetype_name, _archetype} = archetype} <- get_entity_archetype(entity_id) do
      execute_event(archetype, entity_id, event, role, args)
    else
      _ -> false
    end
  end

  def execute_event({_archetype_name, archetype}, entity_id, path, role, args) do
    cond do
      do_has_event?(archetype, path, role) ->
        do_event(archetype, entity_id, path, role, args)

      do_has_event?(archetype, path, "any") ->
        do_event(archetype, entity_id, path, "any", args)

      :else ->
        false
    end
  end

  def has_event?(entity_id, event, role) when is_binary(event) do
    path = event |> String.split(":", trim: true) |> Enum.reverse()
    has_event?(entity_id, path, role)
  end

  def has_event?(entity_id, event, role) do
    with {:ok, {archetype_name, archetype}} <- get_entity_archetype(entity_id) do
      do_has_event?(archetype, event, role)
    else
      _ -> false
    end
  end

  def has_exact_event?(entity_id, event, role) when is_binary(event) do
    path = event |> String.split(":", trim: true) |> Enum.reverse()
    has_exact_event?(entity_id, path, role)
  end

  def has_exact_event?(entity_id, event, role) when is_binary(entity_id) do
    with {:ok, {_archetype_name, _archetype} = archetype} <- get_entity_archetype(entity_id) do
      has_exact_event?(archetype, event, role)
    else
      _ -> false
    end
  end

  def has_exact_event?({_archetype_name, archetype}, event, role) do
    do_has_exact_event?(archetype, event, role)
  end

  def ability(entity_id, ability, role, args) when is_binary(ability) do
    path = ability |> String.split(":", trim: true) |> Enum.reverse()
    ability(entity_id, path, role, args)
  end

  def ability(entity_id, ability, role, args) when is_binary(entity_id) do
    with {:ok, {_archetype_name, _archetype} = architype} <- get_entity_archetype(entity_id) do
      ability(architype, entity_id, ability, role, args)
    else
      _ -> false
    end
  end

  def ability(archetype, entity_id, ability, role, args) when is_binary(ability) do
    path = ability |> String.split(":", trim: true) |> Enum.reverse()
    ability(archetype, entity_id, path, role, args)
  end

  def ability({archetype_name, archetype}, entity_id, ability, role, args) do
    if role == "any" or do_has_ability?(archetype, ability, role) do
      do_ability(archetype, entity_id, ability, role, args)
    else
      do_ability(archetype, entity_id, ability, "any", args)
    end
  end

  def has_ability?(entity_id, ability, role) when is_binary(ability) do
    path = ability |> String.split(":", trim: true) |> Enum.reverse()
    has_ability?(entity_id, path, role)
  end

  def has_ability?(entity_id, ability, role) do
    with {:ok, {archetype_name, archetype}} <- get_entity_archetype(entity_id) do
      do_has_ability?(archetype, ability, role) or do_has_ability?(archetype, ability, "any")
    else
      _ -> false
    end
  end

  def has_exact_ability?(entity_id, ability, role) when is_binary(ability) do
    path = ability |> String.split(":", trim: true) |> Enum.reverse()
    has_exact_ability?(entity_id, path, role)
  end

  def has_exact_ability?(entity_id, ability, role) when is_binary(entity_id) do
    with {:ok, {_archetype_name, _archetype} = architype} <- get_entity_archetype(entity_id) do
      has_exact_ability?(architype, ability, role)
    else
      _ -> false
    end
  end

  def has_exact_ability?({archetype_name, archetype}, ability, role) do
    do_has_exact_ability?(archetype, ability, role) or
      do_has_exact_ability?(archetype, ability, "any")
  end

  def trait({:thing, entity_id}, trait, args) do
    trait(entity_id, trait, args)
  end

  def trait(entity_id, trait, args) when is_binary(entity_id) do
    trait(get_entity_archetype(entity_id), entity_id, trait, args)
  end

  def trait({:ok, {_, archetype}}, entity_id, trait, args) do
    if do_has_trait?(archetype, trait) do
      do_trait(archetype, entity_id, trait, args)
    end
  end

  def trait({_, archetype}, entity_id, trait, args) do
    if do_has_trait?(archetype, trait) do
      do_trait(archetype, entity_id, trait, args)
    end
  end

  def trait(_, _, _, _), do: false

  def has_trait?(entity_id, trait) do
    with {:ok, {archetype_name, archetype}} <- get_entity_archetype(entity_id) do
      do_has_trait?(archetype, trait)
    else
      _ -> false
    end
  end

  def has_exact_trait?({:thing, entity_id}, trait) do
    entity_id
    |> get_entity_archetype()
    |> has_exact_trait?(trait)
  end

  def has_exact_trait?(entity_id, trait) when is_binary(entity_id) do
    entity_id
    |> get_entity_archetype()
    |> has_exact_trait?(trait)
  end

  def has_exact_trait?({:ok, {_, archetype}}, trait) do
    do_has_exact_trait?(archetype, trait)
  end

  def has_exact_trait?({_, archetype}, trait) do
    do_has_exact_trait?(archetype, trait)
  end

  def has_exact_trait?(archetype, trait) when is_map(archetype) do
    do_has_exact_trait?(archetype, trait)
  end

  def has_exact_trait?(_, _), do: false

  def validates?(entity_id, path) do
    with {:ok, {_archetype_name, archetype}} <- get_entity_archetype(entity_id) do
      has_validation?(archetype, path)
    else
      _ -> false
    end
  end

  def has_validation?(%{validations: validations, mixins: mixins, ur_name: ur}, path) do
    cond do
      Map.has_key?(validations, path) ->
        true

      Enum.any?(mixins, fn mixin -> Mixins.validates?(mixin, path) end) ->
        true

      is_nil(ur) ->
        false

      :else ->
        has_validation?(Archetypes.get(ur), path)
    end
  end

  def has_validation?(_, _), do: false

  def validate(entity_id, path, value, args) do
    with {:ok, {_, archetype}} <- get_entity_archetype(entity_id) do
      do_validation(archetype, entity_id, path, Map.put(args, "value", value))
    else
      _ -> nil
    end
  end

  defp do_validation(archetype, entity_id, path, args) do
    with %{validations: validations, mixins: mixins, ur_name: ur} <- archetype do
      handled =
        execute_if_in_map(validations, entity_id, path, args)
        |> execute_if_mixin(
          mixins,
          :has_validation?,
          :validate,
          entity_id,
          path,
          args
        )
        |> execute_if_archetype(
          ur,
          :has_validation?,
          :validate,
          entity_id,
          path,
          args
        )

      case handled do
        {:ok, value} -> value
        _ -> nil
      end
    else
      _ -> nil
    end
  end

  def calculates?(entity_id, path) do
    with {:ok, {_archetype_name, archetype}} <- get_entity_archetype(entity_id) do
      has_calculation?(archetype, path)
    else
      _ -> false
    end
  end

  def has_calculation?({_, archetype}, path), do: has_calculation?(archetype, path)

  def has_calculation?(%{calculations: calculations, mixins: mixins, ur_name: ur}, path) do
    cond do
      Map.has_key?(calculations, path) ->
        true

      Enum.any?(mixins, fn mixin -> Mixins.calculates?(mixin, path) end) ->
        true

      is_nil(ur) ->
        false

      :else ->
        has_calculation?(Archetypes.get(ur), path)
    end
  end

  def has_calculation?(_, _), do: false

  def calculate(entity_id, path, args) do
    with {:ok, {_, archetype}} <- get_entity_archetype(entity_id) do
      do_calculation(archetype, entity_id, path, args)
    else
      _ -> nil
    end
  end

  def do_calculation({_, archetype}, entity_id, path, args) do
    do_calculation(archetype, entity_id, path, args)
  end

  def do_calculation(archetype, entity_id, path, args) do
    with %{calculations: calculations, mixins: mixins, ur_name: ur} <- archetype do
      handled =
        execute_if_in_map(calculations, entity_id, path, args)
        |> execute_if_mixin(
          mixins,
          :calculates?,
          :calculate,
          entity_id,
          path,
          args
        )
        |> execute_if_archetype(
          ur,
          :has_calculation?,
          :do_calculation,
          entity_id,
          path,
          args
        )

      case handled do
        {:ok, value} -> value
        _ -> nil
      end
    else
      _ ->
        nil
    end
  end

  defp do_event(_, _, [], _, _), do: true

  defp do_event(archetype, entity_id, event, role, args) do
    with %{reactions: events, mixins: mixins, ur_name: ur} <- archetype do
      handled =
        execute_if_in_map(events, entity_id, event, role, args)
        |> execute_if_mixin(
          mixins,
          :has_exact_event?,
          :execute_event,
          entity_id,
          event,
          role,
          args
        )
        |> execute_if_archetype(
          ur,
          :has_exact_event?,
          :execute_event,
          entity_id,
          event,
          role,
          args
        )

      case handled do
        {:ok, value} ->
          value

        _ ->
          do_event(archetype, entity_id, Enum.drop(event, 1), role, args)
      end
    else
      _ -> false
    end
  end

  defp do_has_event?(_, [], _), do: false

  defp do_has_event?(nil, _, _), do: false

  defp do_has_event?(archetype, event, role) do
    if do_has_exact_event?(archetype, event, role) do
      true
    else
      #  chop off the last bit and run again - remember, we've reversed the event bits
      do_has_event?(archetype, Enum.drop(event, 1), role)
    end
  end

  defp do_has_exact_event?(nil, _, _), do: false

  defp do_has_exact_event?(archetype, event, role) do
    with %{reactions: events, mixins: mixins, ur_name: ur} <- archetype do
      cond do
        Map.has_key?(events, {event, role}) ->
          true

        Enum.any?(mixins, fn mixin -> Mixins.has_exact_event?(mixin, event, role) end) ->
          true

        is_nil(ur) ->
          false

        :else ->
          do_has_exact_event?(Archetypes.get(ur), event, role)
      end
    else
      _ ->
        false
    end
  end

  defp do_ability(_, _, [], _, _), do: false

  defp do_ability(archetype, entity_id, ability, role, args) do
    with %{abilities: abilities, mixins: mixins, ur_name: ur} <- archetype do
      handled =
        abilities
        |> execute_if_in_map(entity_id, ability, role, args)
        |> execute_if_mixin(
          mixins,
          :has_exact_ability?,
          :ability,
          entity_id,
          ability,
          role,
          args
        )
        |> execute_if_archetype(
          ur,
          :has_exact_ability?,
          :ability,
          entity_id,
          ability,
          role,
          args
        )

      case handled do
        {:ok, value} ->
          value

        _ ->
          do_ability(archetype, entity_id, Enum.drop(ability, 1), role, args)
      end
    else
      _ -> false
    end
  end

  defp do_has_ability?(_, [], _), do: false

  defp do_has_ability?(nil, _, _), do: false

  defp do_has_ability?(archetype, ability, role) do
    if do_has_exact_ability?(archetype, ability, role) do
      true
    else
      #  chop off the last bit and run again - remember, we've reversed the event bits
      do_has_ability?(archetype, Enum.drop(ability, 1), role)
    end
  end

  defp do_has_exact_ability?(archetype, ability, role) do
    with %{abilities: abilities, mixins: mixins, ur_name: ur} <- archetype do
      cond do
        Map.has_key?(abilities, {ability, role}) ->
          true

        Enum.any?(mixins, fn mixin -> Mixins.has_exact_ability?(mixin, ability, role) end) ->
          true

        is_nil(ur) ->
          false

        :else ->
          do_has_exact_ability?(Archetypes.get(ur), ability, role)
      end
    else
      _ ->
        false
    end
  end

  defp do_trait(archetype, entity_id, trait, args) do
    with %{traits: traits, mixins: mixins, ur_name: ur} <- archetype do
      handled =
        traits
        |> execute_if_in_map(entity_id, trait, args)
        |> execute_if_mixin(
          mixins,
          :has_exact_trait?,
          :trait,
          entity_id,
          trait,
          args
        )
        |> execute_if_archetype(
          ur,
          :has_exact_trait?,
          :trait,
          entity_id,
          trait,
          args
        )

      case handled do
        {:ok, value} ->
          value

        _ ->
          false
      end
    else
      _ -> false
    end
  end

  defp do_has_trait?(_, ""), do: false

  defp do_has_trait?(nil, _), do: false

  defp do_has_trait?(archetype, trait) do
    do_has_exact_trait?(archetype, trait)
  end

  defp do_has_exact_trait?(archetype, trait) do
    with %{traits: traits, mixins: mixins, ur_name: ur} <- archetype do
      cond do
        Map.has_key?(traits, trait) ->
          true

        Enum.any?(mixins, fn mixin -> Mixins.has_exact_trait?(mixin, trait) end) ->
          true

        is_nil(ur) ->
          false

        :else ->
          do_has_exact_trait?(Archetypes.get(ur), trait)
      end
    else
      _ ->
        false
    end
  end

  defp execute_if_in_map(events, entity_id, event, role, args) do
    case Map.get(events, {event, role}) do
      code when is_tuple(code) ->
        {:ok, Militerm.Machines.Script.run(code, Map.put(args, "this", {:thing, entity_id}))}

      _ ->
        :unhandled
    end
  end

  defp execute_if_in_map(events, entity_id, path, args) do
    case Map.get(events, path) do
      code when is_tuple(code) ->
        {:ok, Militerm.Machines.Script.run(code, Map.put(args, "this", {:thing, entity_id}))}

      _ ->
        :unhandled
    end
  end

  defp execute_if_mixin({:ok, _} = result, _, _, _, _, _, _, _), do: result

  defp execute_if_mixin(:unhandled, mixins, predicate, method, entity_id, event, role, args) do
    case Enum.find(mixins, fn mixin -> apply(Mixins, predicate, [mixin, event, role]) end) do
      nil ->
        :unhandled

      mixin ->
        {:ok, apply(Mixins, method, [mixin, entity_id, event, role, args])}
    end
  end

  defp execute_if_mixin({:ok, _} = result, _, _, _, _, _, _), do: result

  defp execute_if_mixin(:unhandled, mixins, predicate, method, entity_id, event, args) do
    case Enum.find(mixins, fn mixin -> apply(Mixins, predicate, [mixin, event]) end) do
      nil ->
        :unhandled

      mixin ->
        {:ok, apply(Mixins, method, [mixin, entity_id, event, args])}
    end
  end

  defp execute_if_archetype({:ok, _} = result, _, _, _, _, _, _, _), do: result

  defp execute_if_archetype(status, nil, _, _, _, _, _, _), do: status

  defp execute_if_archetype(:unhandled, ur, predicate, method, entity_id, event, role, args) do
    with %{} = archetype <- Archetypes.get(ur) do
      if apply(__MODULE__, predicate, [{ur, archetype}, event, role]) do
        {:ok, apply(__MODULE__, method, [{ur, archetype}, entity_id, event, role, args])}
      else
        :unhandled
      end
    else
      _ -> :unhandled
    end
  end

  defp execute_if_archetype({:ok, _} = result, _, _, _, _, _, _), do: result

  defp execute_if_archetype(status, nil, _, _, _, _, _), do: status

  defp execute_if_archetype(:unhandled, ur, predicate, method, entity_id, event, args) do
    with %{} = archetype <- Archetypes.get(ur) do
      if apply(__MODULE__, predicate, [{ur, archetype}, event]) do
        {:ok, apply(__MODULE__, method, [{ur, archetype}, entity_id, event, args])}
      else
        :unhandled
      end
    else
      _ -> :unhandled
    end
  end

  defp get_entity_archetype(entity_id) do
    with {:ok, archetype_name} <- Militerm.Components.Entity.archetype(entity_id),
         %{} = archetype <- Archetypes.get(archetype_name) do
      {:ok, {archetype_name, archetype}}
    else
      _ ->
        :error
    end
  end
end
