defmodule Militerm.MML do
  @moduledoc """
  Parses MML into a data structure that can be used to output dynamic content.

  Generally, this is used in item descriptions or other lightly dynamic content.

  See Militerm.If.Builders.MML for information on building up the data structures needed
  to output MML.

    ```
    living_description = Parsers.MML("<this> is <this.position> here")
    non_living_description = Parsers.MML("<this> is <this.position> here")

    inventory = Services.Location.inventory_visible_to(location, actor)
    tag("Room", [], [
      tag("RoomDescription", [], [
        Parsers.MML.parse(Component.Description.get_description(location)),
      ]),
      tag("Inventory", [type: "Living"], [
        inventory
        |> Enum.filter(&Component.Living.living?/1)
        |> Enum.reject(fn id -> id == actor end)
        |> Enum.map(fn id ->
          apply_mml(living_description, %{this: id})
        end)
      ]),
      tag("Inventory", [type: "Books"], [
        inventory
        |> Enum.filter(&Component.Books.book?/1)
        |> Enum.map(fn id ->
          apply_mml(non_living_description, %{this: id})
        end)
      ]),
      ...
      tag("Exits", [], [ ... ])
    ], %{this: location})
    ```
  """

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
    {:ok, {:bound, message, slots}}
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

  @doc """
  Processes the bound message for the entity in the given slot. All this does is substitute
  values from the slots. It doesn't do anything that would produce something like HTML or
  plain text.
  """
  def render_slots(entity_id, {:bound, message, slots}) do
    render_slots(entity_id, message, slots)
  end

  def render_slots(entity_id, message, slots, acc \\ [])

  def render_slots(_, [], _, acc), do: Enum.reverse(acc)

  # by default, the name
  def render_slots(entity_id, [{:slot, slot} | rest], slots, acc) do
    thing_ids =
      case Map.get(slots, slot, []) do
        list when is_list(list) -> list
        thing_id -> [thing_id]
      end

    value =
      thing_ids
      |> Enum.map(fn
        {entity_id, detail} when is_binary(detail) ->
          Components.Details.get_short(entity_id, detail)

        entity_id ->
          Components.Details.get_short(entity_id, "default")
      end)
      |> Militerm.English.item_list()

    render_slots(entity_id, rest, slots, [value | acc])
  end

  def render_slots(entity_id, [{:value, slot} | rest], slots, acc) do
    value = Map.get(slots, slot, "")
    render_slots(entity_id, rest, slots, [value | acc])
  end

  def render_slots(entity_id, [{:bound, sub_message, sub_slots} | rest], slots, acc) do
    render_slots(entity_id, rest, slots, [render_slots(entity_id, sub_message, sub_slots) | acc])
  end

  def render_slots(entity_id, [{:tag, attributes, nodes} | rest], slots, acc) do
    render_slots(entity_id, rest, slots, [
      {:tag, render_attribute_slots(entity_id, attributes, slots),
       render_slots(entity_id, nodes, slots)}
      | acc
    ])
  end

  def render_slots(entity_id, [node | rest], slots, acc) do
    render_slots(entity_id, rest, slots, [node | acc])
  end

  def render_attribute_slots(entity_id, list, slots) do
    list
    |> Enum.map(fn
      {:attributes, attributes} ->
        attributes
        |> Enum.map(fn {k, v} ->
          {k, render_slots(entity_id, v, slots)}
        end)

      pair ->
        pair
    end)
  end

  @doc """
  The ~M sigil parses the string and returns an object that can be used directly to output an
  appropriate message to a group of entities with correct point of view interpolations as well
  as other useful markup.

  The only slots recognized by default are: this, actor, direct, indirect, instrumental, here, hence, whence.

  ## Examples

    iex> ~M"<direct> <do> not fit in <indirect>."
    [{:slot, "direct"}, " ", {:verb, "do"}, " not fit in ", {:slot, "indirect"}, "."]

    iex> ~M'{command send="look at <direct>"}<direct>{/command}'
    [{:tag, [name: "command", attributes: [{"send", ["look at ", {:slot, "direct"}]}]], [{:slot, "direct"}]}]

    iex> ~M'{title}{{title}}{/title}'
    [{:tag, [name: "title"], [script: {"title", :get_context_var}]}]
  """
  def sigil_M(binary, opts) do
    Militerm.Parsers.MML.parse!(binary)
  end
end
