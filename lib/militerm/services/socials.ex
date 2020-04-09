defmodule Militerm.Services.Socials do
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

  def add_soul(scope, first_word, syntax) do
    # figure out bounds - what do we call for that?
    # can also move the thing since a _thing_ can only appear once in this data
    GenServer.call(__MODULE__, {:add, scope, first_word, syntax})
  end

  def get_syntaxes(_scope, word) do
    # removes the thing from the global map registry
    GenServer.call(__MODULE__, {:get_syntaxes, word})
  end

  ###
  ### Callbacks
  ###

  @impl true
  def init(_) do
    store = %{}
    # init store by reading in verbs from filesystem - asyn from this, of course
    Process.send_after(self(), :load_souls, 0)
    {:ok, store}
  end

  @impl true
  def handle_call({:add, _scope, first_word, syntax}, _from, store) do
    new_store = do_add(store, first_word, syntax)
    {:reply, :ok, new_store}
  end

  @impl true
  def handle_call({:get_syntaxes, word}, _from, store) do
    {:reply, Map.get(store, word, []), store}
  end

  def handle_info(:load_souls, store) do
    {:noreply, load_souls(Config.game_dir() <> "/souls", store)}
  end

  ###
  ### Private implementation
  ###

  def do_add(store, first_word, syntax) do
    # %{pattern: [first_word | _]} = syntax
    word_syntaxes = Map.get(store, first_word, [])
    Map.put(store, first_word, [syntax | word_syntaxes])
  end

  def load_souls(path, store) do
    # path / * / soul.md
    paths = Path.wildcard(path <> "/*/*.yaml")

    Enum.reduce(paths, store, fn path, store ->
      case load_and_parse(path) do
        %{"syntaxes" => syntaxes, "verb" => word} = parse ->
          metadata = Map.drop(parse, ["syntaxes", "verb"])

          Enum.reduce(syntaxes, store, fn syntax, word_store ->
            case String.split(word, " ", trim: true) do
              [word] ->
                do_add(word_store, word, Map.merge(syntax, metadata))

              [word | rest] ->
                rest_pattern =
                  rest
                  |> Enum.map(&{:word_list, [&1], nil})

                aug_syntax =
                  %{
                    syntax
                    | pattern: rest_pattern ++ syntax.pattern,
                      short: Enum.join(rest, " ") <> " " <> syntax.short,
                      weight: Enum.count(rest) * 10 + syntax.weight
                  }
                  |> Map.merge(metadata)

                do_add(word_store, word, aug_syntax)
            end
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

  defp parse_syntaxes(%{"syntaxes" => syntaxes} = parse) do
    metadata = Map.drop(parse, ["syntaxes"])

    compiled =
      syntaxes
      |> Enum.map(fn syntax ->
        syntax
        |> Militerm.Parsers.VerbSyntax.parse()
        |> Map.merge(metadata)
      end)

    %{parse | "syntaxes" => compiled}
  end
end
