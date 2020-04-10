defmodule Militerm.Parsers.SimpleResponse do
  @moduledoc ~S"""
    The response system allows NPCs to map text string patterns to
    events. This is a fairly generic system, so the scripting needs to
    supply the string being matched as well as the set of matches. The
    returned event is then triggered by the script as well.

  response:
    set-name:
      - pattern: pattern
        events:
          - event1
          - event2

  The pattern is a regex with named captures available.

  This should be sufficient to build a bot based on the old Eliza game.
  """

  @doc """
  Takes a pattern and returns the Elixir regex that can match against
  a string.

  Patterns:
    $name - a single word
    $name* - zero, one, or more words
    $name? - zero or one word
    $name+ - one or more words
    $$ - literal dollar sign
    
  ## Examples

    iex> Regex.named_captures(SimpleResponse.parse("This is fun!"), "This is fun!")
    %{}
    
    iex> Regex.named_captures(SimpleResponse.parse("$x* hello $y*"), "Why hello there")
    %{"x" => "Why", "y" => "there"}
    
    iex> Regex.named_captures(SimpleResponse.parse("$_* hello $y*"), "Why hello there")
    %{"y" => "there"}
  """
  def parse(pattern) do
    [literal | rest] = String.split(pattern, ~r{\s*\$})

    raw =
      [prepare_literal(literal) | compile_pattern_bits(rest)]
      |> Enum.map(&Regex.source/1)
      |> Enum.join("")

    Regex.compile!("^#{raw}$")
  end

  def compile_pattern_bits(list, acc \\ [])

  def compile_pattern_bits([], acc), do: Enum.reverse(acc)

  def compile_pattern_bits([<<"$", _::binary>> = literal | rest], acc) do
    compile_pattern_bits(rest, [Regex.escape(literal) | acc])
  end

  def compile_pattern_bits([match | rest], acc) do
    case Regex.run(~r{^(_|[a-zA-Z]+)([?*+]?)\s*(.*)}, match, capture: :all_but_first) do
      [name, quantifier, literal] ->
        compile_pattern_bits(rest, [
          prepare_literal(literal),
          prepare_match(name, quantifier)
          | acc
        ])

      nil ->
        compile_pattern_bits(rest, [prepare_literal("$#{match}") | acc])
    end
  end

  def prepare_literal(literal) do
    literal
    |> Regex.escape()
    |> String.replace(~r{(\\ )+}, ~S"\s+")
    |> Regex.compile!()
  end

  def prepare_match(name, "") do
    Regex.compile!("\\b\\s*(#{capture(name)}\\S+)\\b\\s*")
  end

  def prepare_match(name, "?") do
    Regex.compile!("\\b\\s*(#{capture(name)}(\\S+)?)\\b\\s*")
  end

  def prepare_match(name, "*") do
    Regex.compile!("\\b\\s*(#{capture(name)}((\\S+(\\s+\\S+)*))?)\\b\\s*")
  end

  def prepare_match(name, "+") do
    Regex.compile!("\\b\\s*(#{capture(name)}(\\S+(\\s+\\S+)*))\\b\\s*")
  end

  def capture("_"), do: ""
  def capture(name), do: "?<#{name}>"
end
