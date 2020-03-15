defmodule Militerm.Services.MML do
  @moduledoc """
  Manages the rendering handlers for MML tags for different device contexts.
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
  Registers a set of tag handlers for a given device context.


  ## Examples

    Given functions in the `Example.Telnet.Description` module with the
    signatures `room(attributes, children, bindings, device)` and
    `env(attributes, children, bindings, device, sense)`:

    iex> MML.register_tags(Example.Telnet.Description, :telnet, [:room, {"env:sight", {:env, :sight}}])
    :ok
  """
  def register_tags(module, device, tag_map) do
    GenServer.call(__MODULE__, {:register_tags, module, device, tag_map})
  end

  def tag_handler(tag, device) do
    case :ets.lookup(__MODULE__, {tag, device}) do
      [{_, mfa}] ->
        {:ok, mfa}

      _ ->
        case :ets.lookup(__MODULE__, {tag, :any}) do
          [{_, mfa}] -> {:ok, mfa}
          _ -> :error
        end
    end
  end

  def render({parse, bindings}, device) do
    parse
    |> Enum.map(fn item -> render_item(item, bindings, device) end)
  end

  def render_item(string, _, _) when is_binary(string), do: string

  def render_item({:tag, attributes, nodes}, bindings, device) do
    with {:ok, name} <- Keyword.fetch(attributes, :name),
         {:ok, {module, function, args}} <- tag_handler(name, device) do
      apply(module, function, [attributes, nodes, bindings, device] ++ args)
    else
      _ ->
        render({nodes, bindings}, device)
    end
  end

  @impl true
  def init(_) do
    :ets.new(__MODULE__, [:named_table])
    {:ok, nil}
  end

  def handle_call({:register_tags, module, device, tag_map}, _from, state) do
    {:reply, insert_tag_handlers(module, device, tag_map), state}
  end

  def insert_tag_handlers(_, _, []), do: :ok

  def insert_tag_handlers(module, device, map) when is_map(map) do
    insert_tag_handlers(module, device, Map.to_list(map))
  end

  def insert_tag_handlers(module, device, [{tag, {fctn, args}} | rest]) do
    :ets.insert(__MODULE__, {{to_string(tag), device}, {module, fctn, to_list(args)}})
    insert_tag_handlers(module, device, rest)
  end

  def insert_tag_handlers(module, device, [{tag, fctn} | rest]) do
    :ets.insert(__MODULE__, {{to_string(tag), device}, {module, fctn, []}})
    insert_tag_handlers(module, device, rest)
  end

  def insert_tag_handlers(module, device, [tag | rest]) when is_atom(tag) do
    :ets.insert(__MODULE__, {{to_string(tag), device}, {module, tag, []}})
    insert_tag_handlers(module, device, rest)
  end

  def insert_tag_handlers(module, device, [tag | rest]) when is_binary(tag) do
    :ets.insert(__MODULE__, {{tag, device}, {module, String.to_existing_atom(tag), []}})
    insert_tag_handlers(module, device, rest)
  end

  def to_list(list) when is_list(list), do: list
  def to_list(not_list), do: [not_list]
end
