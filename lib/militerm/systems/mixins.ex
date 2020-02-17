defmodule Militerm.Systems.Mixins do
  @moduledoc """
  The Mixins system manages running code defined in a mixin and inspecting aspects
  of the mixin.
  """

  alias Militerm.Services.Mixins

  def execute_event(name, entity_id, event, role, args) when is_binary(event) do
    path = event |> String.split(":", trim: true) |> Enum.reverse()
    execute_event(name, entity_id, path, role, args)
  end

  def execute_event(name, entity_id, path, role, args) do
    with {:ok, mixin} <- get_mixin(name) do
      cond do
        do_has_event?(mixin, path, role) ->
          do_event(mixin, entity_id, path, role, args)

        do_has_event?(mixin, path, "any") ->
          do_event(mixin, entity_id, path, "any", args)

        :else ->
          false
      end
    else
      _ ->
        false
    end
  end

  def has_event?(name, event, role) when is_binary(event) do
    path = event |> String.split(":", trim: true) |> Enum.reverse()
    has_event?(name, path, role)
  end

  def has_event?(name, path, role) do
    with {:ok, mixin} <- get_mixin(name) do
      do_has_event?(mixin, path, role)
    else
      _ -> false
    end
  end

  def has_exact_event?(name, event, role) when is_binary(event) do
    path = event |> String.split(":", trim: true) |> Enum.reverse()
    has_exact_event?(name, path, role)
  end

  def has_exact_event?(name, path, role) do
    with {:ok, mixin} <- get_mixin(name) do
      do_has_exact_event?(mixin, path, role)
    else
      _ -> false
    end
  end

  def ability(name, entity_id, ability, role, args) when is_binary(ability) do
    path = ability |> String.split(":", trim: true) |> Enum.reverse()
    ability(name, entity_id, path, role, args)
  end

  def ability(name, entity_id, ability, role, args) do
    with {:ok, mixin} <- get_mixin(name) do
      if role == "any" or do_has_ability?(mixin, ability, role) do
        do_ability(mixin, entity_id, ability, role, args)
      else
        do_ability(mixin, entity_id, ability, "any", args)
      end
    end
  end

  def has_ability?(name, ability, role) when is_binary(ability) do
    path = ability |> String.split(":", trim: true) |> Enum.reverse()
    has_ability?(name, path, role)
  end

  def has_ability?(name, ability, role) do
    with {:ok, mixin} <- get_mixin(name) do
      do_has_ability?(mixin, ability, role) or do_has_ability?(mixin, ability, "any")
    else
      _ -> false
    end
  end

  def has_exact_ability?(name, ability, role) when is_binary(ability) do
    path = ability |> String.split(":", trim: true) |> Enum.reverse()
    has_exact_ability?(name, path, role)
  end

  def has_exact_ability?(name, ability, role) do
    with {:ok, mixin} <- get_mixin(name) do
      do_has_exact_ability?(mixin, ability, role)
    else
      _ -> false
    end
  end

  def trait(name, entity_id, trait, args) do
    with {:ok, mixin} <- get_mixin(name) do
      if do_has_trait?(mixin, trait) do
        do_trait(mixin, entity_id, trait, args)
      else
        false
      end
    end
  end

  def has_trait?(name, trait) do
    with {:ok, mixin} <- get_mixin(name) do
      do_has_trait?(mixin, trait)
    else
      _ -> false
    end
  end

  def has_exact_trait?(name, trait) do
    with {:ok, mixin} <- get_mixin(name) do
      do_has_exact_trait?(mixin, trait)
    else
      _ -> false
    end
  end

  def validates?(name, path) do
    with {:ok, mixin} <- get_mixin(name) do
      has_validation?(mixin, path)
    else
      _ -> false
    end
  end

  def has_validation?(%{validations: validations, mixins: mixins}, path) do
    cond do
      Map.has_key?(validations, path) ->
        true

      Enum.any?(mixins, fn mixin -> Mixins.validates?(mixin, path) end) ->
        true

      :else ->
        false
    end
  end

  def has_validation?(_, _), do: false

  def validate(name, entity_id, path, args) do
    with {:ok, mixin} <- get_mixin(name) do
      do_validation(mixin, entity_id, path, args)
    else
      _ -> nil
    end
  end

  defp do_validation(mixin, entity_id, path, args) do
    with %{validations: validations, mixins: mixins} <- mixin do
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

      case handled do
        {:ok, value} -> value
        _ -> nil
      end
    else
      _ -> nil
    end
  end

  def calculates?(name, path) do
    with {:ok, mixin} <- get_mixin(name) do
      has_calculation?(mixin, path)
    else
      _ -> false
    end
  end

  def has_calculation?(%{calculations: calculations, mixins: mixins}, path) do
    cond do
      Map.has_key?(calculations, path) ->
        true

      Enum.any?(mixins, fn mixin -> Mixins.calculates?(mixin, path) end) ->
        true

      :else ->
        false
    end
  end

  def has_calculation?(_, _), do: false

  def calculate(name, entity_id, path, args) do
    with {:ok, mixin} <- get_mixin(name) do
      do_calculation(mixin, entity_id, path, args)
    else
      _ -> nil
    end
  end

  defp do_calculation(mixin, entity_id, path, args) do
    with %{calculations: calculations, mixins: mixins} <- mixin do
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

      case handled do
        {:ok, value} -> value
        _ -> nil
      end
    else
      _ -> nil
    end
  end

  defp do_event(_, _, [], _, _), do: true

  defp do_event(mixin, entity_id, event, role, args) do
    with %{reactions: events, mixins: mixins} <- mixin do
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

      case handled do
        {:ok, value} ->
          value

        otherwise ->
          otherwise
      end
    else
      _ -> false
    end
  end

  defp do_has_event?(_, [], _), do: false

  defp do_has_event?(nil, _, _), do: false

  defp do_has_event?(mixin, event, role) do
    if do_has_exact_event?(mixin, event, role) do
      true
    else
      #  chop off the last bit and run again - remember, we've reversed the event bits
      do_has_event?(mixin, Enum.drop(event, 1), role)
    end
  end

  defp do_has_exact_event?(nil, _, _), do: false

  defp do_has_exact_event?(mixin, event, role) do
    with %{reactions: events, mixins: mixins} <- mixin do
      if Map.has_key?(events, {event, role}) do
        true
      else
        # check mixins
        Enum.any?(mixins, fn name ->
          has_exact_event?(name, event, role)
        end)
      end
    else
      _ ->
        false
    end
  end

  defp do_ability(_, _, [], _, _), do: false

  defp do_ability(mixin, entity_id, ability, role, args) do
    with %{abilities: abilities, mixins: mixins} <- mixin do
      handled =
        execute_if_in_map(abilities, entity_id, ability, role, args)
        |> execute_if_mixin(
          mixins,
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
          do_ability(mixin, entity_id, Enum.drop(ability, 1), role, args)
      end
    else
      _ -> false
    end
  end

  defp do_has_ability?(_, [], _), do: false

  defp do_has_ability?(nil, _, _), do: false

  defp do_has_ability?(mixin, ability, role) do
    if do_has_exact_ability?(mixin, ability, role) do
      true
    else
      #  chop off the last bit and run again - remember, we've reversed the event bits
      do_has_ability?(mixin, Enum.drop(ability, 1), role)
    end
  end

  defp do_has_exact_ability?(mixin, ability, role) do
    with %{abilities: abilities, mixins: mixins} <- mixin do
      cond do
        Map.has_key?(abilities, {ability, role}) ->
          true

        Enum.any?(mixins, fn name -> has_exact_ability?(name, ability, role) end) ->
          true

        :else ->
          false
      end
    else
      _ ->
        false
    end
  end

  defp do_trait(mixin, entity_id, trait, args) do
    with %{traits: traits, mixins: mixins} <- mixin do
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

  defp do_has_trait?(mixin, trait) do
    do_has_exact_trait?(mixin, trait)
  end

  defp do_has_exact_trait?(mixin, trait) do
    with %{traits: traits, mixins: mixins} <- mixin do
      cond do
        Map.has_key?(traits, trait) ->
          true

        Enum.any?(mixins, fn mixin -> Mixins.has_exact_trait?(mixin, trait) end) ->
          true

        :else ->
          false
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

  defp execute_if_in_map(events, entity_id, event, args) do
    case Map.get(events, event) do
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

  defp get_mixin(name) do
    with %{} = mixin <- Mixins.get(name) do
      {:ok, mixin}
    else
      _ ->
        :error
    end
  end
end
