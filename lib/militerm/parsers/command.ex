defmodule Militerm.Parsers.Command do
  @moduledoc """
  This provides the methods to take player input and match it against the various
  verb syntax options to see which matches, if any. On success, indicates which objects or
  other values are in the slots.
  """

  alias Militerm.Services
  alias Militerm.Config

  alias Militerm.Systems.Commands.Binder

  @obj_slots ~w[actor direct indirect instrument]

  defmodule PatternMatch do
    defstruct command_pos: 0,
              delayed: [],
              last: nil,
              failed: false,
              pattern_pos: 0,
              pattern_size: 0,
              command_size: 0,
              word_offset: 0,
              matches: [0],
              command: [],
              pattern: [],
              context: %{}
  end

  def parse(command, context) do
    %{command: String.split(command, ~r{\s+}), context: context}
    |> take_adverbs()
    |> fetch_syntaxes()
    |> match_syntax()
  end

  # TODO: parse out adverbs at the bigging of the command - let syntaxes determine where
  # adverbs can go after the first word that isn't an adverb
  def take_adverbs(state), do: Map.put(state, :adverbs, [])

  def fetch_syntaxes(%{command: [word | _]} = state) do
    # get all syntaxes that start with the given word ... then whittle down
    # each syntax will be associated with a given event seqence (multiple syntaxes can go with the
    # same sequence, but only one sequence per syntax)
    # syntaxes should be sorted by weight - heaviest weight first
    syntaxes = Services.Verbs.get_syntaxes(:players, word)

    syntaxes =
      syntaxes
      |> Enum.sort_by(fn
        %{weight: weight} = _syntax -> -weight
        _ -> -1
      end)

    Map.put(state, :syntaxes, syntaxes)
  end

  @doc """
  Given the command and available syntaxes, find the one that matches best, if any. A
  successful result can be given to `Militerm.If.Binder.bind` along with a `Militerm.If.Binder.Context` to determine which things might be appropriate for each slot.

  ## Examples

    These need to be rewritten.
    
    # iex> syntax = VerbSyntax.parse("at <direct:object'thing>")
    # ...> Command.match_syntax(%{context: %{actor: {:thing, "actor"}}, command: ["look", "at", "the", "lamp"], syntaxes: [syntax], adverbs: []})
    # %{command: ["look", "at", "the", "lamp"], adverbs: [], direct: [{:object, :singular, [:me, :near], ["the", "lamp"]}], syntax: VerbSyntax.parse("at <direct:object'thing>")}
    #
    # iex> syntax = VerbSyntax.parse("at <direct:object'thing> through <instrument:object>")
    # ...> Command.match_syntax(%{
    # ...>   context: %{actor: {:thing, "actor"}},
    # ...>   command: ["look", "at", "the", "lit", "lamp", "through", "the", "big", "telescope"],
    # ...>   syntaxes: [syntax], adverbs: []
    # ...> })
    %{
      adverbs: [],
      command: ["look", "at", "the", "lit", "lamp", "through", "the",
       "big", "telescope"],
      direct: [
        {:object, :singular, [:me, :near], ["the", "lit", "lamp"]}
      ],
      instrument: [
        {:object, :singular, [:me, :near], ["the", "big", "telescope"]}
      ],
      syntax: %{
        pattern: [
          "at",
          {:direct, :object, :singular, [:me, :near]},
          "through",
          {:instrument, :object, :singular, [:me, :near]}
        ],
        short: "at <thing> through <object>",
        weight: 34
      }
    }
  """
  # %{command: ["look", "at", "the", "lit", "lamp", "through", "the", "big", "telescope"], adverbs: [], direct: [{:object, :singular, [:me, :near], ["the", "lit", "lamp"]}], instrument: [{:object, :singular, [:me, :near], ["the", "big", "telescope"]}], syntax: VerbSyntax.parse("at <direct:object'thing> through <instrument:object>")}
  def match_syntax(
        %{
          context: context,
          command: command,
          syntaxes: syntaxes,
          adverbs: adverbs
        } = state
      ) do
    case first_syntax_match(command, context, syntaxes) do
      nil ->
        nil

      match ->
        match
        |> Map.put(:adverbs, adverbs)
    end
  end

  # {["look", "at", "the", "floor"],
  #  %{actor: {:thing, "std:character#a90eedc5-8cf8-4abd-be27-9c7270b6e4bc"}},
  #  [
  #    %{
  #      actions: ["scan:item:brief", "finish:verb"],
  #      pattern: ["at", {:direct, :object, :singular, [:me, :near]}],
  #      short: "at <thing>",
  #      weight: 17
  #    },
  #    %{actions: ["scan:env:brief", "finish:verb"], pattern: [], short: "", weight: 0}
  #  ]}

  def first_syntax_match(_, _, []), do: nil

  def first_syntax_match([_ | bits] = command, context, [syntax | rest]) do
    case try_syntax_match(bits, syntax) do
      nil ->
        first_syntax_match(command, context, rest)

      match ->
        data =
          match
          |> Map.put(:syntax, syntax)
          |> Map.put(:command, command)

        case try_binding(context, data) do
          nil -> first_syntax_match(command, context, rest)
          binding -> binding
        end
    end
  end

  # def first_syntax_match(x, y, z) do
  #   IO.inspect({x, y, z})
  # end

  def try_binding(context, match) do
    case Binder.bind(context, match) do
      %{slots: slots, syntax: %{actions: events}} ->
        slots =
          @obj_slots
          |> Enum.reduce(slots, fn slot, slots ->
            case Map.get(slots, slot) do
              nil ->
                slots

              [] ->
                slots

              v ->
                Map.put(
                  slots,
                  slot,
                  v
                  |> accepts_events(to_string(slot), events, slots)
                  |> maybe_scalar
                )
            end
          end)
          |> Enum.map(fn {k, v} -> {to_string(k), v} end)
          |> Enum.into(%{})

        all_slots_filled =
          map_size(slots) == 0 or
            Enum.all?(slots, fn
              {_, []} -> false
              {_, nil} -> false
              _ -> true
            end)

        if all_slots_filled do
          match
          |> Map.put(:slots, slots)
          |> Map.put(:events, events)
        else
          nil
        end

      _ ->
        nil
    end
  end

  @doc """
  ## Examples

    iex> Command.try_syntax_match(["a", "red", "truck"], %{pattern: []})
    nil
  """
  def try_syntax_match(bits, %{pattern: pattern} = syntax) do
    # return nil if not a match - otherwise, return a structure with slots and such identified
    case pattern_match(%PatternMatch{
           command: bits,
           pattern: pattern,
           pattern_size: Enum.count(pattern),
           command_size: Enum.count(bits)
         }) do
      nil ->
        nil

      matches ->
        matches
        # now see if we can bind to objects given the matches
    end
  end

  def try_syntax_match(a, b) do
    nil
  end

  @doc """
  If the pattern matches the bits, then this will return a mapping of slots to
  word lists and information on how to resolve the word lists to objects, if necessary.

  This function has to manage backtracking if a guess doesn't work out.
  """
  def pattern_match(%{failed: true} = state) do
    nil
  end

  def pattern_match(
        %{
          pos: command_pos,
          command_size: command_size,
          pattern_pos: pattern_pos,
          pattern_size: pattern_size
        } = state
      )
      when command_pos >= command_size and pattern_pos < pattern_size,
      do: pattern_match(%{state | failed: true})

  def pattern_match(
        %{
          command_pos: command_pos,
          command_size: command_size,
          pattern_pos: pattern_pos,
          pattern_size: pattern_size,
          word_offset: word_offset,
          matches: matches,
          delayed: delayed
        } = state
      )
      when pattern_pos == pattern_size do
    # we're finished - just need to clean up any delayed pieces
    case delayed do
      [:optional] ->
        %{
          state
          | matches: [command_size | matches],
            delayed: [],
            word_offset: 0,
            command_pos: command_size
        }

      [:single_word] ->
        if command_pos < command_size - 1 do
          %{state | failed: true}
        else
          %{
            state
            | matches: [command_size | matches],
              delayed: [],
              word_offset: 0,
              command_pos: command_size
          }
        end

      [:string] ->
        %{
          state
          | matches: [command_size | matches],
            delayed: [],
            word_offset: 0,
            command_pos: command_size
        }

      [] ->
        if command_pos < command_size, do: %{state | failed: true}, else: state

      _ ->
        pos = command_pos - word_offset

        {matches, command_pos} =
          delayed
          |> Enum.reverse()
          |> Enum.reduce({matches, pos}, fn
            :optional, {[prev_pos | _] = matches, pos} ->
              {[prev_pos | matches], pos}

            atom, {matches, pos} when atom in [:single_word, :string] ->
              {[pos | matches], pos + 1}

            _, acc ->
              acc
          end)

        %{
          state
          | matches: [command_size | matches],
            delayed: [],
            word_offset: 0,
            command_pos: command_size
        }

        # command_pos < command_size ->
        #   %{state | failed: true}
    end
    |> Map.update!(:pattern_pos, fn v -> v + 1 end)
    |> pattern_match()
  end

  def pattern_match(%{pattern_pos: pattern_pos, pattern_size: pattern_size, delayed: []} = state)
      when pattern_pos >= pattern_size do
    %{matches: matches, command_size: command_size, pattern: pattern, command: command} = state
    skips = Enum.reverse([command_size | matches])
    # now match up skips with the slots and similar in the pattern
    # we want a mapping of slot name to string/info, numbers, etc.
    pattern
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {pat, idx}, acc ->
      case pat do
        word when is_binary(word) ->
          acc

        {slot, type, count, env} when is_atom(slot) and is_atom(type) ->
          Map.put(acc, slot, [
            {
              type,
              count,
              env,
              Enum.slice(command, Enum.at(skips, idx), Enum.at(skips, idx + 1))
            }
            | Map.get(acc, slot, [])
          ])

        {:word_list, word_list} ->
          Map.put(acc, word_list, [
            Enum.join(Enum.slice(command, Enum.at(skips, idx), Enum.at(skips, idx + 1)), " ")
            | Map.get(acc, word_list, [])
          ])

        atom when is_atom(atom) ->
          Map.put(acc, atom, [
            Enum.slice(
              command,
              Enum.at(skips, idx),
              Enum.at(skips, idx + 1) - Enum.at(skips, idx)
            )
            | Map.get(acc, atom, [])
          ])

        _ ->
          acc
      end
    end)
  end

  def pattern_match(%{pattern_pos: pattern_pos, pattern_size: pattern_size} = state)
      when pattern_pos >= pattern_size do
    %{
      command_size: command_size,
      word_offset: word_offset,
      matches: matches,
      delayed: delayed
    } = state

    pos = command_size - word_offset

    new_state = handle_delayed(%{state | command_pos: pos}, true)

    pattern_match(%{new_state | command_pos: command_size, word_offset: 0})
  end

  def pattern_match(state) do
    %{
      command_size: command_size,
      pattern: pattern,
      pattern_pos: pattern_pos
    } = state

    pattern
    |> Enum.at(pattern_pos)
    |> process_pattern(state)
    |> Map.update!(:pattern_pos, fn v -> v + 1 end)
    |> pattern_match()
  end

  def process_pattern(
        {slot, :player, count, _},
        %{
          last: last,
          delayed: delayed,
          word_offset: word_offset,
          command_pos: command_pos,
          command_size: command_size,
          matches: matches
        } = state
      )
      when is_atom(slot) and count in [:singular, :plural] do
    if last do
      %{
        state
        | delayed: [:single_word | delayed],
          word_offset: word_offset + 1,
          command_pos: command_pos + 1,
          failed: command_pos > command_size
      }
    else
      %{
        state
        | command_pos: command_pos + 1,
          matches: [command_pos | matches],
          failed: command_pos > command_size
      }
    end
  end

  def process_pattern(
        {slot, _, count, _},
        %{
          last: last,
          delayed: delayed,
          word_offset: word_offset,
          command_pos: command_pos,
          command_size: command_size
        } = state
      )
      when is_atom(slot) and count in [:singular, :plural] do
    if last do
      %{
        state
        | delayed: [:single_word | delayed],
          word_offset: word_offset + 1,
          command_pos: command_pos + 1
      }
    else
      %{
        state
        | delayed: [:string],
          last: :find_first,
          word_offset: word_offset + 1,
          command_pos: command_pos + 1
      }
    end
  end

  def process_pattern(:string, state) do
    %{command_pos: command_pos} = new_state = handle_delayed(state)

    %{
      new_state
      | delayed: [:string],
        word_offset: 1,
        command_pos: command_pos + 1,
        last: :find_last
    }
  end

  def process_pattern(
        :short_string,
        %{last: last, delayed: delayed, word_offset: word_offset, command_pos: command_pos} =
          state
      ) do
    delayed = if last, do: [:single_word | delayed], else: [:string]

    %{
      state
      | delayed: delayed,
        word_offset: word_offset + 1,
        command_pos: command_pos + 1,
        last: :find_first
    }
  end

  def process_pattern(
        :single_word,
        %{
          last: last,
          delayed: delayed,
          word_offset: word_offset,
          command_pos: command_pos,
          command_size: command_size,
          matches: matches
        } = state
      ) do
    if last do
      %{
        state
        | delayed: [:single_word | delayed],
          word_offset: word_offset + 1,
          command_pos: command_pos + 1,
          failed: command_pos >= command_size
      }
    else
      %{
        state
        | matches: [command_pos | matches],
          command_pos: command_pos + 1,
          failed: command_pos >= command_size
      }
    end
  end

  def process_pattern({:word_list, :number}, state) do
  end

  def process_pattern({:word_list, :fraction}, state) do
  end

  def process_pattern(
        {:word_list, word_list},
        %{matches: matches, command: command, command_pos: command_pos} = state
      )
      when is_atom(word_list) do
    # words = Config.master().word_list(word_list) -- [nil]
    words = word_list(word_list)

    words_by_count =
      Enum.group_by(words, fn
        word ->
          word
          |> String.split(" ")
          |> Enum.count()
      end)

    {min_count, max_count} =
      case map_size(words_by_count) do
        0 -> {0, 0}
        _ -> Enum.min_max(Map.keys(words_by_count))
      end

    count =
      max_count..min_count
      |> Enum.flat_map(fn size ->
        given = command |> Enum.slice(command_pos, size) |> Enum.join(" ")
        if given in words, do: [size], else: []
      end)
      |> List.first()

    if is_nil(count) do
      # no match
      %{state | failed: true}
    else
      %{state | matches: [command_pos + count | matches], command_pos: command_pos + count}
    end
  end

  # we treat a literal word as a single-member word list
  # a bare atom as a named word list
  @doc """
  ## Examples

    iex> Command.process_pattern("at", %Command.PatternMatch{command: ["at", "the"], command_pos: 0, command_size: 2, pattern: ["at", {:direct, :object, :singular, [:near, :me]}], pattern_pos: 0, pattern_size: 2, delayed: []})
    %Command.PatternMatch{command: ["at", "the"], command_pos: 1, command_size: 2, pattern: ["at", {:direct, :object, :singular, [:near, :me]}], pattern_pos: 0, pattern_size: 2, matches: [1, 0], delayed: []}
  """
  def process_pattern(
        word,
        %{
          last: last,
          command: command,
          command_pos: command_pos,
          command_size: command_size,
          pattern_pos: pattern_pos,
          matches: matches,
          delayed: delayed
        } = state
      )
      when is_binary(word) do
    new_state =
      case last do
        nil ->
          if word != Enum.at(command, command_pos) do
            %{state | failed: true}
          else
            %{state | matches: [command_pos + 1 | matches], command_pos: command_pos + 1}
          end

        :find_first ->
          # look through command for the word starting at pos
          tmp = command |> Enum.drop(command_pos) |> Enum.find_index(fn w -> w == word end)

          if is_nil(tmp) do
            %{state | failed: true}
          else
            {matches, command_pos} =
              delayed
              |> Enum.reverse()
              |> Enum.reduce({matches, command_pos + tmp}, fn
                :optional, {[prev_pos | _] = matches, pos} ->
                  {[prev_pos | matches], pos}

                atom, {matches, pos} when atom in [:single_word, :string] ->
                  {[pos - 1 | matches], pos + 1}

                _, acc ->
                  acc
              end)

            %{
              state
              | matches: [command_pos | matches],
                command_pos: command_pos + 1,
                delayed: [],
                last: nil
            }
          end

        :find_last ->
          tmp =
            command
            |> Enum.drop(command_pos)
            |> Enum.reverse()
            |> Enum.find_index(fn w -> w == word end)

          if is_nil(tmp),
            do: %{state | failed: true},
            else: handle_delayed(%{state | command_pos: command_size - tmp}, last)
      end
  end

  def handle_delayed(%{failed: true} = state), do: state

  def handle_delayed(
        %{matches: matches, command_pos: command_pos, delayed: delayed, word_offset: word_offset} =
          state,
        last \\ false
      ) do
    {matches, command_pos} =
      delayed
      |> Enum.reverse()
      |> Enum.reduce({matches, command_pos}, fn
        :optional, {[prev_pos | _] = matches, pos} ->
          {[prev_pos | matches], pos}

        atom, {matches, pos} when atom in [:single_word, :string] ->
          {[pos - if(last, do: 0, else: 1) | matches], pos + 1}

        _, acc ->
          acc
      end)

    %{
      state
      | matches: [command_pos | matches],
        command_pos: command_pos + 1,
        delayed: [],
        last: nil
    }
  end

  def word_list(:direction),
    do: ~w[east west north south up down northeast southwest northwest southeast]

  def word_list(_), do: []

  def maybe_scalar([v]), do: v
  def maybe_scalar(v), do: v

  def accepts_events(list, slot, [event | _], slots) when is_list(list) do
    Enum.filter(list, fn entity_id ->
      Militerm.Systems.Entity.can?(entity_id, event, slot, slots)
    end)
  end

  def accepts_events(entity_id, slot, [event | _], slots) do
    if Militerm.Systems.Entity.can?(entity_id, event, slot, slots), do: entity_id, else: []
  end
end
