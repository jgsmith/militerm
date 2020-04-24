defmodule Militerm.Systems.Location do
  use Militerm.ECS.System

  alias Militerm.Systems.{Entity, Events}
  alias Militerm.Components
  alias Militerm.Services

  @doc """
  Returns the exit names appropriate for the current location of the object calling this function.
  """
  defscript exits(), for: %{"this" => this} = _objects do
    find_exits(this)
  end

  @doc """
  Returns the information for an exit.
  """
  defscript exit_(exit_name), for: %{"this" => this} = _objects, as: "Exit" do
    get_exit_info(exit_name, this)
  end

  def get_exit_info(list, this) when is_list(list) do
    list
    |> Enum.map(&get_exit_info(&1, this))
  end

  def get_exit_info(exit_name, this) do
    case Militerm.Services.Location.where(this) do
      {_, {:thing, target_id, detail}} when is_binary(detail) ->
        case Components.Details.get(target_id, detail) do
          %{"exits" => exits} = info ->
            if Map.has_key?(exits, exit_name) do
              Map.get(exits, exit_name)
            else
              case info do
                %{"related_to" => parent_detail} when not is_nil(parent_detail) ->
                  case Components.Details.get(target_id, parent_detail) do
                    %{"exits" => exits} = info ->
                      if Map.has_key?(exits, exit_name) do
                        Map.get(exits, exit_name)
                      else
                        nil
                      end

                    _ ->
                      nil
                  end

                _ ->
                  nil
              end
            end

          %{"related_to" => parent_detail} when not is_nil(parent_detail) ->
            case Components.Details.get(target_id, parent_detail) do
              %{"exits" => %{^exit_name => info}} ->
                info

              _ ->
                nil
            end

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  @doc """
  Describes the given _entity_ using the _sense_.

  It starts by stating the position/proximity/location of the entity.
  Then the detail:default:$sense for the entity.
  Then anything nearby the entity (thing -[_prox_]-> entity).

  Then a listing of entities visible on/in this entity (worn or visibly contained).
  If these entities have detail:default:extra, then that's added to the description and the entity is
  not included in the general inventory.

  This needs all data to be calculable rather than diving into the data directly.
  """
  defscript describe(entity), for: objects do
    do_describe("sight", entity, objects)
  end

  defscript describe(sense, entity), for: objects do
    do_describe(sense, entity, objects)
  end

  def do_describe(sense, things, objects) when is_list(things) do
    things
    |> Enum.map(&do_describe(sense, &1, objects))
    |> Enum.intersperse(" ")
  end

  def do_describe(sense, {:thing, entity_id}, objects) do
    do_describe(sense, {:thing, entity_id, "default"}, objects)
  end

  def do_describe(sense, {:thing, entity_id, detail} = this, objects) do
    placement = describe_placement(sense, this, objects)

    long = Militerm.Systems.Entity.property(this, ["detail", "default", sense], objects)

    [placement, " ", long]
    |> List.flatten()
    |> without_nils
    |> to_string
  end

  def do_describe(sense, thing, options) do
    ""
  end

  defp describe_placement("sight", thing, objects) do
    proximity = proximity(thing, objects)
    position = position(thing, objects)
    location = location(thing, objects)

    loc_short =
      Militerm.Systems.Entity.property(
        location,
        ~w[detail default short],
        Map.put(objects, "this", location)
      ) || "here"

    this_short = Militerm.Systems.Entity.property(thing, ~w[detail default short], objects)

    cardinality = Militerm.Systems.Entity.property(thing, ~w[detail default cardinality], objects)
    is = if cardinality == "plural", do: " are ", else: " is "

    without_nils([
      String.capitalize(this_short),
      is,
      position,
      " ",
      proximity,
      " ",
      loc_short,
      "."
    ])
  end

  defp describe_placement(_, _, _), do: ""

  defscript describe(), for: %{"this" => {:thing, this_id} = this} = objects do
    # exits = ["Obvious exits: ", Militerm.English.item_list(find_exits(this)), "."]
    {start, _, _} = start_sight_inventory(this, objects)
    to_string(["You are ", start])
  end

  def extra_look(sense, thing, objects) do
    objects = Map.put(objects, "this", thing)

    extra =
      Militerm.Systems.Entity.property(thing, ["detail", "default", "extra", sense], objects)

    if extra do
      this_short = Militerm.Systems.Entity.property(thing, ~w[detail default short], objects)
      proximity = proximity(thing, objects)
      position = position(thing, objects)
      location = location(thing, objects)

      loc_short =
        Militerm.Systems.Entity.property(
          location,
          ~w[detail default short],
          Map.put(objects, "this", location)
        ) || "here"

      without_nils([
        String.capitalize(this_short),
        " ",
        position,
        " ",
        proximity,
        " ",
        loc_short,
        " ",
        extra
      ])
    else
      nil
    end
  end

  def proximity({:thing, _} = thing, objects) do
    Militerm.Systems.Entity.property(thing, ~w[location proximity], objects)
  end

  def proximity({:thing, _, "default"} = thing, objects) do
    Militerm.Systems.Entity.property(thing, ~w[location proximity], objects)
  end

  def proximity({:thing, _, coord} = thing, objects) do
    Militerm.Systems.Entity.property(thing, ~w[detail default related_by], objects)
  end

  def position({:thing, _} = thing, objects) do
    Militerm.Systems.Entity.property(thing, ~w[location position], objects)
  end

  def position({:thing, _, "default"} = thing, objects) do
    Militerm.Systems.Entity.property(thing, ~w[location position], objects)
  end

  def position({:thing, _, coord} = thing, objects) do
    Militerm.Systems.Entity.property(thing, ~w[detail default position], objects)
  end

  def location({:thing, _} = thing, objects) do
    Militerm.Systems.Entity.property(thing, ~w[location location], objects)
  end

  def location({:thing, _, "default"} = thing, objects) do
    Militerm.Systems.Entity.property(thing, ~w[location location], objects)
  end

  def location({:thing, thing_id, coord} = thing, objects) do
    parent_coord = Militerm.Systems.Entity.property(thing, ~w[detail default related_to], objects)
    {:thing, thing_id, parent_coord}
  end

  def start_sight_inventory({:thing, this_id}, objects) do
    start_sight_inventory({:thing, this_id, "default"}, objects)
  end

  def start_sight_inventory({:thing, this_id, detail} = this, objects) do
    proximity = proximity(this, objects)
    position = position(this, objects)
    location = location(this, objects)

    loc_short =
      Militerm.Systems.Entity.property(
        location,
        ~w[detail default short],
        Map.put(objects, "this", location)
      ) || "here"

    start = without_nils([position, " ", proximity, " ", loc_short, "."])

    this_long =
      this
      |> Militerm.Systems.Entity.property(~w[detail default sight], objects)
      |> as_mml(Map.put(objects, "this", this))

    inventory = Militerm.Services.Location.find_near(location) -- [this]
    {to_string(start), this_long, inventory}
  end

  defscript describe_long(),
    for: %{"this" => {:thing, this_id} = this} = objects do
    {start, _, inventory} = start_sight_inventory(this, objects)

    location = location(this, objects)

    long =
      location
      |> Militerm.Systems.Entity.property(
        ~w[detail default sight],
        Map.put(objects, "this", location)
      )
      |> as_mml(Map.put(objects, "this", location))

    extras =
      inventory
      |> Enum.map(&extra_look("sight", &1, objects))
      |> without_nils()

    Enum.intersperse(["You are", start, long | extras], " ")
  end

  defscript describe_long(entity), for: %{"this" => {:thing, this_id} = this} = objects do
    thing = if is_list(entity), do: List.first(entity), else: entity

    placement = describe_placement("sight", thing, objects)

    long =
      thing
      |> Militerm.Systems.Entity.property(["detail", "default", "sight"], objects)
      |> as_mml(Map.put(objects, "this", thing))

    start =
      [placement, " ", long]
      |> List.flatten()
      |> without_nils

    location = location(thing, objects)

    inventory = Militerm.Services.Location.find_in(location) -- [thing]

    extras =
      inventory
      |> Enum.map(&extra_look("sight", &1, objects))
      |> without_nils()

    Enum.intersperse([start | extras], " ")
  end

  defp initial_capital(<<first_letter::binary-1, rest::binary>>) do
    String.capitalize(first_letter) <> rest
  end

  @doc """
  Returns the inventory of `this`.
  """
  defscript inventory(), for: %{"this" => this} = objects do
    excluding = Map.get(objects, "actor", [])
    excluding = if is_list(excluding), do: excluding, else: [excluding]

    inventory = Militerm.Services.Location.find_in(this)

    extra_items =
      inventory
      |> Enum.map(&{&1, extra_look("sight", &1, objects)})

    extra_exclusions =
      extra_items
      |> Enum.reject(fn {_, x} -> is_nil(x) end)
      |> Enum.map(&elem(&1, 0))

    describe_inventory(this, [this | excluding ++ extra_exclusions])
  end

  @doc """
  Returns the inventory of the given entity.
  """
  defscript inventory(entity), for: %{"this" => this} = objects do
    excluding = Map.get(objects, "actor", [])

    excluding = if is_list(excluding), do: excluding, else: [excluding]

    inventory = Militerm.Services.Location.find_in(this)

    extra_items =
      inventory
      |> Enum.map(&{&1, extra_look("sight", &1, objects)})

    extra_exclusions =
      extra_items
      |> Enum.reject(fn {_, x} -> is_nil(x) end)
      |> Enum.map(&elem(&1, 0))

    describe_inventory(entity, [entity | excluding ++ extra_exclusions])
  end

  defscript present(string), for: %{"this" => this} = _objects do
  end

  defscript present(string, env), for: %{"this" => this} = _objects do
  end

  defscript move_to(class, entity_id, prep, target_id, coord),
    for: %{"this" => this},
    as: "MoveTo" do
    case entity_id do
      [thing | _] ->
        move_to(class, thing, prep, target_id, coord, this)

      thing ->
        move_to(class, thing, prep, target_id, coord, this)
    end
  end

  defscript move_to(class, thing, default_prox, target),
    for: %{"this" => this} = _objects,
    as: "MoveTo" do
    case prox_target(target, default_prox) do
      {prox, target_id, target_coord} ->
        case thing do
          [one_thing | _] ->
            move_to(class, one_thing, prox, target_id, target_coord, this)

          one_thing ->
            move_to(class, one_thing, prox, target_id, target_coord, this)
        end

      nil ->
        nil
    end
  end

  defscript move_to(class, default_prox, target), for: %{"this" => this} = _objects, as: "MoveTo" do
    case prox_target(target, default_prox) do
      {prox, target_id, target_coord} ->
        move_to(class, this, prox, target_id, target_coord, this)

      nil ->
        nil
    end
  end

  defp as_mml(nil, _), do: ""

  defp as_mml(string, objects) do
    case Militerm.Systems.MML.bind(string, objects) do
      {:ok, binding} -> binding
      _ -> string
    end
  end

  defp prox_target({prox, {:thing, target_id, coord}}, _) do
    {prox, target_id, coord}
  end

  defp prox_target({prox, {:thing, target_id}}, _) do
    {prox, target_id, "default"}
  end

  defp prox_target(thing, [prox | _]), do: prox_target(thing, prox)

  defp prox_target({:thing, target_id, coord}, prox) do
    {prox, target_id, coord}
  end

  defp prox_target({:thing, target_id}, prox) do
    {prox, target_id, "default"}
  end

  defp prox_target(%{"target" => target_id, "detail" => coord, "proximity" => prox}, _)
       when not is_nil(prox) and not is_nil(coord) do
    {prox, target_id, coord}
  end

  defp prox_target(%{"target" => target_id, "detail" => coord}, prox) when not is_nil(coord) do
    {prox, target_id, coord}
  end

  defp prox_target(%{"target" => target_id, "proximity" => prox}, _) when not is_nil(prox) do
    {prox, target_id, "default"}
  end

  defp prox_target(%{"target" => target_id}, prox) do
    {prox, target_id, "default"}
  end

  defp prox_target([target], prox), do: prox_target(target, prox)

  defp prox_target(_, _), do: nil

  defscript place(target), for: %{"this" => this} do
    case target do
      {_, {:thing, target_id, _}} ->
        if Militerm.Systems.Entity.whereis({:thing, target_id}) do
          Militerm.Services.Location.place(this, target)
          true
        else
          false
        end

      _ ->
        false
    end
  end

  defcommand goto(arg), for: %{"this" => {:thing, entity_id} = this} = args do
    bits = String.split(arg, ~r{\s+}, trim: true)

    if Components.EphemeralGroup.get_value(entity_id, ["admin"]) do
      target =
        case bits do
          [location] ->
            case String.split(location, "@", parts: 2) do
              [entity_id] ->
                Militerm.Systems.Entity.whereis({:thing, entity_id})
                {"in", {:thing, entity_id, "default"}}

              [coord, entity_id] ->
                Militerm.Systems.Entity.whereis({:thing, entity_id})
                {"in", {:thing, entity_id, coord}}
            end

          [prep, location] ->
            case String.split(location, "@", parts: 2) do
              [entity_id] ->
                Militerm.Systems.Entity.whereis({:thing, entity_id})
                {prep, {:thing, entity_id, "default"}}

              [coord, entity_id] ->
                Militerm.Systems.Entity.whereis({:thing, entity_id})
                {prep, {:thing, entity_id, coord}}
            end

          _ ->
            nil
        end

      if target && Militerm.Services.Location.place(this, target) do
        Events.run_event_set(["scan:env:brief"], ["actor"], Map.put(args, "actor", [this]))
      else
        Entity.receive_message(this, "cmd", "Unable to move to #{Enum.join(bits, " ")}", args)
      end
    else
      Entity.receive_message(this, "cmd:error", "You aren't allowed to use the @goto command.")
    end
  end

  def describe_inventory(thing, excluding) do
    if Militerm.Systems.Entity.is?(thing, "scene", %{"this" => thing}) do
      describe_scene_inventory(thing, excluding)
    else
      describe_thing_inventory(thing, excluding)
    end
  end

  def describe_thing_inventory(entity, excluding) do
    # what's in, on, or worn by the entity?
    # items = things in/on but not worn or held
    # wieldeds = things held
    # worns = things worn
    # for now, we don't have held or worn
    excluding = if is_list(excluding), do: excluding, else: [excluding]
    items = Militerm.Services.Location.find_near(entity) -- excluding

    case items do
      [] ->
        "You see nothing."

      _ ->
        Militerm.Systems.MML.bind!("You see: {{items}}.", %{"items" => items})
    end
  end

  def describe_scene_inventory(scene, excluding) do
    excluding = if is_list(excluding), do: excluding, else: [excluding]
    items = Militerm.Services.Location.find_in(scene) -- excluding

    for item <- items do
      case Militerm.Services.Location.where(item) do
        {prep, loc} ->
          case Militerm.Systems.Entity.property(item, ["location", "position"], %{"this" => item}) do
            nil ->
              Militerm.Systems.MML.bind!("{capitalize}<this:name>{/capitalize} is here. ", %{
                "this" => item,
                "prep" => prep,
                "loc" => loc
              })

            position ->
              Militerm.Systems.MML.bind!(
                "{capitalize}<this:name>{/capitalize} is {{position}} here. ",
                %{"this" => item, "position" => position, "prep" => prep, "loc" => loc}
              )
          end

        _ ->
          ""
      end
    end
  end

  def find_exits(nil), do: []

  def find_exits(this) do
    # find exits appropriate for the given entity
    # details:$detail:exits:$exit
    case Militerm.Services.Location.where(this) do
      {_, {:thing, target_id, detail}} when is_binary(detail) ->
        case Components.Details.get(target_id, detail) do
          %{"exits" => exits, "related_to" => parent_detail} ->
            if is_nil(parent_detail) do
              map_keys(exits)
            else
              case Components.Details.get(target_id, parent_detail) do
                %{"exits" => parent_exits} ->
                  Enum.uniq(map_keys(exits) ++ map_keys(parent_exits))

                _ ->
                  map_keys(exits)
              end
            end

          %{"exits" => exits} ->
            map_keys(exits)

          %{"related_to" => parent_detail} when not is_nil(parent_detail) ->
            case Components.Details.get(target_id, parent_detail) do
              %{"exits" => parent_exits} ->
                map_keys(parent_exits)

              _ ->
                []
            end

          _ ->
            []
        end

      _ ->
        []
    end
  end

  def place(entity_id, {prep, {:thing, target_id, coord}} = target) do
    Militerm.Services.Location.place(entity_id, target)
  end

  defp map_keys(nil), do: []
  defp map_keys(map), do: Map.keys(map)

  @moduledoc """
  The location component manages all of the information needed to manage where things are.
  """

  @doc """
  Move to a location. Handles calling all the right events.
  """
  def move_to(
        class,
        {:thing, entity_id} = entity,
        prox,
        target_id,
        coord,
        {:thing, actor_id} = actor
      ) do
    dest = {prox, {:thing, target_id, coord}}

    case Militerm.Services.Location.where(entity) do
      {_, {:thing, ^target_id, _}} = from ->
        motion_in_target(entity, class, from, dest, actor)

      {leaving_prep, {:thing, leaving_id, leaving_coord}} = from ->
        entity_id
        |> permission_to_leave(class, leaving_id, leaving_coord)
        |> permission_to_arrive(entity_id, class, {:thing, target_id}, coord)
        |> permission_to_accept(entity_id, class, from, dest)
        |> finalize_move(entity_id, class, actor_id, from, dest)

      nil ->
        {:cont, [], []}
        |> permission_to_arrive(entity_id, class, {:thing, target_id}, coord)
        |> permission_to_accept(entity_id, class, nil, dest)
        |> finalize_move(entity_id, class, actor_id, nil, dest)
    end
  end

  defp finalize_move({:halt, _} = halt, _, _, _, _, _), do: halt

  defp finalize_move({:cont, pre, post}, entity_id, class, actor_id, from, dest) do
    {slot_names, slots} =
      if entity_id == actor_id or is_nil(actor_id) do
        {["actor"], %{"actor" => {:thing, entity_id}}}
      else
        {["actor", "direct"], %{"actor" => {:thing, actor_id}, "direct" => [{:thing, entity_id}]}}
      end

    # move everything in relation to the thing being moved that isn't part of
    # that things inventory.

    Militerm.Systems.Events.run_event_set(
      pre ++ ["move:#{class}"] ++ post,
      slot_names,
      slots
      |> Map.put("moving_from", from)
      |> Map.put("moving_to", dest)
    )
  end

  defp permission_to_leave(entity_id, class, leaving_id, coord) do
    case Militerm.Systems.Entity.pre_event(leaving_id, "move:release:#{class}", "environment", %{
           "direct" => [{:thing, entity_id}],
           "coord" => coord
         }) do
      {:halt, _} = halt -> halt
      {:cont, _, _} = continue -> continue
      _ -> {:cont, [], []}
    end
  end

  defp permission_to_arrive({:halt, _} = halt, _, _, _, _), do: halt

  defp permission_to_arrive({:cont, pre, post} = continue, entity_id, class, arriving_id, coord) do
    case Militerm.Systems.Entity.pre_event(arriving_id, "move:receive", "environment", %{
           "direct" => [entity_id],
           "coord" => coord
         }) do
      {:halt, _} = halt -> halt
      {:cont, more_pre, more_post} -> {:cont, pre ++ more_pre, more_post ++ post}
      _ -> continue
    end
  end

  defp permission_to_accept({:halt, _} = halt, _, _, _, _), do: halt

  defp permission_to_accept({:cont, pre, post} = continue, entity_id, class, from, to) do
    case Militerm.Systems.Entity.pre_event(entity_id, "move:accept", "actor", %{
           "from" => from,
           "to" => to
         }) do
      {:halt, _} = halt -> halt
      {:cont, more_pre, more_post} -> {:cont, pre ++ more_pre, more_post ++ post}
      _ -> continue
    end
  end

  defp motion_in_target(
         {:thing, entity_id},
         class,
         {_, from_loc} = from,
         {to_prox, to_loc},
         actor
       ) do
    # we have to find a chain from where we are to where we want to go
    # it has to be within a certain range -- can't go moving quickly through
    # everything -- chain can be no more than 2-3 nodes long
    #
    # or... we generate an event for each step on the chain
    #
    path =
      case Militerm.Services.Location.shortest_path(from_loc, to_loc) do
        [^from_loc | _] = answer -> answer
        [^to_loc | _] = answer -> Enum.reverse(answer)
        _ -> []
      end

    traverse_path(entity_id, class, from, to_prox, path, actor)
  end

  defp traverse_path(
         entity_id,
         class,
         from,
         final_prox,
         [
           {:thing, current_entity_id, _} = current_loc,
           {:thing, next_entity_id, next_coord} = next_loc
         ],
         {:thing, actor_id} = _actor
       ) do
    # {current_prep, {:thing, current_parent_id, _}} = Militerm.Services.Location.where(current_loc)

    # prox = if current_parent_id == next_entity_id, do: current_prep, else: final_prep

    {leaving_prep, {:thing, leaving_id, leaving_coord}} = from
    dest = {final_prox, next_loc}

    entity_id
    |> permission_to_leave(class, leaving_id, leaving_coord)
    |> permission_to_arrive(entity_id, class, {:thing, next_entity_id}, next_coord)
    |> permission_to_accept(entity_id, class, from, dest)
    |> finalize_move(entity_id, class, actor_id, from, dest)
  end

  defp traverse_path(
         entity_id,
         class,
         from,
         final_prox,
         [
           {:thing, current_entity_id, _} = current_loc,
           {:thing, next_entity_id, next_coord} = next_loc,
           next_next_loc | rest
         ] = chain,
         {:thing, actor_id} = actor
       ) do
    {current_prep, {:thing, current_parent_id, _}} =
      case Militerm.Services.Location.where(current_loc) do
        nil -> {"in", {:thing, nil, nil}}
        otherwise -> otherwise
      end

    {next_prep, _} =
      next_loc_where =
      case Militerm.Services.Location.where(next_next_loc) do
        nil -> {"in", {:thing, nil, nil}}
        otherwise -> otherwise
      end

    prep = if current_parent_id == next_entity_id, do: current_prep, else: next_prep

    {leaving_prep, {:thing, leaving_id, leaving_coord}} = from
    dest = {prep, next_loc}

    result =
      entity_id
      |> permission_to_leave(class, leaving_id, leaving_coord)
      |> permission_to_arrive(entity_id, class, {:thing, next_entity_id}, next_coord)
      |> permission_to_accept(entity_id, class, from, dest)
      |> finalize_move(entity_id, class, actor_id, from, dest)

    case result do
      {:halt, _} = halt ->
        halt

      _ ->
        traverse_path(entity_id, class, dest, final_prox, [next_loc, next_next_loc | rest], actor)
    end
  end

  defp traverse_path(_, _, _, _, _, _), do: false

  defp without_nils(list) do
    list
    |> Enum.reject(&is_nil/1)
  end
end
