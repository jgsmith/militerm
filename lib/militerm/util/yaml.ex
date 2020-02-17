defmodule Militerm.Util.Yaml do
  @moduledoc """
  A simple YAML writer that lets us get the data from the components and display it for editing.
  """

  @doc """

  ## Examples

    iex> Yaml.write_to_string("string") |> to_string
    "string"

    iex> Yaml.write_to_string(["one", "two", "three"]) |> to_string
    "- one\n- two\n- three"

    iex> Yaml.write_to_string(%{"one" => "foo", "two" => ["three", "four"], "three" => %{1 => 2, 3 => 4}}) |> to_string
    "one: foo\ntwo:\n  - three\n  - four\nthree:\n  1: 2\n  3: 4"
  """
  def write_to_string(data), do: write_to_string(data, 0)

  def write_to_string(%MapSet{} = mapset, level) do
    write_to_string(MapSet.to_list(mapset), level)
  end

  def write_to_string(map, level) when is_map(map) do
    map
    |> Enum.map(fn
      {k, map_or_list} when is_list(map_or_list) or is_map(map_or_list) ->
        [
          String.duplicate("  ", level),
          to_string(k),
          ":\n",
          write_to_string(map_or_list, level + 1)
        ]

      {k, v} ->
        [String.duplicate("  ", level), to_string(k), ": ", write_to_string(v, level), "\n"]
    end)
  end

  def write_to_string(list, level) when is_list(list) do
    list
    |> Enum.map(fn
      item when is_list(item) or is_map(item) ->
        [String.duplicate("  ", level), "-\n", write_to_string(item, level + 1)]

      item ->
        [String.duplicate("  ", level), "- ", write_to_string(item, level), "\n"]
    end)
  end

  def write_to_string(string, level) when is_binary(string) do
    indent = String.duplicate("  ", level + 1)

    cond do
      String.length(string) > 50 ->
        # wrap the string as much as possible and indent by level
        [
          ">"
          | string
            |> wrap(108 - 2 * level)
            |> Enum.map(fn line -> ["\n", indent, line] end)
        ]

      String.contains?(string, ~w(: " ')) ->
        [
          ?",
          string
          |> String.replace("\\", "\\\\")
          |> String.replace("\"", "\\\""),
          ?"
        ]

      string in ~w[on off true false yes no nil null] ->
        [?", string, ?"]

      :else ->
        string
    end
  end

  def write_to_string(true, _), do: "true"
  def write_to_string(false, _), do: "false"
  def write_to_string(nil, _), do: "null"
  def write_to_string(other, _), do: to_string(other)

  def wrap(string, width) do
    string
    |> String.split(" ", trim: true)
    |> Enum.chunk_while(
      [],
      fn
        word, [] ->
          {:cont, [word]}

        word, acc ->
          if IO.iodata_length([word, " " | acc]) > width do
            {:cont, Enum.reverse(acc), [word]}
          else
            {:cont, [word, " " | acc]}
          end
      end,
      fn
        [] -> {:cont, []}
        acc -> {:cont, Enum.reverse(acc), []}
      end
    )
  end
end
