defmodule Militerm.Parsers.MML do
  @moduledoc """
  Parses MML into a data structure that can be used to output dynamic content.

  Generally, this is used in item descriptions or other lightly dynamic content.

  See Militerm.If.Builders.MML for information on building up the data structures needed
  to output MML.

    ```
    living_description = Parsers.MML("<this> is <this.position> here")
    non_living_description = Parsers.MML("<this> is <this.position> here")

    inventory = Services.Location.inventory_visible_to(location, actor)
    tag("Room", [], [
      tag("RoomDescription", [], [
        Parsers.MML.parse(Component.Description.get_description(location)),
      ]),
      tag("Inventory", [type: "Living"], [
        inventory
        |> Enum.filter(&Component.Living.living?/1)
        |> Enum.reject(fn id -> id == actor end)
        |> Enum.map(fn id ->
          apply_mml(living_description, %{this: id})
        end)
      ]),
      tag("Inventory", [type: "Books"], [
        inventory
        |> Enum.filter(&Component.Books.book?/1)
        |> Enum.map(fn id ->
          apply_mml(non_living_description, %{this: id})
        end)
      ]),
      ...
      tag("Exits", [], [ ... ])
    ], %{this: location})
    ```
  """

  alias Militerm.Util.Scanner

  def parse!(string) when is_binary(string) do
    case parse(string) do
      {:ok, p} ->
        p

      {:error, reason} ->
        raise reason
    end
  end

  @doc """
  ## Examples

    iex> MML.parse("This is a string")
    {:ok, ["This is a string"]}

    iex> MML.parse("<actor> <hit> <direct> with <indirect>.")
    {:ok, [{:slot, "actor"}, " ", {:verb, "hit"}, " ", {:slot, "direct"}, " with ", {:slot, "indirect"}, "."]}
  """
  def parse(string) when is_binary(string) do
    case :mml_lexer.string(String.to_charlist(string)) do
      {:ok, tokens, _} ->
        case :mml_parser.parse(tokens) do
          {:ok, ast} ->
            {:ok, pre_process(ast)}

          {:error, {_, _, error}} ->
            raise "Unable to parse '#{string}': #{to_string(error)}"
        end

      {:error, {_, _, reason}} ->
        {:error, reason}
    end
  end

  def parse_script("{{" <> string) do
    scanner = Scanner.new(string)

    case Militerm.Parsers.Script.parse_expression(scanner, ~r/}}/) do
      {:ok, parse} ->
        Scanner.terminate(scanner)
        {:script, Militerm.Compilers.Script.compile(parse)}

      error ->
        Scanner.terminate(scanner)
        error
    end
  end

  defp pre_process(ast) do
    ast
    |> Enum.map(&process_node/1)
    |> collapse_strings()
  end

  defp process_node({:string, s}), do: {:string, to_string(s)}

  defp process_node({:slot, {a, b}}) do
    a = to_string(a)

    capitalized = String.downcase(a) != a
    a = String.downcase(a)

    if a in ~w[this actor direct indirect instrumental here hence whence] do
      type = if capitalized, do: :Slot, else: :slot
      {type, a, to_string(b)}
    else
      type = if capitalized, do: :Verb, else: :verb
      {type, a, to_string(b)}
    end
  end

  defp process_node({:verb, {a, b}}) do
    {:verb, to_string(a), to_string(b)}
  end

  defp process_node({:slot, a}) do
    a = to_string(a)
    capitalized = String.downcase(a) != a
    a = String.downcase(a)

    if a in ~w[this actor direct indirect instrumental here hence whence] do
      type = if capitalized, do: :Slot, else: :slot

      {type, a}
    else
      type = if capitalized, do: :Verb, else: :verb
      {type, a}
    end
  end

  defp process_node({:tag, attributes, nodes}) do
    attributes =
      Enum.map(attributes, fn {key, value} ->
        {key, process_attribute(key, value)}
      end)

    {:tag, attributes, pre_process(nodes)}
  end

  defp process_node({:resource, a, b}) do
    {:slot, String.to_atom(to_string(a)), to_string(b)}
  end

  defp process_node({:value, a}) do
    {:value, to_string(a)}
  end

  defp process_node(node), do: node

  defp process_attribute(:name, value) do
    value
    |> Enum.map(fn {:string, value} ->
      to_string(value)
    end)
    |> Enum.join()
  end

  defp process_attribute(:attributes, attributes) do
    Enum.map(attributes, fn attribute ->
      process_attribute(:attribute, attribute)
    end)
  end

  defp process_attribute(:attribute, {name, values}) do
    values = Enum.map(values, &process_node/1)
    {to_string(name), collapse_strings(values)}
  end

  def collapse_strings(ast, acc \\ [])
  def collapse_strings([], acc), do: Enum.reverse(acc)

  def collapse_strings([{:string, s} | rest], [b | acc_rest]) when is_binary(b) do
    collapse_strings(rest, [b <> s | acc_rest])
  end

  def collapse_strings([{:string, s} | rest], acc) do
    collapse_strings(rest, [s | acc])
  end

  def collapse_strings([head | rest], acc) do
    collapse_strings(rest, [head | acc])
  end
end
