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
    |> IO.inspect()
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

    to_string([placement, long])
  end

  def do_describe(sense, thing, options) do
    IO.inspect({:do_describe, sense, thing, options})
    ""
  end

  defscript describe(), for: %{"this" => {:thing, this_id} = this} = _objects do
    # exits = ["Obvious exits: ", Militerm.English.item_list(find_exits(this)), "."]

    case Militerm.Services.Location.where(this) do
      {prep, {:thing, target_id, detail}} when is_binary(detail) ->
        position = Components.Location.position(this_id) || "standing"

        case Components.Details.get(target_id, detail) do
          %{"short" => short} ->
            description = ["You are ", position, " ", prep, " ", short, "."]
            to_string(description)

          _ ->
            description = ["You are ", position, " ", prep, " something somewhere."]
            to_string(description)
        end

      {prep, {:thing, target_id, _}} ->
        position = Components.Location.position(this, "standing")

        %{"short" => short} = detail_info = Components.Details.get(target_id, "default")

        description = ["You are ", position, " ", prep, " ", short, "."]
        to_string(description)

      _ ->
        position = Components.Location.position(this_id, "standing")

        description = ["You are ", position, " somewhere."]
        to_string(description)
    end
  end

  defscript describe_long(),
    as: "DescribeLong",
    for: %{"this" => {:thing, this_id} = this} = _objects do
    {start, sight} =
      case Services.Location.where(this) do
        {prep, {:thing, target_id, detail}} when is_binary(detail) ->
          position = Components.Location.position(this_id) || "standing"

          description =
            case Components.Details.get(target_id, detail) do
              %{"short" => short} ->
                to_string(["You are ", position, " ", prep, " ", short, "."])

              _ ->
                to_string(["You are ", position, " ", prep, " something somewhere."])
            end

          {description, Map.get(Components.Details.get(target_id, detail, %{}), "sight")}

        {prep, {:thing, target_id, _}} ->
          position = Components.Location.position(this, "standing")

          %{"short" => short} = detail_info = Components.Details.get(target_id, "default")

          description = to_string(["You are ", position, " ", prep, " ", short, "."])
          {description, Map.get(Components.Details.get(target_id, "default", %{}), "sight")}

        _ ->
          position = Components.Location.position(this_id, "standing")

          description = to_string(["You are ", position, " somewhere."])
          {description, ""}
      end

    long =
      case sight do
        string when is_binary(string) -> string
        %{"day" => day} -> day
        %{"night" => night} -> night
        _ -> ""
      end

    Enum.join([start, long], " ")
  end

  @doc """
  Returns the inventory of `this`.
  """
  defscript inventory(), for: %{"this" => this} = objects do
    excluding = Map.get(objects, "actor", [])

    describe_inventory(this, excluding)
  end

  @doc """
  Returns the inventory of the given entity.
  """
  defscript inventory(entity), for: %{"this" => this} = objects do
    excluding = Map.get(objects, "actor", [])
    describe_inventory(entity, excluding)
  end

  defscript present(string), for: %{"this" => this} = _objects do
  end

  defscript present(string, env), for: %{"this" => this} = _objects do
  end

  defscript move_to(class, entity_id, target_id, coord), for: %{"this" => this}, as: "MoveTo" do
    move_to(class, entity_id, target_id, coord, this)
  end

  defscript move_to(class, entity_id, coord), for: %{"this" => this} = _objects, as: "MoveTo" do
    case coord do
      %{target: target_id, detail: detail} ->
        move_to(class, entity_id, target_id, detail, this)

      %{target: target_id} ->
        move_to(class, entity_id, target_id, "default", this)

      _ ->
        move_to(class, this, entity_id, coord, this)
    end
  end

  defscript move_to(class, target), for: %{"this" => this} = _objects, as: "MoveTo" do
    target =
      case target do
        [t | _] -> t
        t -> t
      end

    case target do
      %{"target" => target_id, "detail" => coord} ->
        move_to(class, this, target_id, coord, this)

      %{"target" => target_id} ->
        move_to(class, this, target_id, "default", this)

      [single_target] ->
        move_to(class, this, target, "default", this)
    end
  end

  defscript place(target), for: %{"this" => this} do
    case target do
      {_, {:thing, target_id, _}} ->
        if Militerm.Components.Entity.entity_exists?(target_id) do
          Militerm.Services.Location.place(this, target)
          true
        else
          false
        end

      _ ->
        false
    end
  end

  defcommand goto(bits), for: %{"this" => this} = args do
    target =
      case bits do
        [location] ->
          case String.split(location, "@", parts: 2) do
            [entity_id] ->
              {"in", {:thing, entity_id, "default"}}

            [coord, entity_id] ->
              {"in", {:thing, entity_id, coord}}
          end

        [prep, location] ->
          case String.split(location, "@", parts: 2) do
            [entity_id] ->
              {prep, {:thing, entity_id, "default"}}

            [coord, entity_id] ->
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
    items = Militerm.Services.Location.find_near(entity) -- excluding

    case items do
      [] ->
        "You see nothing."

      _ ->
        Militerm.Services.MML.bind("You see: {{items}}.", %{"items" => items})
    end
  end

  def describe_scene_inventory(scene, excluding) do
    items = Militerm.Services.Location.find_in(scene) -- excluding

    for item <- items do
      {prep, loc} = Militerm.Services.Location.where(item)

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
    end
  end

  def find_exits(this) do
    # find exits appropriate for the given entity
    # details:$detail:exits:$exit
    case Militerm.Services.Location.where(this) do
      {_, {:thing, target_id, detail}} when is_binary(detail) ->
        case Components.Details.get(target_id, detail) do
          %{"exits" => exits, "related_to" => parent_detail} ->
            if is_nil(parent_detail) do
              Map.keys(exits)
            else
              case Components.Details.get(target_id, parent_detail) do
                %{"exits" => parent_exits} ->
                  Enum.unique(Map.keys(exits) ++ Map.keys(parent_exits))

                _ ->
                  Map.keys(exits)
              end
            end

          %{"exits" => exits} ->
            Map.keys(exits)

          %{"related_to" => parent_detail} when not is_nil(parent_detail) ->
            case Components.Details.get(target_id, parent_detail) do
              %{"exits" => parent_exits} ->
                Map.keys(parent_exits)

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

  @moduledoc """
  The location component manages all of the information needed to manage where things are.
  """

  @doc """
  Move to a location. Handles calling all the right events.
  """
  def move_to(class, entity_id, target_id, coord, actor \\ nil) do
    case Militerm.Services.Location.where(entity_id) do
      {_, {:thing, ^target_id, _}} = from ->
        motion_in_target(entity_id, from, {target_id, coord})

      {leaving_prep, {:thing, leaving_id, leaving_coord}} = from ->
        result =
          entity_id
          |> permission_to_leave(class, {:thing, leaving_id})
          |> permission_to_arrive(entity_id, class, {:thing, target_id})
          |> permission_to_accept(entity_id, class, from, {:thing, target_id, coord})

        case result do
          {:error, _} = _message ->
            # message
            false

          {:cont, pre, post} ->
            # run the pre events -- if they all succeed, then make the move, and then run the post events
            # observers are everything in the scene that can see the move
            # args: %{direct: entity_id, from: ..., to: ...}

            # Militerm.EventManager.run_event_set(
            #   pre ++ ["move"] ++ post, [:actor], %{actor: entity_id}
            # )
            {slot_names, slots} =
              if entity_id == actor or is_nil(actor) do
                {["actor"], %{"actor" => entity_id}}
              else
                {["actor", "direct"], %{"actor" => actor, "direct" => [entity_id]}}
              end

            Militerm.Systems.Events.run_event_set(
              pre ++ ["move:#{class}"] ++ post,
              slot_names,
              slots
              |> Map.put("moving_from", from)
              |> Map.put("moving_to", {"in", {:thing, target_id, coord}})
            )
        end
    end
  end

  defp permission_to_leave(entity_id, class, leaving_id) do
    {:cont, [], []}
    # case Militerm.EntityController.pre_event(leaving_id, "move:release", :environment, %{
    #        direct: [entity_id]
    #      }) do
    #   {:halt, message} -> {:error, message}
    #   {:cont, _, _} = continue -> continue
    #   _ -> {:cont, [], []}
    # end
  end

  defp permission_to_arrive({:error, _} = message, _, _, _), do: message

  defp permission_to_arrive({:cont, pre, post} = c, entity_id, class, arriving_id) do
    c
    # case Militerm.EntityController.pre_event(arriving_id, "move:receive", :environment, %{
    #        direct: [entity_id]
    #      }) do
    #   {:halt, message} -> {:error, message}
    #   {:cont, more_pre, more_post} -> {:cont, pre ++ more_pre, more_post ++ post}
    #   _ -> {:cont, pre, post}
    # end
  end

  defp permission_to_accept({:error, _} = message, _, _, _), do: message

  defp permission_to_accept({:cont, pre, post} = c, entity_id, class, from, to) do
    c
    # case Militerm.EntityController.pre_event(entity_id, "move:accept", :actor, %{
    #        from: from,
    #        to: to
    #      }) do
    #   {:halt, message} -> {:error, message}
    #   {:cont, more_pre, more_post} -> {:cont, pre ++ more_pre, more_post ++ post}
    #   _ -> {:cont, pre, post}
    # end
  end

  defp motion_in_target(entity_id, from_loc, to_loc) do
    # we just do it for now
  end
end
