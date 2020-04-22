defmodule Militerm.Machines.Script do
  alias Militerm.Systems.Entity
  alias Militerm.Systems

  require Logger

  @boolean_ops [:and, :or]
  @numeric_ops [:sum, :product]

  @boolean_false_values [false, "", 0, 0.0, nil, []]

  @moduledoc false

  # A simple stack machine used for executing event handlers.
  # The code is a sequence of atoms, strings, and numbers provided by
  # `Militerm.System.Compilers.Script`:
  #
  #     source_code
  #     |> Militerm.System.Parsers.Script.parse
  #     |> Militerm.System.Compilers.Script.compile
  #     |> Militerm.System.Machines.Script.run(objects)
  #
  # Where `objects` is a mapping of atoms to object identifiers useful with
  # `Militerm.Entity`.
  #
  # The machine consists of the code, an instruction pointer, a stack, a
  # stack of stack marks (for rolling back a stack after a subroutine call),
  # a set of objects in the narrative context, and a scratch pad for temporary
  # values such as variables referenced in code.
  #
  # The machine runs in the same thread as the caller.

  defmodule Machine do
    @moduledoc false

    defstruct code: {}, stack: [], ip: 0, marks: [], objects: %{}, pad: %{}
  end

  @doc """
  Run the script from the current position.

  ## Examples

  ### Get passed-in arguments/objects

      iex> Script.run({"coord", :get_obj}, %{"coord" => "default"})
      "default"

  ### Boolean AND

      iex> Script.run({
      ...>   true, 0, true,
      ...>   3, :and
      ...> })
      false

  ### Boolean OR

      iex> Script.run({
      ...>   true, false, true,
      ...>   3, :or
      ...> })
      true

  ### Make a list from the top _n_ items

      iex> Script.run({
      ...>   1, 2, 3,
      ...>   3, :make_list
      ...> })
      [3, 2, 1]

  ### Jump unconditionally

      iex> Script.run({
      ...>   :jump, 1, 3, 7
      ...> })
      7
  """
  def run(code, objects \\ %{}) do
    # IO.inspect({:running, code})

    machine = %Machine{
      code: code,
      objects: objects
    }

    case step_until_done(machine) do
      %{stack: [return_value | _]} ->
        return_value

      _ ->
        nil
    end
  end

  defp step_until_done(state) do
    case step(state) do
      :done -> state
      new_state -> step_until_done(new_state)
    end
  end

  defp step(%{code: code, ip: ip}) when ip >= tuple_size(code), do: :done

  defp step(%{code: code, ip: ip} = state) when ip >= 0 do
    execute_step(elem(code, ip), %{state | ip: ip + 1})
  end

  defp execute_step(v, %{stack: stack} = state) when not is_atom(v) do
    %{state | stack: [v | stack]}
  end

  defp execute_step(bool, %{stack: stack} = state) when bool in [true, false] do
    %{state | stack: [bool | stack]}
  end

  defp execute_step(:done, _), do: :done

  defp execute_step(:dup, %{stack: [h | stack]} = state) do
    %{state | stack: [h, h | stack]}
  end

  defp execute_step(:drop, %{stack: [_ | stack]} = state) do
    %{state | stack: stack}
  end

  defp execute_step(:mark, %{stack: stack, marks: marks} = state) do
    %{state | marks: [Enum.count(stack) | marks]}
  end

  defp execute_step(:clear, %{marks: []} = state) do
    %{state | stack: []}
  end

  defp execute_step(:clear, %{stack: stack, marks: [h | marks]} = state) do
    stack_size = Enum.count(stack)

    if h <= stack_size do
      %{state | stack: Enum.drop(stack, stack_size - h), marks: marks}
    else
      %{state | stack: [], marks: marks}
    end
  end

  defp execute_step(:jump, %{code: code, ip: ip} = state) do
    %{state | ip: ip + 1 + elem(code, ip)}
  end

  defp execute_step(:jump_unless, %{stack: [v | stack]} = state) when is_map(v) do
    execute_jump_unless(map_size(v) == 0, %{state | stack: stack})
  end

  defp execute_step(:jump_unless, %{stack: [v | stack]} = state) when is_tuple(v) do
    execute_jump_unless(tuple_size(v) == 0, %{state | stack: stack})
  end

  defp execute_step(:jump_unless, %{stack: [v | stack]} = state) do
    execute_jump_unless(v in @boolean_false_values, %{state | stack: stack})
  end

  defp execute_step(:not, %{stack: [v | stack]} = state) when is_map(v) do
    %{state | stack: [map_size(v) == 0 | stack]}
  end

  defp execute_step(:not, %{stack: [v | stack]} = state) when is_tuple(v) do
    %{state | stack: [tuple_size(v) == 0 | stack]}
  end

  defp execute_step(:not, %{stack: [v | stack]} = state) do
    %{state | stack: [v in @boolean_false_values | stack]}
  end

  defp execute_step(:this_can, %{stack: [ability, pov | stack], objects: objects} = state) do
    case Map.get(objects, "this") do
      nil ->
        %{state | stack: [false | stack]}

      [_ | _] = these ->
        %{
          state
          | stack: [
              Enum.any?(these, &Entity.can?(&1, ability, pov, objects))
              | stack
            ]
        }

      this ->
        %{
          state
          | stack: [
              Entity.can?(this, ability, pov, objects)
              | stack
            ]
        }
    end
  end

  defp execute_step(:can, %{stack: [ability, pov, base | stack], objects: objects} = state)
       when is_tuple(base) do
    %{
      state
      | stack: [
          Entity.can?(base, ability, pov, objects)
          | stack
        ]
    }
  end

  defp execute_step(:can, %{stack: [ability, pov, base | stack], objects: objects} = state)
       when is_list(base) do
    %{
      state
      | stack: [
          base |> Enum.map(&Entity.can?(&1, ability, pov, objects))
          | stack
        ]
    }
  end

  defp execute_step(:can, %{stack: [_, _, _ | stack]} = state) do
    %{state | stack: [nil | stack]}
  end

  defp execute_step(:this_is, %{stack: [trait | stack], objects: objects} = state) do
    case Map.get(objects, "this") do
      nil ->
        %{state | stack: [false | stack]}

      [_ | _] = these ->
        %{
          state
          | stack: [
              Enum.any?(these, &Entity.is?(&1, trait, objects))
              | stack
            ]
        }

      this ->
        %{
          state
          | stack: [
              Entity.is?(this, trait, objects)
              | stack
            ]
        }
    end
  end

  defp execute_step(:is, %{stack: [trait, base | stack], objects: objects} = state)
       when is_tuple(base) do
    %{
      state
      | stack: [
          Entity.is?(base, trait, objects)
          | stack
        ]
    }
  end

  defp execute_step(:is, %{stack: [trait, base | stack], objects: objects} = state)
       when is_list(base) do
    %{
      state
      | stack: [
          base |> Enum.map(&Entity.is?(&1, trait, objects))
          | stack
        ]
    }
  end

  defp execute_step(:is, %{stack: [_, _, _ | stack]} = state) do
    %{state | stack: [false | stack]}
  end

  defp execute_step(:uhoh, %{stack: [message | stack], objects: objects} = state) do
    with {:ok, parse} <- Militerm.Parsers.MML.parse(message),
         {:ok, bound_message} <- Militerm.Systems.MML.bind(parse, objects) do
      %{
        state
        | stack: [
            {:halt, bound_message} | stack
          ]
      }
    else
      _ ->
        %{
          state
          | stack: [
              {:halt, "Something went wrong."} | stack
            ]
        }
    end
  end

  defp execute_step(:index, %{stack: [idx | [base | stack]]} = state)
       when is_list(base) and is_integer(idx) do
    %{state | stack: [Enum.at(base, idx, nil) | stack]}
  end

  defp execute_step(:index, %{stack: [prop | [base | stack]], objects: objects} = state)
       when is_list(base) do
    %{
      state
      | stack: [
          base
          |> Enum.map(fn obj ->
            Entity.property(obj, prop, objects)
          end)
          | stack
        ]
    }
  end

  defp execute_step(:index, %{stack: [idx | [base | stack]]} = state) when is_map(base) do
    %{state | stack: [Map.get(base, idx, nil) | stack]}
  end

  defp execute_step(:index, %{stack: [idx | [base | stack]]} = state) when is_binary(base) do
    %{state | stack: [String.at(base, idx) | stack]}
  end

  defp execute_step(:index, %{stack: [prop | [base | stack]], objects: objects} = state)
       when is_tuple(base) do
    %{state | stack: [Entity.property(base, prop, objects) | stack]}
  end

  defp execute_step(:index, %{stack: []} = state), do: %{state | stack: [nil]}

  defp execute_step(:index, %{stack: [_ | [_ | stack]]} = state) do
    %{state | stack: [nil | stack]}
  end

  defp execute_step(:call, %{code: code, ip: ip, stack: stack, objects: objects} = state) do
    function = elem(code, ip)
    arity = elem(code, ip + 1)
    {args, rest} = Enum.split(stack, arity)

    %{
      state
      | ip: ip + 2,
        stack: [
          Systems.Script.call_function(
            function,
            args,
            objects
          )
          | rest
        ]
    }
  end

  defp execute_step(
         :narrate,
         %{stack: [sense, volume, message | stack], objects: %{"this" => this} = objects} = state
       ) do
    # send the message out to everyone - it's a "msg:#{sense}" event that's tailored to them
    # so the target object decides if it gets displayed or not

    observers =
      this
      |> Militerm.Services.Location.find_near()
      |> Enum.map(fn item -> {item, "observer"} end)

    observers =
      case Militerm.Services.Location.where(this) do
        {_, loc} -> [{loc, "observer"} | observers]
        _ -> observers
      end

    {:ok, bound_message} =
      message
      |> Militerm.Systems.MML.bind(
        objects
        |> Map.put("actor", to_list(this))
      )

    event = "msg:#{sense}"

    entities =
      for slot <- ~w[actor direct indirect instrument],
          entities <- to_list(Map.get(objects, slot, [])),
          entity_id <- to_list(entities),
          do: {entity_id, slot}

    # TOOD: add observant entities in the environment
    entities = Enum.uniq_by(entities ++ observers, &elem(&1, 0))

    for {entity_id, role} <- entities do
      Militerm.Systems.Entity.event(entity_id, event, to_string(role), %{
        "this" => entity_id,
        "text" => bound_message,
        "intensity" => volume
      })
    end

    %{state | stack: stack}
  end

  defp execute_step(:make_list, %{stack: [n | stack]} = state) do
    with {list, new_stack} <- Enum.split(stack, n) do
      %{state | stack: [list | new_stack]}
    end
  end

  defp execute_step(:make_dict, %{stack: [n | stack]} = state) do
    with {list, new_stack} <- Enum.split(stack, 2 * n) do
      map =
        list
        |> Enum.chunk_every(2)
        |> Enum.map(&List.to_tuple/1)
        |> Enum.into(%{})

      %{state | stack: [map | new_stack]}
    end
  end

  defp execute_step(:trigger_event, %{stack: [target, event, pov, args | stack]} = state) do
    targets = if is_list(target), do: target, else: [target]

    targets =
      targets
      |> Enum.filter(fn thing ->
        case Militerm.Systems.Entity.pre_event(thing, event, pov, Map.put(args, "this", thing)) do
          {:halt, _} -> false
          :halt -> false
          _ -> true
        end
      end)

    for thing <- targets do
      Militerm.Systems.Entity.event(thing, event, pov, Map.put(args, "this", thing))
    end

    for thing <- targets do
      Militerm.Systems.Entity.post_event(thing, event, pov, Map.put(args, "this", thing))
    end

    %{state | stack: [Enum.any?(targets) | stack]}
  end

  defp execute_step(:sum, state) do
    do_series_op(0, &+/2, :numeric, state)
  end

  defp execute_step(:concat, state) do
    do_series_op("", &<>/2, :string, state)
  end

  defp execute_step(:product, state) do
    do_series_op(1, &*/2, :numeric, state)
  end

  defp execute_step(:and, state) do
    do_series_op(true, &series_and/2, :boolean, state)
  end

  defp execute_step(:or, state) do
    do_series_op(false, &series_or/2, :boolean, state)
  end

  defp execute_step(:set_union, state) do
    do_mapset_op(:union, state)
  end

  defp execute_step(:set_intersection, state) do
    do_mapset_op(:intersection, state)
  end

  defp execute_step(:set_diff, state) do
    do_mapset_op(:difference, state)
  end

  defp execute_step(:lt, state), do: do_ordered_op(&Kernel.</2, state)
  defp execute_step(:le, state), do: do_ordered_op(&Kernel.<=/2, state)
  defp execute_step(:gt, state), do: do_ordered_op(&Kernel.>/2, state)
  defp execute_step(:ge, state), do: do_ordered_op(&Kernel.>=/2, state)
  defp execute_step(:eq, state), do: do_ordered_op(&Kernel.==/2, state)

  defp execute_step(:ne, %{stack: [n | stack]} = state) do
    with {list, new_stack} <- Enum.split(stack, n) do
      %{state | stack: [list |> Enum.uniq() |> Enum.count() == n | new_stack]}
    end
  end

  defp execute_step(:difference, %{stack: [l, r | stack]} = state) do
    %{state | stack: [l - r | stack]}
  end

  defp execute_step(:div, %{stack: [d, n | stack]} = state) do
    %{state | stack: [n / d | stack]}
  end

  defp execute_step(:mod, %{stack: [r, l | stack]} = state) do
    mod =
      if l < 0 do
        l + rem(l, r)
      else
        rem(l, r)
      end

    %{state | stack: [mod | stack]}
  end

  defp execute_step(:set_var, %{pad: pad, stack: [name | [value | _] = stack]} = state) do
    %{state | stack: stack, pad: Map.put(pad, name, value)}
  end

  defp execute_step(
         :set_this_prop,
         %{pad: pad, stack: [name | [value | _] = stack], objects: %{"this" => this} = objects} =
           state
       ) do
    path =
      case name do
        nil ->
          ""

        _ ->
          name
          |> String.split(":", trim: true)
          |> resolve_var_references(pad)
      end

    Entity.set_property(this, path, value, objects)
    %{state | stack: stack}
  end

  defp execute_step(
         :reset_this_prop,
         %{pad: pad, stack: [name | stack], objects: %{"this" => this} = objects} = state
       ) do
    path =
      case name do
        nil ->
          ""

        _ ->
          name
          |> String.split(":", trim: true)
          |> resolve_var_references(pad)
      end

    Entity.reset_property(this, path, objects)
    %{state | stack: [nil | stack]}
  end

  defp execute_step(
         :get_this_prop,
         %{pad: pad, stack: [name | stack], objects: %{"this" => this} = objects} = state
       ) do
    path =
      case name do
        nil ->
          ""

        _ ->
          name
          |> String.split(":", trim: true)
          |> resolve_var_references(pad)
      end

    %{state | stack: [Entity.property(this, path, objects) | stack]}
  end

  defp execute_step(
         :remove_prop,
         %{pad: pad, stack: [name | stack], objects: %{"this" => this}} = state
       ) do
    path =
      case name do
        nil ->
          ""

        _ ->
          name
          |> String.split(":", trim: true)
          |> resolve_var_references(pad)
      end

    Entity.remove_property(this, path)
    %{state | stack: stack}
  end

  defp execute_step(:get_obj, %{stack: [name | stack], objects: objects} = state) do
    %{state | stack: [Map.get(objects, name, nil) | stack]}
  end

  defp execute_step(:get_context_var, %{stack: [name | stack], objects: objects} = state) do
    %{state | stack: [Map.get(objects, name, nil) | stack]}
  end

  defp execute_step(:get_var, %{stack: [name | stack], pad: pad} = state) do
    %{state | stack: [Map.get(pad, name, nil) | stack]}
  end

  defp execute_step(
         :get_prop,
         %{stack: [bases, n | stack], objects: objects, pad: pad} = state
       )
       when is_list(bases) do
    {paths, new_stack} = Enum.split(stack, n)

    values =
      paths
      |> Enum.map(fn name ->
        name
        |> String.split(":")
        |> resolve_var_references(pad)
      end)
      |> Enum.reduce(bases, fn path, bases ->
        bases
        |> Enum.flat_map(fn base ->
          to_list(Entity.property(base, path, objects))
        end)
        |> Enum.reject(&is_nil/1)
      end)

    %{state | stack: [values | stack]}
  end

  defp execute_step(:get_prop, %{stack: [base, n | stack], objects: objects, pad: pad} = state)
       when is_tuple(base) do
    {paths, new_stack} = Enum.split(stack, n)

    paths =
      paths
      |> Enum.map(fn name ->
        name
        |> String.split(":")
        |> resolve_var_references(pad)
      end)

    values =
      paths
      |> Enum.reduce([base], fn path, bases ->
        bases
        |> Enum.map(fn base ->
          Entity.property(base, path, objects)
        end)
        |> Enum.reject(&is_nil/1)
      end)

    %{state | stack: [values | stack]}
  end

  defp execute_step(:get_prop, %{stack: [_base, n | stack]} = state) do
    {_paths, new_stack} = Enum.split(stack, n)

    %{state | stack: [nil | new_stack]}
  end

  defp execute_step(opcode, state) do
    Logger.debug("Unknown instruction! #{opcode}")
    Logger.debug(inspect(state))
  end

  defp to_list(list) when is_list(list), do: list
  defp to_list(scalar), do: [scalar]

  defp maybe_atom(atom) when is_atom(atom), do: atom

  defp maybe_atom(string) when is_binary(string) do
    # try do
    String.to_existing_atom(string)
    # catch
    #   _ -> nil
    # end
  end

  defp resolve_var_references(bits, pad) do
    Enum.flat_map(bits, fn bit ->
      case bit do
        <<"$", _::binary>> = var ->
          val = Map.get(pad, var, "")

          case val do
            nil -> ""
            v when is_binary(v) -> String.split(v, ":", trim: true)
            [v | _] -> String.split(v, ":", trim: true)
          end

        _ ->
          [bit]
      end
    end)
  end

  defp do_ordered_op(op, %{stack: [n | stack]} = state) do
    with {list, new_stack} <- Enum.split(stack, n) do
      %{state | stack: [ordering_satisfied?(op, list) | new_stack]}
    end
  end

  defp ordering_satisfied?(_, []), do: true
  defp ordering_satisfied?(_, [_]), do: true

  defp ordering_satisfied?(op, [l | [r | _] = rest]) do
    if op.(l, r) do
      ordering_satisfied?(op, rest)
    else
      false
    end
  end

  defp do_mapset_op(op, %{stack: [n | stack]} = state) when n > 0 do
    {list, new_stack} = Enum.split(stack, n)

    [prime | sets] =
      list
      |> Enum.map(fn x ->
        if is_list(x), do: MapSet.new(x), else: MapSet.new([x])
      end)

    %{
      state
      | stack: [
          sets
          |> Enum.reduce(prime, fn x, acc ->
            apply(MapSet, op, [x, acc])
          end)
          |> MapSet.to_list()
          | new_stack
        ]
    }
  end

  defp do_mapset_op(_, %{stack: [_ | rest]} = state) do
    %{state | stack: [[] | rest]}
  end

  defp do_series_op(init, op, type, %{stack: [n | rest]} = state) when n > 0 do
    {values, new_stack} = Enum.split(rest, n)

    values =
      case values do
        [a, b] -> [b, a]
        _ -> values
      end

    %{
      state
      | stack: [
          values
          |> convert_for(type)
          |> List.foldl(init, op)
          | new_stack
        ]
    }
  end

  defp do_series_op(init, _, _, %{stack: [_ | rest]} = state) do
    %{state | stack: [init | rest]}
  end

  defp convert_for(list, type, acc \\ [])

  defp convert_for([], _, acc), do: acc

  defp convert_for([nil | rest], type, acc), do: convert_for(rest, type, acc)

  defp convert_for([item | rest], type, acc) do
    convert_for(rest, type, [convert_item_for(type, item) | acc])
  end

  defp convert_item_for(:boolean, item) when item in @boolean_false_values, do: false
  defp convert_item_for(:boolean, _), do: true

  defp convert_item_for(:string, true), do: "True"
  defp convert_item_for(:string, false), do: ""
  defp convert_item_for(:string, item) when is_binary(item), do: item
  defp convert_item_for(:string, item) when is_integer(item), do: Integer.to_string(item)
  defp convert_item_for(:string, item) when is_float(item), do: Float.to_string(item)
  defp convert_item_for(:string, {:thing, id}), do: "<Thing##{id}>"
  defp convert_item_for(:string, {:detail, id, {x, y}}), do: "<Thing##{id}@#{x},#{y}>"
  defp convert_item_for(:string, {:detail, id, {t}}), do: "<Thing##{id}@#{t}>"
  defp convert_item_for(:string, {:detail, id, d}), do: "<Thing##{id}@#{d}>"

  defp convert_item_for(:string, list) when is_list(list),
    do: Militerm.English.item_list(list)

  defp convert_item_for(:string, _), do: ""

  defp convert_item_for(:numeric, item) when is_float(item) or is_integer(item), do: item

  defp convert_item_for(:numeric, item) when is_binary(item) do
    module =
      if String.contains?(item, ".") do
        Float
      else
        Integer
      end

    case module.parse(item) do
      {numeric, _} -> numeric
      _ -> 0
    end
  end

  defp convert_item_for(:numeric, _), do: 0

  defp series_and(true, true), do: true
  defp series_and(_, _), do: false

  defp series_or(false, false), do: false
  defp series_or(_, _), do: true

  defp execute_jump_unless(true, %{code: code, ip: ip} = state) do
    %{state | ip: ip + elem(code, ip) + 1}
  end

  defp execute_jump_unless(false, %{ip: ip} = state) do
    %{state | ip: ip + 1}
  end

  defp to_list(list) when is_list(list), do: list
  defp to_list(nil), do: []
  defp to_list(scalar), do: [scalar]
end
