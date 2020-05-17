defmodule Militerm.Systems.Archetypes do
  @moduledoc """
  The Archetypes system manages running code defined in an archetype and inspecting aspects
  of the archetype.

  The public API uses the entity_id rather than an archetype name. The system expects
  the archetype for the entity to be available from the Entity component.
  """

  alias Militerm.Services.Archetypes
  alias Militerm.Systems.Mixins

  require Logger

  def list_archetypes() do
    Militerm.Services.Archetypes.list_archetypes()
  end

  def introspect(archetype) do
    data = Archetypes.get(archetype)

    if map_size(data) > 0 do
      ur_data =
        case data do
          %{ur_name: ur_name} when not is_nil(ur_name) ->
            introspect(data.ur_name)

          _ ->
            %{}
        end

      data.mixins
      |> Enum.reverse()
      |> Enum.reduce(ur_data, fn mixin, acc ->
        deep_merge(acc, Mixins.introspect(mixin))
      end)
      |> deep_merge(%{
        calculations: keys_with_attribution(data.calculations, archetype),
        reactions: keys_with_attribution(data.reactions, archetype),
        abilities: keys_with_attribution(data.abilities, archetype),
        traits: keys_with_attribution(data.traits, archetype),
        validators: keys_with_attribution(data.validators, archetype)
      })
    else
      %{}
    end
  end

  defp deep_merge(into, from) when is_map(into) and is_map(from) do
    Map.merge(into, from, fn _k, v1, v2 -> deep_merge(v1, v2) end)
  end

  defp deep_merge(v1, v2), do: v2

  defp keys_with_attribution(map, attr) do
    map
    |> Map.keys()
    |> Enum.map(fn k -> {k, attr} end)
    |> Enum.into(%{})
  end

  def execute_event(entity_id, event, role, args) when is_binary(event) do
    path = event |> String.split(":", trim: true) |> Enum.reverse()
    execute_event(entity_id, path, role, args)
  end

  def execute_event(entity_id, event, role, args) when is_binary(entity_id) do
    case get_entity_archetype(entity_id) do
      {:ok, {_archetype_name, _archetype} = archetype} ->
        execute_event(archetype, entity_id, event, role, args)

      _ ->
        false
    end
  end

  def execute_event({archetype_name, archetype}, entity_id, path, role, args) do
    cond do
      do_has_event?(archetype, path, role) ->
        Logger.debug(fn ->
          [
            entity_id,
            " (",
            archetype_name,
            ") has event ",
            Enum.join(Enum.reverse(path), ":"),
            " as ",
            role,
            ": true"
          ]
        end)

        do_event(archetype, entity_id, path, role, args)

      do_has_event?(archetype, path, "any") ->
        Logger.debug(fn ->
          [
            entity_id,
            " (",
            archetype_name,
            ") has event ",
            Enum.join(Enum.reverse(path), ":"),
            " as any: true"
          ]
        end)

        do_event(archetype, entity_id, path, "any", args)

      :else ->
        Logger.debug(fn ->
          [
            entity_id,
            " (",
            archetype_name,
            ") has event ",
            Enum.join(Enum.reverse(path), ":"),
            " as ",
            role,
            ": false"
          ]
        end)

        false
    end
  end

  def has_event?({_archetype_name, archetype}, event, role) do
    do_has_event?(archetype, event, role)
  end

  def has_event?(entity_id, event, role) when is_binary(event) do
    path = event |> String.split(":", trim: true) |> Enum.reverse()
    has_event?(entity_id, path, role)
  end

  def has_event?(entity_id, event, role) do
    case get_entity_archetype(entity_id) do
      {:ok, {_archetype_name, archetype}} ->
        do_has_event?(archetype, event, role)

      _ ->
        false
    end
  end

  def has_exact_event?(entity_id, event, role) when is_binary(event) do
    path = event |> String.split(":", trim: true) |> Enum.reverse()
    has_exact_event?(entity_id, path, role)
  end

  def has_exact_event?(entity_id, event, role) when is_binary(entity_id) do
    case get_entity_archetype(entity_id) do
      {:ok, {_archetype_name, _archetype} = archetype} ->
        has_exact_event?(archetype, event, role)

      _ ->
        false
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
    case get_entity_archetype(entity_id) do
      {:ok, {_archetype_name, _archetype} = architype} ->
        ability(architype, entity_id, ability, role, args)

      _ ->
        false
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
    case get_entity_archetype(entity_id) do
      {:ok, {archetype_name, archetype}} ->
        do_has_ability?(archetype, ability, role) or do_has_ability?(archetype, ability, "any")

      _ ->
        false
    end
  end

  def has_exact_ability?(entity_id, ability, role) when is_binary(ability) do
    path = ability |> String.split(":", trim: true) |> Enum.reverse()
    has_exact_ability?(entity_id, path, role)
  end

  def has_exact_ability?(entity_id, ability, role) when is_binary(entity_id) do
    case get_entity_archetype(entity_id) do
      {:ok, {_archetype_name, _archetype} = architype} ->
        has_exact_ability?(architype, ability, role)

      _ ->
        false
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
    case get_entity_archetype(entity_id) do
      {:ok, {archetype_name, archetype}} ->
        do_has_trait?(archetype, trait)

      _ ->
        false
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
    case get_entity_archetype(entity_id) do
      {:ok, {_archetype_name, archetype}} ->
        has_validation?(archetype, path)

      _ ->
        false
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
    case get_entity_archetype(entity_id) do
      {:ok, {_, archetype}} ->
        do_validation(archetype, entity_id, path, Map.put(args, "value", value))

      _ ->
        nil
    end
  end

  defp do_validation(archetype, entity_id, path, args) do
    case archetype do
      %{validations: validations, mixins: mixins, ur_name: ur} ->
        handled =
          validations
          |> execute_if_in_map(entity_id, path, args)
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

      _ ->
        nil
    end
  end

  def calculates?(entity_id, path) do
    case get_entity_archetype(entity_id) do
      {:ok, {_archetype_name, archetype}} ->
        has_calculation?(archetype, path)

      _ ->
        false
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
    case get_entity_archetype(entity_id) do
      {:ok, {_, archetype}} ->
        do_calculation(archetype, entity_id, path, args)

      _ ->
        nil
    end
  end

  def do_calculation({_, archetype}, entity_id, path, args) do
    do_calculation(archetype, entity_id, path, args)
  end

  def do_calculation(archetype, entity_id, path, args) do
    case archetype do
      %{calculations: calculations, mixins: mixins, ur_name: ur} ->
        handled =
          calculations
          |> execute_if_in_map(entity_id, path, args)
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

      _ ->
        nil
    end
  end

  defp do_event(_, _, [], _, _), do: true

  defp do_event(archetype, entity_id, event, role, args) do
    case archetype do
      %{reactions: events, mixins: mixins, ur_name: ur} ->
        handled =
          events
          |> execute_if_in_map(entity_id, event, role, args)
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

      _ ->
        false
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
    case archetype do
      %{reactions: events, mixins: mixins, ur_name: ur} ->
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

      _ ->
        false
    end
  end

  defp do_ability(_, _, [], _, _), do: false

  defp do_ability(archetype, entity_id, ability, role, args) do
    case archetype do
      %{abilities: abilities, mixins: mixins, ur_name: ur} ->
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

      _ ->
        false
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
    case archetype do
      %{abilities: abilities, mixins: mixins, ur_name: ur} ->
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

      _ ->
        false
    end
  end

  defp do_trait(archetype, entity_id, trait, args) do
    case archetype do
      %{traits: traits, mixins: mixins, ur_name: ur} ->
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

      _ ->
        false
    end
  end

  defp do_has_trait?(_, ""), do: false

  defp do_has_trait?(nil, _), do: false

  defp do_has_trait?(archetype, trait) do
    do_has_exact_trait?(archetype, trait)
  end

  defp do_has_exact_trait?(archetype, trait) do
    case archetype do
      %{traits: traits, mixins: mixins, ur_name: ur} ->
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

      _ ->
        false
    end
  end

  defp execute_if_in_map(events, entity_id, event, role, args) do
    case Map.get(events, {event, role}) do
      code when is_tuple(code) ->
        # IO.inspect({:code, event, role, code}, limit: :infinity)
        Logger.debug(fn ->
          [
            entity_id,
            ": execute code for ",
            inspect(event),
            " as ",
            role,
            ": ",
            inspect(code, limit: :infinity)
          ]
        end)

        ret =
          {:ok, Militerm.Machines.Script.run(code, Map.put(args, "this", {:thing, entity_id}))}

        Logger.debug([entity_id, ": finished executing code for ", inspect(event), " as ", role])
        ret

      _ ->
        :unhandled
    end
  end

  defp execute_if_in_map(events, entity_id, path, args) do
    case Map.get(events, path) do
      code when is_tuple(code) ->
        Logger.debug(fn ->
          [entity_id, ": execute code for ", inspect(path), ": ", inspect(code, limit: :infinity)]
        end)

        ret =
          {:ok, Militerm.Machines.Script.run(code, Map.put(args, "this", {:thing, entity_id}))}

        Logger.debug([entity_id, ": finished executing code for ", inspect(path)])
        ret

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
        Logger.debug([entity_id, " handing off ", inspect(event), " as ", role, " to ", mixin])
        {:ok, apply(Mixins, method, [mixin, entity_id, event, role, args])}
    end
  end

  defp execute_if_mixin({:ok, _} = result, _, _, _, _, _, _), do: result

  defp execute_if_mixin(:unhandled, mixins, predicate, method, entity_id, event, args) do
    case Enum.find(mixins, fn mixin -> apply(Mixins, predicate, [mixin, event]) end) do
      nil ->
        :unhandled

      mixin ->
        Logger.debug([entity_id, " handing off ", inspect(event), " to ", mixin])
        {:ok, apply(Mixins, method, [mixin, entity_id, event, args])}
    end
  end

  defp execute_if_archetype({:ok, _} = result, _, _, _, _, _, _, _), do: result

  defp execute_if_archetype(status, nil, _, _, _, _, _, _), do: status

  defp execute_if_archetype(:unhandled, ur, predicate, method, entity_id, event, role, args) do
    case Archetypes.get(ur) do
      %{} = archetype ->
        if apply(__MODULE__, predicate, [{ur, archetype}, event, role]) do
          Logger.debug([entity_id, " handing off ", inspect(event), " as ", role, " to ", ur])
          {:ok, apply(__MODULE__, method, [{ur, archetype}, entity_id, event, role, args])}
        else
          :unhandled
        end

      _ ->
        :unhandled
    end
  end

  defp execute_if_archetype({:ok, _} = result, _, _, _, _, _, _), do: result

  defp execute_if_archetype(status, nil, _, _, _, _, _), do: status

  defp execute_if_archetype(:unhandled, ur, predicate, method, entity_id, event, args) do
    case Archetypes.get(ur) do
      %{} = archetype ->
        if apply(__MODULE__, predicate, [{ur, archetype}, event]) do
          Logger.debug([entity_id, " handing off ", inspect(event), " to ", ur])
          {:ok, apply(__MODULE__, method, [{ur, archetype}, entity_id, event, args])}
        else
          :unhandled
        end

      _ ->
        :unhandled
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
