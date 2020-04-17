defmodule Militerm.Util.Scanner do
  @moduledoc """
  Scan a string while keeping state. This is most useful in complex parsers where
  threading this state through all the calls might hide the logic.

  The scanner does not support backtracking.
  """
  use GenServer

  def start_link(arg) do
    GenServer.start_link(__MODULE__, [arg])
  end

  @doc """
  ## Examples

    iex> Scanner.new({:error, "error"})
    {:error, "error"}

    iex> nil == Scanner.new({:ok, "string"})
    false
  """
  def new({:error, _} = error), do: error
  def new({:ok, string}), do: new(string)

  def new(string) do
    case start_link(string) do
      {:ok, pid} -> pid
      _ -> nil
    end
  end

  def stop(pid), do: GenServer.cast(pid, :stop)
  def rest(pid), do: GenServer.call(pid, :rest)
  def terminate(pid), do: GenServer.call(pid, :terminate)
  def matches(pid), do: GenServer.call(pid, :matches)
  def pos(pid), do: GenServer.call(pid, :pos)

  @doc """
  Checks if the beginning of the string matches the regex.
  Any matches may be retrieved by `matches`.

  ## Examples
      iex> scanner = Scanner.new("The quick brown fox")
      ...> Scanner.scan(scanner, ~r/[tT]he\\b/)
      true

      iex> scanner = Scanner.new("The quick brown fox")
      ...> Scanner.scan(scanner, ~r/the\\b/)
      false
  """
  def scan(pid, regex), do: GenServer.call(pid, {:scan, regex})

  def expect(pid, regex), do: GenServer.call(pid, {:expect, regex})

  @doc """
  Scans through the string until the regex matches. Returns the consumed string or `nil`.

  ## Examples
      iex> scanner = Scanner.new("something starts as 123")
      ...> Scanner.scan_until(scanner, ~r/\\bstarts\\b/)
      "something "
  """
  def scan_until(pid, regex, discard_match \\ true),
    do: GenServer.call(pid, {:scan_until, regex, discard_match})

  @doc """
  Skips over anything matching the regex. Returns `true` if a match is made.
  This is almost the same as `scan`, but the matches are not affected.

  ## Examples
      iex> scanner = Scanner.new("something starts as 123")
      iex> Scanner.skip(scanner, ~r/[a-z]+\\s+[a-z]+/)
      true
      iex> Scanner.rest(scanner)
      " as 123"
      iex> Scanner.pos(scanner)
      16
      iex> Scanner.matches(scanner)
      []
  """
  def skip(pid, regex), do: GenServer.call(pid, {:skip, regex})

  @doc """
  ## Examples
      iex> scanner = Scanner.new("")
      iex> Scanner.eos?(scanner)
      true

      iex> scanner = Scanner.new("Boo!")
      iex> Scanner.eos?(scanner)
      false
  """
  def eos?(pid), do: GenServer.call(pid, :eos?)
  def error(pid, message), do: GenServer.call(pid, {:error, message})
  def error(pid, message, regex), do: GenServer.call(pid, {:error, message, regex})

  @doc """
  Returns true if the scanner matches the regular expression. Does not advance the scanner.
  ## Examples
      iex> scanner = Scanner.new("Foo bar")
      iex> Scanner.match?(scanner, ~r/oo/)
      false
      iex> Scanner.skip(scanner, ~r/[A-Z]+/)
      true
      iex> Scanner.match?(scanner, ~r/oo/)
      true
  """
  def match?(pid, regex), do: GenServer.call(pid, {:match?, regex})

  ###
  ### Implementation
  ###

  def init([string]) do
    {:ok, {string, [], find_beginning_of_lines(string), 0}}
    #     {source, matches, beginnings,                 pos}
  end

  def handle_cast(:stop, state) do
    {:stop, :shutdown, state}
  end

  def handle_call(:rest, _from, {string, _, _, _} = state) do
    {:reply, string, state}
  end

  def handle_call(:terminate, _from, {_, _, _, pos}) do
    {:reply, nil, {"", [], [], pos}}
  end

  def handle_call(:matches, _from, {_, matches, _, _} = state) do
    {:reply, matches, state}
  end

  def handle_call(:pos, _from, {_, _, _, pos} = state) do
    {:reply, pos, state}
  end

  def handle_call({:scan, regex}, _from, {string, _, positions, pos} = _state) do
    with {:ok, fixed_regex} <- fix_regex("\\A", regex),
         [first_match | other_matches] <- Regex.run(fixed_regex, string) do
      {:reply, true,
       {
         String.replace_leading(string, first_match, ""),
         [first_match | other_matches],
         positions,
         pos + String.length(first_match)
       }}
    else
      _ ->
        {:reply, false, {string, [], positions, pos}}
    end
  end

  def handle_call({:expect, regex}, _from, {string, kept_matches, positions, pos} = state) do
    with {:ok, fixed_regex} <- fix_regex("\\A", regex),
         [first_match | _] <- Regex.run(fixed_regex, string) do
      {:reply, :ok,
       {
         String.replace_leading(string, first_match, ""),
         kept_matches,
         positions,
         pos + String.length(first_match)
       }}
    else
      _ ->
        {:reply,
         {:error,
          {"Expected \"#{Regex.source(regex)}\"", state_coords(state),
           String.slice(string, 0, 20)}}, state}
    end
  end

  def handle_call({:scan_until, regex, discard_match}, _from, state) do
    case do_scan_until(regex, discard_match, state) do
      {new_state, value} ->
        {:reply, value, new_state}

      _ ->
        {:reply, nil, state}
    end
  end

  def handle_call({:skip, regex}, _from, {string, kept_matches, positions, pos} = state) do
    case fix_regex("\\A", regex) do
      {:ok, fixed_regex} ->
        case Regex.run(fixed_regex, string) do
          ["" | _] ->
            {:reply, false, state}

          [match | _] ->
            {:reply, true,
             {
               String.replace_leading(string, match, ""),
               kept_matches,
               positions,
               pos + String.length(match)
             }}

          _ ->
            {:reply, false, state}
        end

      _ ->
        {:reply, false, state}
    end
  end

  def handle_call(:eos?, _from, {string, _, _, _} = state) do
    {:reply, string == "", state}
  end

  def handle_call({:error, message, nil}, _from, {string, _, _, _} = state) do
    {:reply, {message, state_coords(state), String.slice(string, 0, 20)}, state}
  end

  def handle_call({:error, message, regex}, _from, {string, _, _, _} = state) do
    message_tuple =
      {message, state_coords(state), string |> String.slice(0, 20) |> escape_escapes}

    case do_scan_until(regex, true, state) do
      {new_state, _} ->
        {:reply, message_tuple, new_state}

      _ ->
        {:reply, message_tuple, state}
    end
  end

  def handle_call({:error, message}, _from, {string, _, _, _} = state) do
    {:reply, {message, state_coords(state), String.slice(string, 0, 20)}, state}
  end

  def handle_call({:match?, binary}, _from, {string, _, _, _} = state) when is_binary(binary) do
    {:reply, String.starts_with?(string, binary), state}
  end

  def handle_call({:match?, regex}, _from, {string, _, _, _} = state) do
    case fix_regex("\\A", regex) do
      {:ok, fixed_regex} ->
        case Regex.run(fixed_regex, string) do
          nil -> {:reply, false, state}
          _ -> {:reply, true, state}
        end

      _ ->
        {:reply, false, state}
    end
  end

  defp find_beginning_of_lines(source, list \\ [])

  defp find_beginning_of_lines(source, []),
    do: find_beginning_of_lines(source, [String.length(source)])

  defp find_beginning_of_lines("", list) do
    [total_length | list] = list |> Enum.reverse()
    (list |> Enum.map(&(total_length - &1))) ++ [total_length]
  end

  defp find_beginning_of_lines(<<"\n", rest::binary>>, list) do
    find_beginning_of_lines(rest, [String.length(rest) | list])
  end

  defp find_beginning_of_lines(<<_::bytes-size(1), rest::binary>>, list) do
    find_beginning_of_lines(rest, list)
  end

  defp state_coords({_, _, lines, pos} = _state) do
    line =
      case Enum.find_index(lines, fn candidate -> candidate > pos end) do
        nil -> Enum.count(lines)
        number -> number
      end

    offset = pos - Enum.at(lines, line - 1, 0)
    {line + 1, offset}
  end

  defp escape_escapes(string, acc \\ "")
  defp escape_escapes("", acc), do: acc
  defp escape_escapes(<<"\n", rest::binary>>, acc), do: escape_escapes(rest, acc <> "\\n")
  defp escape_escapes(<<"\t", rest::binary>>, acc), do: escape_escapes(rest, acc <> "\\t")
  defp escape_escapes(<<"\r", rest::binary>>, acc), do: escape_escapes(rest, acc <> "\\r")
  defp escape_escapes(<<"\e", rest::binary>>, acc), do: escape_escapes(rest, acc <> "\\e")
  defp escape_escapes(<<"\\", rest::binary>>, acc), do: escape_escapes(rest, acc <> "\\\\")
  defp escape_escapes(<<x::utf8, rest::binary>>, acc), do: escape_escapes(rest, acc <> <<x>>)

  defp do_scan_until(regex, false, {string, kept_matches, positions, pos} = state) do
    case fix_regex("\\A(.*?)", regex) do
      {:ok, fixed_regex} ->
        case Regex.run(fixed_regex, string) do
          nil ->
            nil

          [full | []] ->
            {state, ""}

          [full | [value | _]] ->
            {
              {
                String.replace_leading(string, value, ""),
                kept_matches,
                positions,
                pos + String.length(value)
              },
              value
            }
        end

      _ ->
        nil
    end
  end

  defp do_scan_until(regex, true, {string, kept_matches, positions, pos} = state) do
    case fix_regex("\\A(.*?)", regex) do
      {:ok, fixed_regex} ->
        case Regex.run(fixed_regex, string) do
          nil ->
            nil

          [full | []] ->
            {
              {
                String.replace_leading(string, full, ""),
                kept_matches,
                positions,
                pos + String.length(full)
              },
              ""
            }

          [full | [value | _]] ->
            {
              {
                String.replace_leading(string, full, ""),
                kept_matches,
                positions,
                pos + String.length(full)
              },
              value
            }
        end

      _ ->
        nil
    end
  end

  defp fix_regex(prefix, regex, suffix \\ "") do
    Regex.compile(prefix <> "(" <> Regex.source(regex) <> ")" <> suffix, "ums")
  end
end
