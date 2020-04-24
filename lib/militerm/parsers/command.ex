defmodule Militerm.Parsers.Command do
  @moduledoc """
  This provides the methods to take player input and match it against the various
  verb syntax options to see which matches, if any. On success, indicates which objects or
  other values are in the slots.
  """

  alias Militerm.Binder
  alias Militerm.Services
  alias Militerm.Config

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
              actor: nil
  end

  def parse(command, context, syntax_provider) do
    %{command: String.split(command, ~r{\s+}), context: context}
    |> take_adverbs()
    |> fetch_syntaxes(syntax_provider)
    |> match_syntax()
  end

  def take_adverbs(state), do: Map.put(state, :adverbs, [])

  def fetch_syntaxes(%{command: [word | _]} = state, syntax_provider) do
    # get all syntaxes that start with the given word ... then whittle down
    # each syntax will be associated with a given event seqence (multiple syntaxes can go with the
    # same sequence, but only one sequence per syntax)
    # syntaxes should be sorted by weight - heaviest weight first
    syntaxes = syntax_provider.get_syntaxes(:players, word)

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

    # iex> syntax = VerbSyntax.parse("at <direct:object'thing>")
    # ...> Command.match_syntax(%{actor: :actor, command: ["look", "at", "the", "lamp"], syntaxes: [syntax], adverbs: []})
    # %{command: ["look", "at", "the", "lamp"], adverbs: [], slots: %{"direct" => [{:object, :singular, [:me, :near], "the lamp"}]}, syntax: VerbSyntax.parse("at <direct:object'thing>")}
    #
    # iex> syntax = VerbSyntax.parse("at <direct:object'thing> through <instrument:object>")
    # ...> Command.match_syntax(%{
    # ...>   actor: :actor,
    # ...>   command: ["look", "at", "the", "lit", "lamp", "through", "the", "big", "telescope"],
    # ...>   syntaxes: [syntax], adverbs: []
    # ...> })
    # %{
    #   adverbs: [],
    #   command: ["look", "at", "the", "lit", "lamp", "through", "the",
    #    "big", "telescope"],
    #   slots: %{
    #     "direct" => [
    #       {:object, :singular, [:me, :near], "the lit lamp"}
    #     ],
    #     "instrument" => [
    #       {:object, :singular, [:me, :near], "the big telescope"}
    #     ]
    #   },
    #   syntax: %{
    #     pattern: [
    #       {:word_list, ["at"], nil},
    #       {:direct, :object, :singular, [:me, :near]},
    #       {:word_list, ["through"], nil},
    #       {:instrument, :object, :singular, [:me, :near]}
    #     ],
    #     short: "at <thing> through <object>",
    #     weight: 34
    #   }
    # }
  """
  # %{command: ["look", "at", "the", "lit", "lamp", "through", "the", "big", "telescope"], adverbs: [], direct: [{:object, :singular, [:me, :near], ["the", "lit", "lamp"]}], instrument: [{:object, :singular, [:me, :near], ["the", "big", "telescope"]}], syntax: VerbSyntax.parse("at <direct:object'thing> through <instrument:object>")}
  def match_syntax(
        %{context: context, command: command, syntaxes: syntaxes, adverbs: adverbs} = state
      ) do
    case first_syntax_match(command, context, syntaxes) do
      nil ->
        nil

      match ->
        match
        |> Map.put(:command, command)
        |> Map.put(:adverbs, adverbs)
    end
  end

  def first_syntax_match(_, _, []), do: nil

  def first_syntax_match(bits, context, [syntax | rest]) do
    case try_syntax_match(bits, context, syntax) do
      nil -> first_syntax_match(bits, context, rest)
      match -> Map.put(match, :syntax, syntax)
    end
  end

  @doc """
  ## Examples
    iex> Command.try_syntax_match(["a", "red", "truck"], %{pattern: []})
    nil
  """
  def try_syntax_match(bits, context, %{word_lists: word_lists, pattern: pattern} = syntax) do
    # return nil if not a match - otherwise, return a structure with slots and such identified
    case Militerm.Parsers.Command.PatternMatcher.pattern_match(bits, pattern, word_lists) do
      nil ->
        nil

      matches ->
        Militerm.Systems.Commands.Binder.bind(context, %{
          slots: assign_matches_to_slots(bits, pattern, matches)
        })
    end
  end

  def try_syntax_match(a, b) do
    nil
  end

  def assign_matches_to_slots(bits, pattern, [_ | matches]) do
    pattern
    |> Enum.zip(Enum.chunk_every(matches, 2, 1))
    |> Enum.map(&assign_match_to_slot(&1, bits))
    |> Enum.reject(&is_nil/1)
    |> Enum.group_by(&elem(&1, 0))
    |> Enum.map(fn {key, values} ->
      {key, maybe_scalar(Enum.map(values, &elem(&1, 1)))}
    end)
    |> Enum.into(%{})
  end

  defp maybe_scalar([]), do: nil
  defp maybe_scalar([thing]), do: thing
  defp maybe_scalar(list), do: list

  def assign_match_to_slot({pattern, [start, stop]}, bits) do
    phrase = Enum.join(Enum.slice(bits, start, stop - start), " ")

    case pattern do
      {:number, nil} -> {"number", {:number, phrase}}
      {:number, name} -> {name, {:number, phrase}}
      {:fraction, nil} -> {"fraction", {:fraction, phrase}}
      {:fraction, name} -> {name, {:fraction, phrase}}
      {slot, type, count, env} -> {to_string(slot), {type, count, env, phrase}}
      {:string, nil} -> {"string", phrase}
      {:string, name} -> {name, phrase}
      {:quoted_string, nil} -> {"quoted_string", remove_quotes(phrase)}
      {:quoted_string, name} -> {name, remove_quotes(phrase)}
      {:short_string, nil} -> {"string", phrase}
      {:short_string, name} -> {name, phrase}
      {:single_word, nil} -> {"word", phrase}
      {:single_word, name} -> {name, phrase}
      {:word_list_spaces, _, nil} -> nil
      {:word_list_spaces, _, name} -> {name, phrase}
      {:word_list, _, nil} -> nil
      {:word_list, _, name} -> {name, phrase}
      _ -> nil
    end
  end

  def remove_quotes(string) do
    String.slice(string, 1, String.length(string) - 2)
  end
end
