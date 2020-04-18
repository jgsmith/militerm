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

  defscript describe(sense, entity), for: options do
    do_describe(sense, entity, options)
  end

  def do_describe(sense, things, options) when is_list(things) do
    things
    |> Enum.map(&do_describe(sense, &1, options))
    |> Enum.intersperse(" ")
  end

  def do_describe(sense, {:thing, entity_id}, options) do
    do_describe(sense, {:thing, entity_id, "default"}, options)
  end

  def do_describe(sense, {:thing, entity_id, detail} = this, options) do
    detail_info = Militerm.Components.Details.get(entity_id, detail)

    placement =
      case Militerm.Services.Location.where(this) do
        {prep, {:thing, target_id, target_detail}} when is_binary(detail) ->
          position =
            case detail do
              "default" -> Components.Location.position(entity_id)
              _ -> Map.get(detail_info, "position", "")
            end

          case Components.Details.get(target_id, target_detail) do
            %{"short" => short} ->
              [
                String.capitalize(Map.get(detail_info, "short")),
                " is ",
                position,
                " ",
                prep,
                " ",
                short,
                "."
              ]

            _ ->
              [String.capitalize(Map.get(detail_info, "short")), " is ", position, " here."]
          end
      end

    long =
      case detail_info do
        %{^sense => value} -> [" ", value]
        _ -> []
      end

    [placement, long]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> to_string
  end

  def do_describe(sense, thing, options) do
    ""
  end

  defscript describe(), for: %{"this" => {:thing, this_id} = this} = _objects do
    # exits = ["Obvious exits: ", Militerm.English.item_list(find_exits(this)), "."]
    {start, _, _} = start_sight_inventory(this)
    to_string(["You are ", start])
  end

  def start_sight_inventory({:thing, this_id}) do
    start_sight_inventory({:thing, this_id, "default"})
  end

  def start_sight_inventory({:thing, this_id, detail} = this) do
    {start, sight, inventory} =
      case Services.Location.where(this) do
        {prep, {:thing, target_id, detail} = loc} when is_binary(detail) ->
          position = Components.Location.position(this_id) || "standing"

          description =
            case Components.Details.get(target_id, detail) do
              %{"short" => short} ->
                [position, " ", prep, " ", short]

              _ ->
                [position, " ", prep, " something"]
            end

          description =
            case Components.Details.get(target_id, detail) do
              %{"related_to" => parent_detail, "related_by" => prox} ->
                case Components.Details.get(target_id, parent_detail) do
                  %{"short" => short} ->
                    [description, " ", prox, " ", short, "."]

                  _ ->
                    [description, " ", prox, " somewhere."]
                end

              _ ->
                [description, "."]
            end

          {to_string(description),
           Map.get(Components.Details.get(target_id, detail, %{}), "sight"),
           Militerm.Services.Location.find_near(loc)}

        {prep, {:thing, target_id, _} = loc} ->
          position = Components.Location.position(this, "standing")

          %{"short" => short} = detail_info = Components.Details.get(target_id, "default")

          description = to_string(["You are ", position, " ", prep, " ", short, "."])

          {description, Map.get(Components.Details.get(target_id, "default", %{}), "sight"),
           Militerm.Services.Location.find_near(loc)}

        _ ->
          position = Components.Location.position(this_id, "standing")

          description = to_string(["You are ", position, " somewhere."])
          {description, "", []}
      end
  end

  defscript describe_long(),
    for: %{"this" => {:thing, this_id} = this} = _objects do
    {start, sight, inventory} = start_sight_inventory(this)

    long =
      case sight do
        string when is_binary(string) -> string
        %{"day" => day} -> day
        %{"night" => night} -> night
        _ -> ""
      end

    extras =
      inventory
      |> Enum.map(fn
        {:thing, entity_id, detail} ->
          Components.Details.get(entity_id, detail)

        {:thing, entity_id} ->
          Components.Details.get(entity_id, "default")
      end)
      |> Enum.map(fn
        %{"extra" => %{"sight" => extra}} ->
          case extra do
            string when is_binary(string) -> string
            %{"day" => day} -> day
            %{"night" => night} -> night
            _ -> nil
          end

        _ ->
          nil
      end)
      |> Enum.reject(&is_nil/1)

    Enum.join(["You are", start, long | extras], " ")
  end

  defscript describe_long(entity), for: %{"this" => {:thing, this_id} = this} = _objects do
    entity = if is_list(entity), do: List.first(entity), else: entity

    detail =
      case entity do
        {:thing, _, d} when is_binary(d) -> d
        _ -> "default"
      end

    short =
      case Components.Details.get(elem(entity, 1), detail) do
        %{"short" => short} -> short
        _ -> "something"
      end

    {start, sight, inventory} = start_sight_inventory(entity)

    long =
      case sight do
        string when is_binary(string) -> string
        %{"day" => day} -> day
        %{"night" => night} -> night
        _ -> ""
      end

    extras =
      inventory
      |> Enum.map(fn
        {:thing, entity_id, detail} ->
          Components.Details.get(entity_id, detail)

        {:thing, entity_id} ->
          Components.Details.get(entity_id, "default")
      end)
      |> Enum.map(fn
        %{"extra" => %{"sight" => extra}} ->
          case extra do
            string when is_binary(string) -> string
            %{"day" => day} -> day
            %{"night" => night} -> night
            _ -> nil
          end

        _ ->
          nil
      end)
      |> Enum.reject(&is_nil/1)

    Enum.join([initial_capital(short), "is", start, long | extras], " ")
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

    extras =
      this
      |> Militerm.Services.Location.find_near()
      |> Enum.map(fn
        {:thing, entity_id, detail} ->
          Components.Details.get(entity_id, detail)

        {:thing, entity_id} ->
          Components.Details.get(entity_id, "default")
      end)
      |> Enum.filter(fn
        %{"extra" => %{"sight" => extra}} ->
          case extra do
            string when is_binary(string) -> true
            %{"day" => day} -> true
            %{"night" => night} -> true
            _ -> false
          end

        _ ->
          false
      end)

    describe_inventory(this, [this | excluding ++ extras])
  end

  @doc """
  Returns the inventory of the given entity.
  """
  defscript inventory(entity), for: %{"this" => this} = objects do
    excluding = Map.get(objects, "actor", [])

    excluding = if is_list(excluding), do: excluding, else: [excluding]

    extras =
      entity
      |> Militerm.Services.Location.find_near()
      |> Enum.map(fn
        {:thing, entity_id, detail} = thing ->
          {thing, Components.Details.get(entity_id, detail)}

        {:thing, entity_id} = thing ->
          {thing, Component.Details.get(entity_id, "default")}
      end)
      |> Enum.filter(fn
        {_, %{"extra" => %{"sight" => extra}}} ->
          case extra do
            string when is_binary(string) -> true
            %{"day" => day} -> true
            %{"night" => night} -> true
            _ -> false
          end

        _ ->
          false
      end)
      |> Enum.map(&elem(&1, 0))

    describe_inventory(entity, [entity | excluding ++ extras])
  end

  defscript present(string), for: %{"this" => this} = _objects do
  end

  defscript present(string, env), for: %{"this" => this} = _objects do
  end

  defscript move_to(class, entity_id, prep, target_id, coord),
    for: %{"this" => this},
    as: "MoveTo" do
    move_to(class, entity_id, prep, target_id, coord, this)
  end

  defscript move_to(class, thing, default_prox, target),
    for: %{"this" => this} = _objects,
    as: "MoveTo" do
    case prox_target(target, default_prox) do
      {prox, target_id, target_coord} ->
        move_to(class, thing, prox, target_id, target_coord, this)

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

  defp prox_target({prox, {:thing, target_id, coord}}, _) do
    {prox, target_id, coord}
  end

  defp prox_target({prox, {:thing, target_id}}, _) do
    {prox, target_id, "default"}
  end

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

    Militerm.Systems.Events.run_event_set(
      pre ++ ["move:#{class}"] ++ post,
      slot_names,
      slots
      |> Map.put("moving_from", from)
      |> Map.put("moving_to", dest)
    )
  end

  defp permission_to_leave(entity_id, class, leaving_id, coord) do
    case Militerm.Systems.Entity.pre_event(leaving_id, "move:release:#{class}", :environment, %{
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
    case Militerm.Systems.Entity.pre_event(arriving_id, "move:receive", :environment, %{
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
    case Militerm.Systems.Entity.pre_event(entity_id, "move:accept", :actor, %{
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
end
