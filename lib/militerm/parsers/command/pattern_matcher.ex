defmodule Militerm.Parsers.Command.PatternMatcher do
  @moduledoc false

  #
  # Based on the pattern matcher in the Discworld mudlib.
  #

  @doc """
  ## Examples

    iex> PatternMatcher.pattern_match(["", "at", "this"], [{:word_list, ["at"], nil}, {:word_list, ["this"], nil}])
    [0, 1, 2, 3]

    iex> PatternMatcher.pattern_match(["", "under", "neath", "this"], [{:word_list_spaces, [~w[under neath]], nil}, {:word_list, ["this"], nil}])
    [0, 1, 3, 4]

    iex> PatternMatcher.pattern_match(["", "at", "the", "lamp"], [{:word_list, ["at"], nil}, {:direct, :object, :singular, [:me, :here]}])
    [0, 1, 2, 4]

    iex> PatternMatcher.pattern_match(["", "at", "the", "lit", "lamp", "through", "the", "big", "telescope"], [
    ...>   {:word_list, ["at"], nil},
    ...>   {:direct, :object, :singular, [:me, :near]},
    ...>   {:word_list, ["through"], nil},
    ...>   {:instrument, :object, :singular, [:me, :near]}
    ...> ])
    [0, 1, 2, 5, 6, 9]
  """
  def pattern_match(bits, pattern) do
    state =
      do_pattern_match(
        %{
          pos: 1,
          wcount: 1,
          matches: [0],
          delayed: [],
          last: nil,
          failed: false,
          word_offset: 0,
          bits: bits,
          bits_size: Enum.count(bits)
        },
        pattern
      )

    %{delayed: delayed, word_offset: word_offset, bits_size: bits_size, pos: pos} = state

    state =
      case delayed do
        [] ->
          state

        _ ->
          pos = bits_size + 1 - word_offset

          handle_final_delayed(state)
      end

    %{failed: failed, pos: pos, matches: matches} = state

    if not failed and pos == bits_size do
      [bits_size | matches] |> Enum.reverse()
    end
  end

  def do_pattern_match(%{failed: true} = state, _), do: state
  def do_pattern_match(%{} = state, []), do: state

  def do_pattern_match(state, [pattern_bit | rest_of_pattern]) do
    %{pos: pos, bits_size: bits_size} = state

    state = if pos >= bits_size, do: %{state | failed: true}, else: state

    state =
      case pattern_bit do
        {_, _, _, _} -> do_object_match(state, pattern_bit)
        {:string, _} -> do_string_match(state)
        {:quoted_string, _} -> do_quoted_string_match(state)
        {:short_string, _} -> do_short_string_match(state)
        {:single_word, _} -> do_single_word_match(state)
        {:number, _} -> do_number_match(state, :number)
        {:fraction, _} -> do_number_match(state, :fraction)
        {:optional_spaces, _, _} -> do_optional_match(state, pattern_bit)
        {:optional, _, _} -> do_optional_match(state, pattern_bit)
        {:word_list_spaces, _, _} -> do_optional_match(state, pattern_bit)
        {:word_list, _, _} -> do_word_list_match(state, pattern_bit)
      end

    do_pattern_match(state, rest_of_pattern)
  end

  def do_object_match(state, {_, type, _, _}) do
    %{
      failed: failed,
      pos: pos,
      bits_size: bits_size,
      last: last,
      delayed: delayed,
      matches: matches,
      word_offset: word_offset
    } = state

    if type == :player do
      if last do
        %{
          state
          | delayed: [:single_word | delayed],
            word_offset: word_offset + 1,
            pos: pos + 1,
            failed: failed || pos >= bits_size
        }
      else
        %{
          state
          | pos: pos + 1,
            matches: [pos | matches],
            failed: failed || pos >= bits_size
        }
      end
    else
      if last do
        %{
          state
          | delayed: [:single_word | delayed],
            word_offset: word_offset + 1,
            pos: pos + 1
        }
      else
        %{
          state
          | delayed: [:string | delayed],
            last: :find_first,
            word_offset: word_offset + 1,
            pos: pos + 1
        }
      end
    end
  end

  def do_string_match(state) do
    %{last: last, pos: pos, word_offset: word_offset, delayed: delayed} = state

    state =
      if last do
        delayed
        |> Enum.reverse()
        |> Enum.reduce(%{state | pos: pos - (word_offset - 1)}, fn
          :string, %{matches: matches, pos: pos} = state ->
            %{state | matches: [pos - 1 | matches], pos: pos + 1}

          :optional, %{matches: [last_pos | _] = matches} = state ->
            %{state | matches: [last_pos | matches]}

          :single_word, %{matches: matches, pos: pos} = state ->
            %{state | matches: [pos - 1 | matches], pos: pos + 1}
        end)
      else
        state
      end

    %{pos: pos} = state

    %{state | delayed: [:string], word_offset: 1, pos: pos + 1, last: :find_last}
  end

  def do_quoted_string_match(state) do
    state = handle_delayed_for_quoted_string(state)

    %{pos: pos, bits_size: bits_size} = state

    state = if pos > bits_size, do: %{state | failed: true}, else: state

    %{failed: failed, bits: bits, matches: matches} = state

    if failed do
      state
    else
      quote_char = String.first(Enum.at(bits, pos))

      if quote_char in ~w[" ' `] do
        needle =
          bits
          |> Enum.with_index()
          |> Enum.drop(pos)
          |> Enum.find(fn {w, _} -> String.last(w) == quote_char end)

        case needle do
          {_, i} ->
            %{state | matches: [i | matches], pos: i + 1}

          _ ->
            %{state | failed: true}
        end
      else
        %{state | failed: true}
      end
    end
  end

  def do_short_string_match(state) do
    %{last: last, delayed: delayed, word_offset: word_offset, pos: pos} = state

    if last do
      %{
        state
        | delayed: [:single_word | delayed],
          word_offset: word_offset + 1,
          pos: pos + 1,
          last: :find_first
      }
    else
      %{
        state
        | delayed: [:string | delayed],
          word_offset: word_offset + 1,
          pos: pos + 1,
          last: :find_first
      }
    end
  end

  def do_single_word_match(state) do
    %{last: last, delayed: delayed, word_offset: word_offset, pos: pos, matches: matches} = state

    if last do
      %{state | delayed: [:single_word | delayed], word_offset: word_offset + 1, pos: pos + 1}
    else
      %{state | matches: [pos | matches], pos: pos + 1}
    end
  end

  def handle_delayed_for_quoted_string(%{last: nil} = state), do: state

  def handle_delayed_for_quoted_string(state) do
    state = find_quoted_string_start(state)

    %{pos: pos, bits_size: bits_size, word_offset: word_offset, delayed: delayed} = state

    if pos < bits_size do
      delayed
      |> Enum.reverse()
      |> Enum.reduce(%{state | pos: pos - word_offset, last: nil}, fn
        :string, %{matches: matches, pos: pos} = state ->
          %{state | matches: [pos | matches], pos: pos + 1}

        :optional, %{matches: [last_pos | _] = matches} = state ->
          %{state | matches: [last_pos | matches]}

        :single_word, %{matches: matches, pos: pos} = state ->
          %{state | matches: [pos | matches], pos: pos + 1}
      end)
    else
      %{state | failed: true}
    end
  end

  def find_quoted_string_start(%{pos: pos, bits_size: bits_size, bits: bits} = state)
      when pos < bits_size do
    if String.first(Enum.at(bits, pos)) in ~w[" ' `] do
      state
    else
      find_quoted_string_start(%{state | pos: pos + 1})
    end
  end

  def find_quoted_string_start(state), do: state

  def do_number_match(state, type) do
    state = %{state | failed: true}
    %{last: last, bits: bits, pos: pos} = state

    state =
      case last do
        :find_last ->
          needle =
            bits
            |> Enum.with_index()
            |> Enum.drop(pos)
            |> Enum.reverse()
            |> Enum.find(fn {w, _} ->
              String.match?(w, ~r{^\d}) or (type != :fraction and String.match?(w, ~r{^-\d}))
            end)

          case needle do
            {w, j} ->
              if type != :fraction or Enum.count(String.split(w, "/", trim: true)) == 2 do
                %{state | failed: false, pos: j + 1}
              else
                state
              end

            _ ->
              state
          end

        :find_first ->
          needle =
            bits
            |> Enum.with_index()
            |> Enum.drop(pos)
            |> Enum.find(fn {w, _} ->
              String.match?(w, ~r{^\d}) or (type != :fraction and String.match?(w, ~r{^-\d}))
            end)

          case needle do
            {w, j} ->
              if type != :fraction or Enum.count(String.split(w, "/", trim: true)) == 2 do
                %{state | failed: false, pos: j + 1}
              else
                state
              end

            _ ->
              state
          end

        _ ->
          w = Enum.at(bits, pos)

          if String.match?(w, ~r{^\d}) or (type != :fraction and String.match?(w, ~r{^-\d})) do
            %{state | failed: false, pos: pos + 1}
          else
            state
          end
      end

    case state do
      %{failed: true} ->
        state

      %{delayed: delayed, word_offset: word_offset, pos: pos} ->
        %{pos: pos, matches: matches} =
          state =
          delayed
          |> Enum.reverse()
          |> Enum.reduce(%{state | delayed: [], word_offset: 0, pos: pos - word_offset}, fn
            :string, %{matches: matches, pos: pos} = state ->
              %{state | matches: [pos - 1 | matches], pos: pos + 1}

            :optional, %{matches: [last_pos | _] = matches} = state ->
              %{state | matches: [last_pos | matches]}

            :single_word, %{matches: matches, pos: pos} = state ->
              %{state | matches: [pos - 1 | matches], pos: pos + 1}
          end)

        %{state | last: nil, matches: [pos - 1 | matches]}
    end
  end

  def do_optional_match(state, {:optional_spaces, _, _} = pattern_bit) do
    do_word_list_match(state, pattern_bit, true, true)
  end

  def do_optional_match(state, {:optional, _, _} = pattern_bit) do
    do_word_list_match(state, pattern_bit, false, true)
  end

  def do_optional_match(state, {:word_list_spaces, _, _} = pattern_bit) do
    do_word_list_match(state, pattern_bit, true, false)
  end

  def do_word_list_match(state, {_, elem_type, _}, spaces \\ false, opt \\ false) do
    {spaces, elms} =
      case elem_type do
        words when is_list(words) ->
          {spaces, words}

        binary when is_binary(binary) ->
          case query_word_list(binary) do
            nil ->
              {false, nil}

            [] ->
              {false, []}

            list ->
              spaces =
                Enum.any?(list, fn
                  [_, _ | _] -> true
                  _ -> false
                end)

              {spaces, list}
          end
      end

    state = do_word_list_match_with_elements(%{state | wcount: 1}, elms, spaces, opt)

    %{
      failed: failed,
      last: last,
      delayed: delayed,
      matches: matches,
      pos: pos,
      wcount: wcount
    } = state

    cond do
      opt and failed ->
        if last do
          %{state | failed: false, delayed: [:optional | delayed], last: nil}
        else
          %{state | failed: false, matches: [pos - 1 | matches], last: nil}
        end

      not failed ->
        state = %{state | pos: pos + wcount}

        state =
          if Enum.any?(delayed) do
            %{pos: pos, word_offset: word_offset} = state

            delayed
            |> Enum.reverse()
            |> Enum.reduce(%{state | pos: pos - word_offset, delayed: [], word_offset: 0}, fn
              :string, %{matches: matches, pos: pos} = state ->
                %{state | matches: [pos - 1 | matches], pos: pos + 1}

              :optional, %{matches: [last_pos | _] = matches} = state ->
                %{state | matches: [last_pos | matches]}

              :single_word, %{matches: matches, pos: pos} = state ->
                %{state | matches: [pos - 1 | matches], pos: pos + 1}
            end)
            |> Map.put(:pos, pos)
          else
            state
          end

        %{pos: pos, matches: matches, wcount: wcount} = state
        %{state | last: nil, pos: pos, matches: [pos - wcount | matches], wcount: 1}

      :else ->
        %{state | last: nil, wcount: 1}
    end
  end

  def do_word_list_match_with_elements(state, [], _, _), do: %{state | failed: true}
  def do_word_list_match_with_elements(state, nil, _, _), do: %{state | failed: true}

  def do_word_list_match_with_elements(state, elms, spaces, opt) do
    %{
      last: last,
      failed: failed,
      matches: matches,
      word_offset: word_offset,
      bits: bits,
      bits_size: bits_size,
      pos: pos
    } = state

    cond do
      !(last || failed || spaces) ->
        if Enum.at(bits, pos) in elms do
          state
        else
          %{state | failed: true}
        end

      Enum.count(elms) == 1 && last == :find_first && !spaces ->
        [elm] = elms

        needle =
          bits
          |> Enum.with_index()
          |> Enum.drop(pos)
          |> Enum.find(fn {w, _} -> w == elm end)

        case needle do
          {_, i} ->
            %{state | pos: i, word_offset: word_offset + i - pos}

          _ ->
            %{state | failed: true}
        end

      not spaces ->
        tmp = Enum.drop(bits, pos) -- elms

        if Enum.count(tmp) < bits_size - pos do
          if last == :find_first do
            {{_, i}, _} =
              bits
              |> Enum.with_index()
              |> Enum.drop(pos)
              |> Enum.zip(tmp)
              |> Enum.find(fn {{x, _}, y} -> x != y end)

            %{state | pos: i - 1}
          else
            {{_, i}, _} =
              bits
              |> Enum.with_index()
              |> Enum.drop(pos)
              |> Enum.zip(tmp)
              |> Enum.reverse()
              |> Enum.find(fn {{x, _}, y} -> x != y end)

            %{state | pos: i + 1}
          end
        else
          %{state | failed: true}
        end

      :else_spaces ->
        if last do
          bits_here =
            bits
            |> Enum.with_index()
            |> Enum.drop(pos)

          if last == :find_first do
            found =
              elms
              |> Enum.find_value(fn e ->
                e_size = Enum.count(e)

                needle =
                  bits_here
                  |> Enum.chunk_every(e_size, 1)
                  |> Enum.find(fn b ->
                    e == Enum.map(b, fn {w, _} -> w end)
                  end)

                case needle do
                  [{_, i} | _] = list ->
                    {i, e_size}

                  _ ->
                    nil
                end
              end)

            case found do
              {pos, wcount} -> %{state | pos: pos, wcount: wcount}
              _ -> %{state | failed: true}
            end
          else
            bits_here = bits_here |> Enum.reverse()

            found =
              elms
              |> Enum.find_value(fn e ->
                e_size = Enum.count(e)

                needle =
                  bits_here
                  |> Enum.chunk_every(e_size, 1)
                  |> Enum.find(fn b ->
                    Enum.reverse(e) == Enum.map(b, fn {w, _} -> w end)
                  end)

                case needle do
                  [_ | _] = list ->
                    {_, i} = List.last(list)
                    {i, e_size}

                  _ ->
                    nil
                end
              end)

            case found do
              {pos, wcount} -> %{state | pos: pos, wcount: wcount}
              _ -> %{state | failed: true}
            end
          end
        else
          bits_here = Enum.drop(bits, pos)

          elem =
            elms
            |> Enum.find(fn e ->
              e == Enum.take(bits_here, Enum.count(e))
            end)

          if elem do
            %{state | wcount: Enum.count(elem)}
          else
            %{state | failed: true}
          end
        end
    end
  end

  def handle_final_delayed(state) do
    %{delayed: delayed, bits_size: bits_size, word_offset: word_offset, pos: pos} = state

    state =
      delayed
      |> Enum.reverse()
      |> Enum.reduce(%{state | pos: pos - word_offset + 1}, fn
        :string, %{matches: matches, pos: pos} = state ->
          %{state | matches: [pos - 1 | matches], pos: pos + 1}

        :optional, %{matches: [last_pos | _] = matches} = state ->
          %{state | matches: [last_pos | matches]}

        :single_word, %{matches: matches, pos: pos} = state ->
          %{state | matches: [pos - 1 | matches], pos: pos + 1}
      end)

    %{state | pos: bits_size, word_offset: 0, delayed: [], last: nil}
  end

  def to_tuple(tuples) when is_tuple(tuples), do: tuples
  def to_tuple(list) when is_list(list), do: List.to_tuple(list)

  def query_word_list("direction") do
    ~w[north south east west up down northeast northwest southeast southwest out]
  end
end
