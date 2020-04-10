defmodule Militerm.Services.Verbs do
  @moduledoc """
  The verb service tracks syntaxes for verbs.
  """

  use GenServer

  alias Militerm.Config

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def child_spec(opts \\ []) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[{:name, __MODULE__} | opts]]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  ###
  ### Public API
  ###

  def add_verb(scope, first_word, syntax) do
    # figure out bounds - what do we call for that?
    # can also move the thing since a _thing_ can only appear once in this data
    GenServer.call(__MODULE__, {:add, scope, first_word, syntax})
  end

  def reload_file(file), do: GenServer.call(__MODULE__, {:reload, file})

  def get_syntaxes(scope, word) do
    # removes the thing from the global map registry
    GenServer.call(__MODULE__, {:get_syntaxes, scope, word})
  end

  ###
  ### Callbacks
  ###

  @impl true
  def init(_) do
    store = %{}
    # init store by reading in verbs from filesystem - asyn from this, of course
    Process.send_after(self(), :load_verbs, 0)
    {:ok, store}
  end

  @impl true
  def handle_call({:add, scope, first_word, syntax}, _from, store) do
    new_store = do_add(store, scope, first_word, syntax)
    {:reply, :ok, new_store}
  end

  @impl true
  def handle_call({:get_syntaxes, scope, word}, _from, store) do
    {:reply, do_get_syntaxes(store, scope, word), store}
  end

  @impl true
  def handle_call({:reload, file}, _from, store) do
    {:reply, :ok, reload_file(file, store)}
  end

  def handle_info(:load_verbs, store) do
    {:noreply, load_verbs(Config.game_dir() <> "/verbs", store)}
  end

  ###
  ### Private implementation
  ###

  def do_add(store, scope, first_word, syntax) do
    # %{pattern: [first_word | _]} = syntax
    word_syntaxes = Map.get(store, first_word, [])
    Map.put(store, first_word, [{scope, syntax} | word_syntaxes])
  end

  def do_get_syntaxes(store, scope, word) do
    store
    |> Map.get(word, [])
    |> Enum.filter(fn
      {^scope, _} -> true
      _ -> false
    end)
    |> Enum.map(fn {scope, info} -> info end)
  end

  def reload_file(file, store) do
    case load_and_parse(file) do
      %{"syntaxes" => syntaxes, "verbs" => words} = parse ->
        [_, scope | _] =
          file
          |> Path.split()
          |> Enum.reverse()

        store =
          store
          |> Enum.map(fn {word, list} ->
            {word,
             Enum.reject(list, fn
               {^scope, %{"source" => ^file}} -> true
               _ -> false
             end)}
          end)
          |> Enum.into(%{})

        Enum.reduce(syntaxes, store, fn syntax, syn_store ->
          syntax = Map.put(syntax, :source, file)

          Enum.reduce(words, syn_store, fn word, word_store ->
            case String.split(word, " ", trim: true) do
              [word] ->
                do_add(word_store, scope, word, syntax)

              [word | rest] ->
                rest_pattern =
                  rest
                  |> Enum.map(&{:word_list, [&1], nil})

                aug_syntax = %{
                  syntax
                  | pattern: rest_pattern ++ syntax.pattern,
                    short: Enum.join(rest, " ") <> " " <> syntax.short,
                    weight: Enum.count(rest) * 10 + syntax.weight
                }

                do_add(word_store, scope, word, aug_syntax)
            end
          end)
        end)

      _ ->
        store
    end
  end

  def load_verbs(path, store) do
    # path / scope / verb.md
    paths = Path.wildcard(path <> "/*/*.md")

    Enum.reduce(paths, store, fn path, store ->
      [_, scope | _] =
        path
        |> Path.split()
        |> Enum.reverse()

      scope = String.to_atom(scope)

      case load_and_parse(path) do
        %{"syntaxes" => syntaxes, "verbs" => words} = parse ->
          Enum.reduce(syntaxes, store, fn syntax, syn_store ->
            syntax = Map.put(syntax, :source, path)

            Enum.reduce(words, syn_store, fn word, word_store ->
              case String.split(word, " ", trim: true) do
                [word] ->
                  do_add(word_store, scope, word, syntax)

                [word | rest] ->
                  rest_pattern =
                    rest
                    |> Enum.map(&{:word_list, [&1], nil})

                  aug_syntax = %{
                    syntax
                    | pattern: rest_pattern ++ syntax.pattern,
                      short: Enum.join(rest, " ") <> " " <> syntax.short,
                      weight: Enum.count(rest) * 10 + syntax.weight
                  }

                  do_add(word_store, scope, word, aug_syntax)
              end
            end)
          end)

        otherwise ->
          store
      end
    end)
  end

  defp load_and_parse(path) do
    path
    |> load_content
    |> parse(path)
    |> compile()
  end

  defp load_content(path), do: File.read!(path)

  defp parse({:error, _} = error, _), do: error

  defp parse(content, name) do
    case Militerm.Parsers.Script.parse(:verb, content) do
      %{errors: [_ | _] = errors} ->
        raise "Errors loading #{name}: #{Enum.join("; ", errors)}"

      otherwise ->
        otherwise
    end
  end

  defp compile({:error, _} = error), do: error

  defp compile(parse) do
    parse
    |> parse_syntaxes
  end

  defp parse_syntaxes(%{"syntaxes" => syntaxes, "actions" => actions} = parse) do
    compiled =
      syntaxes
      |> Enum.map(fn syntax ->
        syntax
        |> Militerm.Parsers.VerbSyntax.parse()
        |> Map.put(:actions, actions)
      end)

    %{parse | "syntaxes" => compiled}
  end
end
