defmodule Militerm.Parsers.VerbSyntax do
  @moduledoc """
  Provides a parser to take a simple string description of a verb form and parse it into
  something that can be matched against player input.
  """

  @doc """
  Parses the string into a set of directives and texts
  ## Examples
  iex> VerbSyntax.parse("[<adverb>] at <direct:object'thing> {through|with} <instrument:object:me>")
  %{
    pattern: [
      {:optional, [{:word_list, :adverb}]}, "at",
      {:direct, :object, :singular, [:me, :near]},
      {:word_list, ["through", "with"]},
      {:instrument, :object, :singular, [:me]}
    ],
    short: "[<adverb>] at <thing> {through|with} <object>",
    weight: 39
  }

  iex> VerbSyntax.parse("<number> <direct:objects'things> with <indirect:object:me>")
  %{
    pattern: [
      {:word_list, :number},
      {:direct, :object, :plural, [:me, :near]},
      "with",
      {:indirect, :object, :singular, [:me]}
    ],
    short: "<number> <things> with <object>",
    weight: 34
  }

  iex> VerbSyntax.parse("<direct:object:me'something> with <string:quoted'phrase>")
  %{
    pattern: [
      {:direct, :object, :singular, [:me]},
      "with",
      :quoted_string
    ],
    short: "<something> with \\"<phrase>\\"",
    weight: 25
  }
  """
  # {pattern, short, weight}
  def parse(string) when is_binary(string),
    do: parse(%{source: string, pattern: [], short: [], weight: 0})

  def parse(error) when is_tuple(error), do: error

  def parse(%{source: "", pattern: pattern, short: short, weight: weight} = state) do
    %{
      pattern: Enum.reverse(pattern),
      short: String.trim(to_string(Enum.reverse(short))),
      weight: weight
    }
  end

  def parse(state) do
    state
    |> trim_leading_space()
    |> try_string()
    |> trim_leading_space()
    |> try_slot()
    |> trim_leading_space()
    |> try_word_list()
    |> trim_leading_space()
    |> try_optional()
    |> trim_leading_space()
    |> expect_word()
    |> parse()
  end

  def trim_leading_space(%{source: source} = state) do
    %{state | source: String.trim_leading(source)}
  end

  def trim_leading_space(state), do: state

  def try_string(%{
        source: <<"<string:", rest::binary>>,
        pattern: pattern,
        short: short,
        weight: weight
      }) do
    # allow arbitrary string input in a command
    case parse_string_expectation(rest) do
      {:error, _} = error ->
        error

      {type, name, heft, remaining} ->
        %{
          source: remaining,
          pattern: [type | pattern],
          short: [[" ", name] | short],
          weight: weight + heft
        }
    end
  end

  def try_string(%{
        source: <<"<string>", rest::binary>>,
        pattern: pattern,
        short: short,
        weight: weight
      }) do
    # allow arbitrary string input in a command

    %{
      source: rest,
      pattern: [:string | pattern],
      short: [" string" | short],
      weight: weight + 5
    }
  end

  def try_string(%{
        source: <<"<string'", rest::binary>>,
        pattern: pattern,
        short: short,
        weight: weight
      }) do
    # allow arbitrary string input in a command
    case String.split(rest, ">", parts: 2) do
      [_] ->
        {:error, "String slot not terminated"}

      [name, remaining] ->
        %{
          source: remaining,
          pattern: [:string | pattern],
          short: [[" ", name] | short],
          weight: weight + 5
        }
    end
  end

  def try_string(state), do: state

  def try_slot(%{source: <<"<", rest::binary>>, pattern: pattern, short: short, weight: weight}) do
    # parse slot description
    case parse_slot(rest) do
      {:error, _} = error ->
        error

      {:ok, slot, short_bit, heft, remaining} ->
        %{
          source: remaining,
          pattern: [slot | pattern],
          short: [[" ", short_bit] | short],
          weight: weight + heft
        }
    end
  end

  def try_slot(state), do: state

  def try_word_list(%{
        source: <<"{", rest::binary>>,
        pattern: pattern,
        short: short,
        weight: weight
      }) do
    # parse word option list
    case parse_options(rest) do
      {:error, _} = error ->
        error

      {words, short_bit, heft, remaining} ->
        %{
          source: remaining,
          pattern: [words | pattern],
          short: [[" ", short_bit] | short],
          weight: weight + heft
        }
    end
  end

  def try_word_list(state), do: state

  def try_optional(%{
        source: <<"[", rest::binary>>,
        pattern: pattern,
        short: short,
        weight: weight
      }) do
    # parse optional pattern
    case String.split(rest, "]", parts: 2) do
      [optional, remaining] ->
        %{pattern: optional_pattern, short: optional_short, weight: heft} = parse(optional)

        %{
          source: remaining,
          pattern: [{:optional, optional_pattern} | pattern],
          short: [[" [", optional_short, "]"] | short],
          weight: weight + div(heft, 2)
        }

      otherwise ->
        {:error, "missing closing ]"}
    end
  end

  def try_optional(state), do: state

  def expect_word(%{source: ""} = state), do: state

  def expect_word(%{source: string, pattern: pattern, short: short, weight: weight} = state) do
    # find the first word (to a space or end of sentence) and add it to the pattern as a word literal
    if String.match?(string, ~r{^[A-Za-z0-9]}) do
      case String.split(string, " ", parts: 2) do
        [word, remaining] ->
          %{
            source: remaining,
            pattern: [word | pattern],
            short: [[" ", word] | short],
            weight: weight + 10
          }

        [word] ->
          %{
            source: "",
            pattern: [word | pattern],
            short: [[" ", word] | short],
            weight: weight + 10
          }
      end
    else
      state
    end
  end

  def parse_slot(string) do
    [description, remaining] = String.split(string, ">", parts: 2)

    [bits, maybe_name] =
      case String.split(description, "'", parts: 2) do
        [_, _] = result -> result
        [result] -> [result, nil]
      end

    bits = String.split(bits, ":")

    {pattern, name, heft} =
      case bits do
        [word] ->
          # pre-defined word list
          {
            {:word_list, String.to_atom(word)},
            if(is_nil(maybe_name), do: word, else: maybe_name),
            10
          }

        [slot_name, object_type | env_bits] ->
          slot = String.to_atom(slot_name)

          with {:ok, type, number} <- interpret_objective_type(object_type),
               {:ok, env} <- interpret_objective_env(env_bits) do
            # part of speech, etc.
            {
              {slot, type, number, env},
              if(is_nil(maybe_name), do: object_type, else: maybe_name),
              7
            }
          else
            error -> error
          end
      end

    {:ok, pattern, ["<", name, ">"], heft, remaining}
  end

  def parse_options(string) do
    [words, remaining] = String.split(string, "}", parts: 2)
    bits = String.split(words, "|", trim: true)
    {{:word_list, bits}, ["{", Enum.join(bits, "|"), "}"], 10, remaining}
  end

  def parse_string_expectation(string) do
    case String.split(string, ">", parts: 2) do
      [definition, rest] ->
        case String.split(definition, "'", parts: 2) do
          [type, name] ->
            name = if type == "quoted", do: ["\"<", name, ">\""], else: ["<", name, ">"]

            case type do
              "quoted" -> {:quoted_string, name, 8, rest}
              "small" -> {:short_string, name, 6, rest}
              "long" -> {:long_string, name, 5, rest}
              _ -> {:string, name, 5, rest}
            end

          [type] ->
            name = if type == "quoted", do: "\"<string>\"", else: "<string>"

            case type do
              "quoted" -> {:quoted_string, name, 8, rest}
              "small" -> {:short_string, name, 6, rest}
              "long" -> {:long_string, name, 5, rest}
              _ -> {:string, name, 5, rest}
            end
        end

      _ ->
        {:error, "Missing > in <string:...>"}
    end
  end

  def interpret_objective_type(type) do
    case type do
      "living" ->
        {:ok, :living, :singular}

      "livings" ->
        {:ok, :living, :plural}

      "object" ->
        {:ok, :object, :singular}

      "objects" ->
        {:ok, :object, :plural}

      "player" ->
        {:ok, :player, :singular}

      "players" ->
        {:ok, :player, :plural}

      _ = unknown ->
        {:error, "Unknown type of direct (#{unknown})."}
    end
  end

  def interpret_objective_env(envs, acc \\ [])

  def interpret_objective_env([], []), do: {:ok, [:me, :near]}

  def interpret_objective_env([], acc), do: {:ok, Enum.reverse(acc)}

  def interpret_objective_env(["here" | rest], acc),
    do: interpret_objective_env(rest, [:here | acc])

  def interpret_objective_env(["me" | rest], acc), do: interpret_objective_env(rest, [:me | acc])

  def interpret_objective_env(["direct" | rest], acc),
    do: interpret_objective_env(rest, [:direct | acc])

  def interpret_objective_env(["indirect" | rest], acc),
    do: interpret_objective_env(rest, [:indirect | acc])

  def interpret_objective_env(["close" | rest], acc),
    do: interpret_objective_env(rest, [:close | acc])

  def interpret_objective_env(["near" | rest], acc),
    do: interpret_objective_env(rest, [:near | acc])

  def interpret_objective_env([env | _], _), do: {:error, "Unknown environment (#{env})"}
end
