defmodule Militerm.Services.Script do
  @moduledoc """
  Manages the system function handlers for scripts.
  """

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def child_spec(opts \\ []) do
    %{
      id: {:global, __MODULE__},
      start: {__MODULE__, :start_link, []},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  @doc """
  Registers a set of function handlers for a given service.
  """
  def register_functions(module, fctn_map) do
    GenServer.call(__MODULE__, {:register_functions, module, fctn_map})
  end

  def function_handler(function, arity) do
    case :ets.lookup(__MODULE__, {function, arity}) do
      [{_, mfa}] -> {:ok, mfa}
      _ -> :error
    end
  end

  @impl true
  def init(_) do
    :ets.new(__MODULE__, [:named_table])
    {:ok, nil}
  end

  def handle_call({:register_functions, module, fctn_map}, _from, state) do
    {:reply, insert_function_handlers(module, fctn_map), state}
  end

  def insert_function_handlers(_, []), do: :ok

  def insert_function_handlers(module, map) when is_map(map) do
    insert_function_handlers(module, Map.to_list(map))
  end

  def insert_function_handlers(module, [{{name, arity}, {fctn, args}} | rest]) do
    :ets.insert(__MODULE__, {{to_string(name), arity}, {module, fctn, to_list(args)}})
    insert_function_handlers(module, rest)
  end

  def insert_function_handlers(module, [{name, arity_map} | rest]) when is_map(arity_map) do
    insert_function_handlers(
      module,
      Enum.map(arity_map, fn {arity, fa} -> {{name, arity}, fa} end) ++ rest
    )
  end

  def insert_function_handlers(module, [{name, fctn} | rest]) when is_atom(fctn) do
    :ets.insert(__MODULE__, {{to_string(name), 0}, {module, fctn, []}})
    insert_function_handlers(module, rest)
  end

  def insert_function_handlers(module, [{name, arity} | rest])
      when is_atom(name) and is_integer(arity) and arity >= 0 do
    :ets.insert(__MODULE__, {{to_string(name), arity}, {module, name, [arity]}})
  end

  def to_list(list) when is_list(list), do: list
  def to_list(not_list), do: [not_list]
end
