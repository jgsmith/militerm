defmodule Militerm.ECS.EctoComponent do
  @moduledoc """
  The component service tracks component data for entities with a backing store in an Ecto repo.

  For eaxmple, if yu have a component named MyGame.Components.Health, you
  can start a copy of this with:

      Militerm.ECS.EctoComponent.start_link(name: MyGame.Components.Health)

  Then, later, you can set or get the data for the component:

      Militerm.ECS.EctoComponent.set(MyGame.Components.Health, entity_id, %{hp: 100, max_hp: 100})
      %{hp: hp, max_hp: hp} = Militerm.ECS.Component.get(MyGame.Components.Health, entity_id)

  Each component defines its persistance mechanisms through the `store/2`, `update/3`, `fetch/1`,
  `delete/1`, and `clear/0` functions. These are required and do not have default definitions.

  By default, the component uses the Ecto repo set in the militerm configuration.
  """

  import Ecto.Query

  @callback process_record(term) :: term
  @callback primary_keys(term) :: Keyword.t() | Map.t()
  @callback write_data(term, term) :: term
  @callback read_data(map) :: term

  defmacro __using__(opts) do
    default = Keyword.get(opts, :default)

    repo = Keyword.get_lazy(opts, :repo, &Militerm.Config.repo/0)
    schema = Keyword.fetch!(opts, :schema)

    quote do
      use Militerm.ECS.Component, unquote(opts)

      @behaviour Militerm.ECS.EctoComponent

      @schema unquote(schema)
      @repo unquote(repo)

      @impl true
      def store(entity_id, data) do
        Militerm.ECS.EctoComponent.ecto_store(
          primary_keys(entity_id),
          data,
          @repo,
          @schema,
          __MODULE__
        )
      end

      @impl true
      def update(entity_id, nil, new_data) do
        Militerm.ECS.EctoComponent.ecto_store(
          primary_keys(entity_id),
          new_data,
          @repo,
          @schema,
          __MODULE__
        )
      end

      def update(entity_id, old_data, new_data) do
        Militerm.ECS.EctoComponent.ecto_update(
          primary_keys(entity_id),
          old_data,
          new_data,
          @repo,
          @schema,
          __MODULE__
        )
      end

      @impl true
      def fetch(entity_id) do
        entity_id
        |> primary_keys()
        |> Militerm.ECS.EctoComponent.ecto_fetch(@repo, @schema)
        |> __MODULE__.read_data()
        |> __MODULE__.process_record()
      end

      @impl true
      def delete(entity_id),
        do: Militerm.ECS.EctoComponent.ecto_delete(primary_keys(entity_id), @repo, @schema)

      @impl true
      def clear(), do: Militerm.ECS.EctoComponent.ecto_clear(@repo, @schema)

      def process_record(nil), do: @default
      def process_record(record), do: record

      def primary_keys(entity_id), do: [entity_id: entity_id]

      def write_data(map, nil), do: map
      def write_data(map, data), do: Map.put(map, :data, data)

      def read_data(nil), do: nil
      def read_data(map), do: Map.get(map, :data)

      defoverridable process_record: 1, primary_keys: 1, write_data: 2, read_data: 1
    end
  end

  def ecto_store(key, data, repo, schema, module) do
    case ecto_fetch(key, repo, schema) do
      nil ->
        schema
        |> struct
        |> schema.changeset(
          key
          |> Enum.reduce(%{}, fn {k, v}, acc -> Map.put(acc, k, v) end)
          |> module.write_data(data)
          |> atoms_to_strings
        )
        |> repo.insert!()

      record ->
        ecto_update(key, record, data, repo, schema, module)
    end
  end

  def ecto_update(key, _old_data, new_data, repo, schema, module) do
    updates =
      %{}
      |> module.write_data(new_data)
      |> strings_to_atoms()
      |> Map.to_list()

    key
    |> Enum.reduce(schema, fn {k, v}, q ->
      where(q, [i], field(i, ^k) == ^v)
    end)
    |> repo.update_all(set: updates)
  end

  def ecto_fetch(key, repo, schema) do
    key
    |> Enum.reduce(schema, fn {k, v}, q ->
      where(q, [i], field(i, ^k) == ^v)
    end)
    |> repo.one
  end

  def ecto_delete(key, repo, schema) do
    result =
      key
      |> Enum.reduce(schema, fn {k, v}, q ->
        where(q, [i], field(i, ^k) == ^v)
      end)
      |> repo.delete_all

    case result do
      {:ok, _} -> :ok
      _ -> :error
    end
  end

  def ecto_clear(repo, schema) do
    repo.delete_all(schema)
  end

  def atoms_to_strings(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> {atoms_to_strings(k), atoms_to_strings(v)} end)
    |> Enum.into(%{})
  end

  def atoms_to_strings(list) when is_list(list) do
    Enum.map(list, fn v -> atoms_to_strings(v) end)
  end

  def atoms_to_strings(atom) when is_atom(atom), do: to_string(atom)

  def atoms_to_strings(otherwise), do: otherwise

  def strings_to_atoms(atom) when is_atom(atom), do: atom

  def strings_to_atoms(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> {strings_to_atoms(k), v} end)
    |> Enum.into(%{})
  end

  def strings_to_atoms(string) when is_binary(string), do: String.to_atom(string)

  def strings_to_atoms(otherwise), do: otherwise
end
