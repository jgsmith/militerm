defmodule Militerm.Systems.Commands.Binder do
  # %{
  #  command: ["look", "at", "the", "lit", "lamp", "through", "the", "big", "telescope"],
  #  adverbs: [],
  #  direct: [{:object, :singular, [:me, :near], ["the", "lit", "lamp"]}],
  #  instrument: [{:object, :singular, [:me, :near], ["the", "big", "telescope"]}],
  #  syntax: VerbSyntax.parse("at <direct:object'thing> through <instrument:object>")
  # }

  alias Militerm.Components
  alias Militerm.Services
  alias Militerm.Systems

  @not_slots ~w[command adverbs syntax events]a
  @obj_slots ~w[direct indirect instrument]a
  @predefined_env ~w[me near here]a

  @doc """
  Takes the context and command. Returns a new context and the command with slots bound to the
  entities that match the words. Further processing is needed to know if the bound entities can
  be used in the slot for the set of events.
  """

  @spec bind(map, map) :: {map, map}
  def bind(context, command) do
    {_, bound_slots} =
      command
      |> Map.take(@obj_slots)
      |> ordered_slots()
      |> Enum.reduce({context, %{}}, fn slot, acc ->
        bind_slot(slot, Map.get(command, slot), acc)
      end)

    bound_slots =
      command
      |> Map.drop(@not_slots)
      |> Map.drop(@obj_slots)
      |> Enum.reduce(bound_slots, fn {slot, v}, acc ->
        Map.put(acc, slot, v)
      end)

    Map.put(command, :slots, bound_slots)
    # Map.merge(bound_command, Map.take(command, @not_slots))
  end

  def bind_slot(slot, list, info) when is_list(list) do
    {context, new_bindings} =
      Enum.reduce(list, info, fn item, info ->
        bind_slot(slot, item, info)
      end)

    {context, Map.put(new_bindings, slot, Enum.reverse(Map.get(new_bindings, slot, [])))}
  end

  def bind_slot(slot, string, {context, bindings}) when is_binary(string) do
    {
      context,
      Map.put(bindings, slot, [string | Map.get(bindings, slot, [])])
    }
  end

  def bind_slot(slot, {type, number, envs, words}, {context, bindings}) do
    # the -> ignored - can be used with singular and plural sets
    # a/an -> indicates that if there's more than one, select one at random
    # ordinal -> order entities reliably and drop the first few up to the ordinal
    # cardinal -> take the indicated number after processing any ordinal
    # pronouns -> my, its, her, their, his - refocus environment based on context

    # we expect at most one ordinal, one cardinal, one article

    # first, split on prepositions and then match up the chain

    # the env entities are the things we can look in to find what should be visible to us
    # so no delving into containers - no 'in', 'on', etc., that indicates narrative containment
    env_entities = gather_environments(envs, context, bindings)

    # we run through the envs list and see if we can match based on the env
    # rather than translate them into entities and then match in the entities
    # we need to handle distant-living

    # IO.inspect({:bind_slot, :env_entities, env_entities})

    matches =
      case parse_noun_phrase(words) do
        {:ok, parses} ->
          parses
          |> Enum.flat_map(fn %{} = parse ->
            find_objects(parse, env_entities)
          end)

        _ ->
          []
      end

    {context, Map.put(bindings, slot, matches)}
  end

  def bind_slot(_, nil, info), do: info

  defp find_objects(_, []), do: []

  defp find_objects(%{words: words} = parse, [env | rest]) do
    # look in env - if we find nothing, go to rest - otherwise, return what we find
    match =
      env
      |> Services.Location.find_in()
      |> Enum.filter(fn thing -> Systems.Identity.parse_match?(thing, words) end)

    case match do
      [] -> find_objects(parse, rest)
      otherwise -> match
    end
  end

  defp gather_environments(envs, context, bindings, acc \\ [])

  defp gather_environments([], _, _, acc), do: Enum.reverse(acc)

  defp gather_environments([:me | rest], %{actor: entity_id} = context, bindings, acc) do
    gather_environments(rest, context, bindings, [entity_id | acc])
  end

  defp gather_environments([:near | rest], %{actor: entity_id} = context, bindings, acc) do
    {_, loc} = Services.Location.where(entity_id)

    loc =
      case Services.Location.where(loc) do
        {_, loc_loc} -> loc_loc
        nil -> loc
      end

    gather_environments(rest, context, bindings, [loc | acc])
  end

  defp gather_environments([:here | rest], %{actor: entity_id} = context, bindings, acc) do
    {_, {:thing, loc_id, _}} = Services.Location.where(entity_id)
    gather_environments(rest, context, bindings, [{:thing, loc_id} | acc])
  end

  defp gather_environments([slot | rest], context, bindings, acc) do
    gather_environments(rest, context, bindings, Map.get(bindings, slot, []) ++ acc)
  end

  @doc """
  Parses the noun phrase into parts that can be matched against things.

  ## Examples

    iex> Binder.parse_noun_phrase(~w[duck])
    {:ok, [%{words: ["duck"]}]}

    iex> Binder.parse_noun_phrase(~w[all ducks])
    {:ok, [%{quantity: :all, words: ["ducks"]}]}

    iex> Binder.parse_noun_phrase(~w[the letter in the envelope])
    {:ok, [%{article: "the", words: ["envelope"], relation: {"in", %{article: "the", words: ["letter"]}}}]}

    iex> Binder.parse_noun_phrase(~w[twenty six grams of flour])
    {:ok, [%{words: ["flour"], relation: {"of", %{quantity: 26, words: ["grams"]}}}]}
  """
  def parse_noun_phrase(words) do
    # split words on prepositions
    lex =
      words
      |> Enum.join(" ")
      |> String.to_charlist()
      |> :command_lexer.string()

    case lex do
      {:ok, tokens, _} ->
        parse =
          tokens
          |> Enum.reject(fn
            {:space, _} -> true
            _ -> false
          end)
          |> :command_parser.parse()

        case parse do
          {:ok, structure} ->
            {:ok, cleanup_parse(structure)}

          otherwise ->
            # IO.inspect(otherwise)
            {:error, "Unrecognizable phrase"}
        end

      {:error, {_, _, reason}} ->
        # IO.inspect(reason)
        {:error, reason}
    end
  end

  defp cleanup_parse(structure, acc \\ [])

  defp cleanup_parse([], acc), do: Enum.reverse(acc)

  defp cleanup_parse([tuple | rest], acc) when is_tuple(tuple) do
    cleanup_parse(rest, [reduce_parse(tuple, %{}) | acc])
  end

  defp cleanup_parse([object | rest], acc) do
    map =
      object
      |> Enum.reduce(%{}, &reduce_parse/2)

    cleanup_parse(rest, [map | acc])
  end

  defp reduce_parse({:relation, {left, prep, right}}, acc) do
    [right]
    |> cleanup_parse()
    |> List.first()
    |> Map.put(:relation, {prep, List.first(cleanup_parse([left]))})
  end

  defp reduce_parse({k, v}, map) do
    Map.put(map, k, v)
  end

  defp reduce_parse(list, map) when is_list(list) do
    list
    |> Enum.reduce(map, &reduce_parse/2)
  end

  defp ordered_slots(mapping) do
    sort =
      mapping
      |> Enum.reduce(%{}, fn {slot, refs}, acc ->
        referenced_slots =
          refs
          |> Enum.flat_map(fn
            {_, _, envs} -> envs
            _ -> []
          end)
          |> Enum.uniq()

        case referenced_slots do
          [] -> acc
          _ -> Map.put(acc, slot, referenced_slots -- @predefined_env)
        end
      end)
      |> topological_sort

    sort ++ (@obj_slots -- sort)
  end

  defp topological_sort(map, acc \\ [])

  defp topological_sort(map, acc) when map_size(map) == 0, do: Enum.reverse(acc)

  defp topological_sort(map, acc) do
    available =
      map
      |> Enum.filter(fn
        {_, []} -> true
        _ -> false
      end)

    with [_ | _] = available <-
           Enum.filter(map, fn
             {_, []} -> true
             _ -> false
           end) do
      map
      |> Map.drop(available)
      |> Enum.map(fn {k, v} -> {k, v -- available} end)
      |> Enum.into(%{})
      |> topological_sort(available ++ acc)
    else
      _ -> :error
    end
  end
end
