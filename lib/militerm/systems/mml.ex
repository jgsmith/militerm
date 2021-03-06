defmodule Militerm.Systems.MML do
  @moduledoc """
  Manages the rendering handlers for MML tags for different device contexts.
  """

  use Militerm.ECS.System

  alias Militerm.Services.MML, as: MMLService
  alias Militerm.Parsers.MML, as: MMLParser

  @doc """
  Accepts output and forwards it to the registered interfaces. Eventually, this will
  cache output until the closing matching tag or an explicit flush at the end of the
  event handling cycle.
  """
  defscript emit(content), for: %{"this" => this} = objects do
    Militerm.Systems.Entity.receive_message(this, "emit", content, objects)
    true
  end

  defscript prompt(content), for: %{"this" => this} = objects do
    Militerm.Systems.Entity.receive_message(this, "prompt", content, objects)
    true
  end

  defscript item_list(content), as: "ItemList" do
    if is_nil(content) do
      "nothing"
    else
      content
      |> Enum.reject(&is_nil/1)
      |> Militerm.English.item_list()
    end
  end

  defscript item_list(content, conjunction), as: "ItemList" do
    if is_nil(content) do
      "nothing"
    else
      content
      |> Enum.reject(&is_nil/1)
      |> Militerm.English.item_list(conjunction)
    end
  end

  @doc """
  Bind the given slots to the message. This allows the message to be embedded in other
  messages while keeping track of what goes in which slot for this message.
  """
  def bind(message, slots) when is_binary(message) do
    case Militerm.Parsers.MML.parse(message) do
      {:ok, p} -> {:ok, {:bound, p, slots}}
      otherwise -> otherwise
    end
  end

  def bind(message, slots) when is_list(message) do
    result =
      Enum.reduce_while(message, [], fn line, acc ->
        case bind(line, slots) do
          {:ok, binding} -> {:cont, [binding | acc]}
          {:error, error} -> {:halt, {:error, error}}
        end
      end)

    case result do
      {:error, _} -> result
      list -> {:ok, {:bound, Enum.reverse(list), %{}}}
    end
  end

  def bind({:bound, _, _} = binding, _), do: {:ok, binding}

  def bind!(message, slots) do
    case bind(message, slots) do
      {:ok, binding} -> binding
      {:error, error} -> raise error
    end
  end

  def used_slots({:bound, message, _}), do: used_slots(message)

  def used_slots([], slots), do: Enum.uniq(Enum.reverse(slots))

  def used_slots([{:slot, slot} | rest], slots) do
    used_slots(rest, [slot | slots])
  end

  def used_slots([{:slot, slot, _} | rest], slots) do
    used_slots(rest, [slot | slots])
  end

  def used_slots([{:tag, attributes, nodes} | rest], slots) do
    # attributes first, then nodes
    used_slots(
      rest,
      used_slots_in_attributes(attributes) ++ used_slots(nodes) ++ slots
    )
  end

  def used_slots([_ | rest], slots), do: used_slots(rest, slots)

  def used_slots_in_attributes(attributes) do
    case Keyword.fetch(attributes, :attributes) do
      {:ok, list} ->
        list
        |> Enum.flat_map(fn {_, value} -> used_slots(value) end)
        |> Enum.uniq()

      _ ->
        []
    end
  end

  def render({:bound, parse, bindings}, pov, device) do
    parse
    |> Enum.map(fn item -> render_item(item, bindings, pov, device) end)
  end

  def render({:bound, parse, bindings}, pov, device) do
    parse
    |> Enum.map(fn item -> render_item(item, bindings, pov, device) end)
  end

  def render({parse, bindings}, pov, device) do
    parse
    |> Enum.map(fn item -> render_item(item, bindings, pov, device) end)
  end

  def render_item(string, _, _, _) when is_binary(string), do: string

  def render_item(nil, _, _, _), do: ""

  def render_item(list, bindings, pov, device) when is_list(list) do
    list
    |> Enum.map(&render_item(&1, bindings, pov, device))
  end

  def render_item({:script, code}, bindings, pov, device) do
    code
    |> Militerm.Machines.Script.run(bindings)
    |> render_item(bindings, pov, device)
  end

  def render_item({:error, message}, _bindings, _pov, _device) do
    "(ERROR: #{inspect(message)})"
  end

  def render_item({:thing, _} = thing, _bindings, pov, _device) do
    entity_name(thing, pov)
  end

  def render_item({:thing, _, _} = thing, _bindings, pov, _device) do
    entity_name(thing, pov)
  end

  def render_item({:bound, _, _} = binding, _bindings, pov, device) do
    render(binding, pov, device)
  end

  def render_item({:value, name}, bindings, pov, device) do
    render_item(Map.get(bindings, name, ""), bindings, pov, device)
  end

  def render_item({:verb, verb}, bindings, pov, _device) do
    objs = as_list(Map.get(bindings, "actor", []))

    if pov not in objs and Enum.count(objs) == 1 do
      Militerm.English.pluralize(verb)
    else
      verb
    end
  end

  def render_item({:verb, slot, verb}, bindings, pov, _device) do
    objs = Map.get(bindings, to_string(slot), [])

    if pov not in objs and Enum.count(objs) == 1 do
      Militerm.English.pluralize(verb)
    else
      verb
    end
  end

  def render_item({:Verb, verb}, bindings, pov, _device) do
    objs = Map.get(bindings, "actor", [])

    if pov not in objs and Enum.count(objs) == 1 do
      String.capitalize(Militerm.English.pluralize(verb))
    else
      String.capitalize(verb)
    end
  end

  def render_item({:Verb, slot, verb}, bindings, pov, _device) do
    objs = Map.get(bindings, to_string(slot), [])

    if pov not in objs and Enum.count(objs) == 1 do
      String.capitalize(Militerm.English.pluralize(verb))
    else
      String.capitalize(verb)
    end
  end

  def render_item({:tag, attributes, nodes}, bindings, pov, device) do
    with {:ok, name} <- Keyword.fetch(attributes, :name),
         {:ok, {module, function, args}} <- MMLService.tag_handler(name, device) do
      apply(module, function, [attributes, nodes, bindings, pov, device] ++ args)
    else
      otherwise ->
        render({nodes, bindings}, pov, device)
    end
  end

  def render_item({:slot, slot, type}, bindings, pov, _device) do
    this = Map.get(bindings, "this")

    case Map.get(bindings, to_string(slot)) do
      nil ->
        "nothing"

      [] ->
        "nothing"

      list when is_list(list) ->
        list
        |> Enum.map(&entity_name(&1, pov, type))
        |> Militerm.English.item_list()

      thing when is_tuple(thing) ->
        entity_name(thing, pov)
    end
  end

  def render_item({:slot, slot}, bindings, pov, _device) do
    this = Map.get(bindings, "this")

    case Map.get(bindings, to_string(slot)) do
      nil ->
        "nothing"

      [] ->
        "nothing"

      list when is_list(list) ->
        list
        |> Enum.map(&entity_name(&1, pov))
        |> Militerm.English.item_list()

      thing when is_tuple(thing) ->
        entity_name(thing, pov)
    end
  end

  def render_item({:Slot, slot, type}, bindings, pov, _device) do
    this = Map.get(bindings, "this")

    case Map.get(bindings, to_string(slot)) do
      nil ->
        "Nothing"

      [] ->
        "Nothing"

      list when is_list(list) ->
        list
        |> Enum.map(&entity_name(&1, pov, type))
        |> Militerm.English.item_list()
        |> String.capitalize()

      thing when is_tuple(thing) ->
        String.capitalize(entity_name(thing, pov))
    end
  end

  def render_item({:Slot, slot}, bindings, pov, _device) do
    this = Map.get(bindings, "this")

    case Map.get(bindings, to_string(slot)) do
      nil ->
        "Nothing"

      [] ->
        "Nothing"

      list when is_list(list) ->
        list
        |> Enum.map(&entity_name(&1, pov))
        |> Militerm.English.item_list()
        |> String.capitalize()

      thing when is_tuple(thing) ->
        String.capitalize(entity_name(thing, pov))
    end
  end

  defp as_list(list) when is_list(list), do: list
  defp as_list(nil), do: []
  defp as_list(value), do: [value]

  defp entity_name(pov, pov), do: "you"

  defp entity_name({:thing, entity_id} = it, pov) do
    entity_name_by_identity(entity_id) || entity_name_by_details(entity_id) || entity_id
  end

  defp entity_name({:thing, entity_id, detail}, _) when is_binary(detail) do
    entity_name_by_details({entity_id, detail}) || entity_id
  end

  defp entity_name(string, _) when is_binary(string), do: string

  defp entity_name({:thing, entity_id} = it, _, "name") do
    entity_name_by_identity(entity_id) || entity_name_by_details(entity_id) || "something"
  end

  defp entity_name({:thing, entity_id, detail} = it, _, "name") do
    entity_name_by_details({entity_id, detail}) || "something"
  end

  defp entity_name(string, _, "name") when is_binary(string), do: string

  defp entity_name(pov, pov, "nominative"), do: "you"
  defp entity_name(pov, pov, "objective"), do: "you"
  defp entity_name(pov, pov, "reflexive"), do: "yourself"
  defp entity_name(pov, pov, "possessive"), do: "your"

  defp entity_name(thing, _, "nominative"), do: entity_nominative(thing)
  defp entity_name(thing, _, "objective"), do: entity_objective(thing)
  defp entity_name(thing, _, "reflexive"), do: entity_reflexive(thing)
  defp entity_name(thing, _, "possessive"), do: entity_possessive(thing)

  defp entity_nominative({:thing, entity_id}) do
    case Militerm.Components.Identity.get(entity_id) do
      %{"nominative" => nom} -> nom
      _ -> "it"
    end
  end

  defp entity_nominative({:thing, entity_id, "default"}) do
    entity_nominative({:thing, entity_id})
  end

  defp entity_nominative(_), do: "it"

  defp entity_objective({:thing, entity_id}) do
    case Militerm.Components.Identity.get(entity_id) do
      %{"objective" => obj} -> obj
      _ -> "it"
    end
  end

  defp entity_objective({:thing, entity_id, "default"}) do
    entity_objective({:thing, entity_id})
  end

  defp entity_objective(_), do: "it"

  defp entity_possessive({:thing, entity_id}) do
    case Militerm.Components.Identity.get(entity_id) do
      %{"possessive" => pos} -> pos
      _ -> "its"
    end
  end

  defp entity_possessive({:thing, entity_id, "default"}) do
    entity_possessive({:thing, entity_id})
  end

  defp entity_possessive(_), do: "its"

  def entity_reflexive(thing) do
    entity_objective(thing) <> "self"
  end

  defp entity_name_by_identity({entity_id, _}) do
    entity_name_by_identity(entity_id)
  end

  defp entity_name_by_identity(entity_id) do
    case Militerm.Components.Identity.get(entity_id) do
      %{"name" => name} -> name
      _ -> nil
    end
  end

  defp entity_name_by_details(entity_id) when is_binary(entity_id) do
    entity_name_by_details({entity_id, "default"})
  end

  defp entity_name_by_details({entity_id, detail}) do
    case Militerm.Components.Details.get(entity_id, detail) do
      %{"short" => name} ->
        name

      _ ->
        if detail == "default", do: nil, else: entity_name_by_details({entity_id, "default"})
    end
  end
end
