defmodule Militerm.English do
  import Militerm.EnglishMacros

  @abnormal_plurals %{
    "moose" => "moose",
    "mouse" => "mouse",
    "die" => "dice",
    "index" => "indices",
    "human" => "humans",
    "sheep" => "sheep",
    "fish" => "fish",
    "child" => "children",
    "ox" => "oxen",
    "tooth" => "teeth",
    "deer" => "deer",
    "sphinx" => "sphinges"
  }

  @doc """
  Return the English plural of a singular noun.

  Also returns the English singular of a plural verb.

  ## Examples

      iex> English.pluralize("")
      ""

      iex> English.pluralize("sheep")
      "sheep"

      iex> English.pluralize("bench")
      "benches"

      iex> English.pluralize("buoy")
      "buoys"

      iex> English.pluralize("ivy")
      "ivies"

      iex> English.pluralize(["sheep", "coin"])
      ["sheep", "coins"]
  """
  def pluralize(""), do: ""

  def pluralize(word) when is_binary(word) do
    if Map.has_key?(@abnormal_plurals, word) do
      Map.get(@abnormal_plurals, word)
    else
      word
      |> String.reverse()
      |> do_reverse_plural
      |> String.reverse()
    end
  end

  def pluralize(list) when is_list(list), do: pluralize_list(list, [])

  pluralize("ch", "ches")
  pluralize("hs", "shes")
  pluralize("ff", "ves")
  pluralize("fe", "ves")
  pluralize("us", "i")
  pluralize("um", "a")
  pluralize("ef", "efs")
  pluralize("ay", "ays")
  pluralize("ey", "eys")
  pluralize("iy", "iys")
  pluralize("oy", "oys")
  pluralize("uy", "uys")

  pluralize("o", "oes")
  pluralize("x", "xes")
  pluralize("s", "ses")
  pluralize("f", "ves")
  pluralize("y", "ies")

  defp do_reverse_plural(str), do: "s" <> str

  def pluralize_list([], acc), do: Enum.reverse(acc)

  def pluralize_list([word | rest], acc) do
    pluralize_list(rest, [pluralize(word) | acc])
  end

  @doc """
  Returns an English rendering of the number.

  ## Examples

    iex> English.cardinal(-21)
    "negative twenty-one"

    iex> English.cardinal(1_234_567)
    "one million two hundred thirty-four thousand five hundred sixty-seven"
  """
  def cardinal(x) when x < 0, do: "negative " <> cardinal(-x)

  def cardinal(x) when x < 20 do
    case x do
      0 -> "zero"
      1 -> "one"
      2 -> "two"
      3 -> "three"
      4 -> "four"
      5 -> "five"
      6 -> "six"
      7 -> "seven"
      8 -> "eight"
      9 -> "nine"
      10 -> "ten"
      11 -> "eleven"
      12 -> "twelve"
      13 -> "thirteen"
      14 -> "fourteen"
      15 -> "fifteen"
      16 -> "sixteen"
      17 -> "seventeen"
      18 -> "eighteen"
      19 -> "nineteen"
    end
  end

  def cardinal(x) when x < 100 do
    a =
      case div(x, 10) do
        2 -> "twenty"
        3 -> "thirty"
        4 -> "forty"
        5 -> "fifty"
        6 -> "sixty"
        7 -> "seventy"
        8 -> "eighty"
        9 -> "ninety"
      end

    b = rem(x, 10)

    if b == 0, do: a, else: a <> "-" <> cardinal(b)
  end

  def cardinal(x) when x < 1000 do
    a = div(x, 100)
    b = rem(x, 100)
    if b == 0, do: cardinal(a) <> " hundred", else: cardinal(a) <> " hundred " <> cardinal(b)
  end

  def cardinal(x) when x < 1_000_000 do
    a = div(x, 1000)
    b = rem(x, 1000)
    if b == 0, do: cardinal(a) <> " thousand", else: cardinal(a) <> " thousand " <> cardinal(b)
  end

  def cardinal(x) when x < 1_000_000_000 do
    a = div(x, 1_000_000)
    b = rem(x, 1_000_000)
    if b == 0, do: cardinal(a) <> " million", else: cardinal(a) <> " million " <> cardinal(b)
  end

  def cardinal(1_000_000_000), do: "one billion"

  def cardinal(x) when x > 1_000_000_000, do: "over a billion"

  def remove_article("the " <> word), do: word
  def remove_article("a " <> word), do: word
  def remove_article("an " <> word), do: word
  def remove_article(word), do: word

  def consolidate(0, word) do
    "no " <> pluralize(remove_article(word))
  end

  def consolidate(1, word), do: word

  def consolidate(count, word) do
    cardinal(count) <> " " <> pluralize(remove_article(word))
  end

  @doc """
  Returns a list of items.

  ## Examples

    iex> English.item_list(["an apple", "an apple", "a banana"])
    "two apples and a banana"

    iex> English.item_list(["a bat", "a bear", "a bottle", "a bear", "a turtle"])
    "a bat, two bears, a bottle, and a turtle"
  """
  def item_list(strings, conjunction \\ "and")

  def item_list([], _), do: ""
  def item_list([string], _), do: string

  def item_list(strings, conjunction) do
    list =
      strings
      |> Enum.reduce(%{}, fn string, acc ->
        Map.put(acc, string, Map.get(acc, string, 0) + 1)
      end)
      |> Map.to_list()
      |> Enum.sort_by(fn {word, _} -> remove_article(word) end)
      |> Enum.map(fn {word, count} -> consolidate(count, word) end)
      |> join_list(conjunction)
  end

  def join_list([a, b], conjunction), do: to_string([a, " ", conjunction, " ", b])

  def join_list(list, conjunction) do
    list
    |> Enum.intersperse(", ")
    |> List.insert_at(Enum.count(list) * 2 - 2, [conjunction, " "])
    |> to_string
  end
end
