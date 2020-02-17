defmodule Militerm.Services.GlobalMap do
  @moduledoc """
  The global map service tracks where different things are on the global stage. That is, each top-level
  terrain, path, or scene that is part of the global universe.

  Each thing is placed at a coordinate in a world. Events do not propagate between worlds, but they
  can propagate between things in the same world.

  The global map is stored in a database table:
  - entity_id
  - world
  - center coordinates
  - extent
  """

  use GenServer

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

  @doc """
  ## Example
    iex> GlobalMap.place("123", "default", {1,2,3}, {10,10,10})
    :ok
  """
  def place(thing, world, coords, extent) do
    # figure out bounds - what do we call for that?
    # can also move the thing since a _thing_ can only appear once in this data
    GenServer.call(__MODULE__, {:place, thing, world, coords, extent})
  end

  @doc """
    iex> GlobalMap.place("123", "default", {1,2,3}, {10,10,10})
    :ok
    iex> GlobalMap.find("default", {2,4,6})
    "123"
    iex> GlobalMap.find("foo", {2,4,6})
    nil
    iex> GlobalMap.find("default", {100,200,300})
    nil
  """
  def find(world, coords) do
    # given the world and coords, find the thing that is most likely to map to those coordinates
    do_find(world, coords)
  end

  @doc """
    iex> GlobalMap.place("123", "default", {1,2,3}, {10,10,10})
    :ok
    iex> GlobalMap.find("default", {2,4,6})
    "123"
    iex> GlobalMap.remove("123")
    :ok
    iex> GlobalMap.find("default", {2,4,6})
    nil
  """
  def remove(thing) do
    # removes the thing from the global map registry
    GenServer.call(__MODULE__, {:remove, thing})
  end

  ###
  ### Callbacks
  ###

  @impl true
  def init(_) do
    table = :ets.new(__MODULE__, [:named_table, read_concurrency: true])
    {:ok, table}
  end

  @impl true
  def handle_call({:place, thing, world, coords, extent}, _from, state) do
    do_place(thing, world, coords, extent)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:remove, thing}, _from, state) do
    do_remove(thing)
    {:reply, :ok, state}
  end

  ###
  ### Private implementation
  ###

  def do_place(thing, world, coords, extent) do
    :ets.insert(__MODULE__, {thing, world, {coords, extent}})
  end

  def do_find(world, coords) do
    __MODULE__
    |> :ets.match({:"$1", world, :"$3"})
    |> Enum.find(fn [_, loc] -> in_bounds(coords, loc) end)
    |> extract_thing
  end

  def do_remove(thing) do
    :ets.delete(__MODULE__, thing)
  end

  defp in_bounds({x, y, z}, {{mx, my, mz}, {x_size, y_size, z_size}}) do
    abs(x - mx) < x_size && abs(y - my) < y_size && abs(z - mz) < z_size
  end

  defp extract_thing(nil), do: nil
  defp extract_thing({thing, _}), do: thing
  defp extract_thing([thing | _]), do: thing
end
