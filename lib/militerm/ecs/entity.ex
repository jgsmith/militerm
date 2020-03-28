defmodule Militerm.ECS.Entity do
  @moduledoc """
  An entity is composed of components. Each entity has a process that coordinates event
  messages with the components if the entity responds to events.

  The entity module holds any event handlers that are specific to the entity type. Entity
  modules can delegate some events to other modules as-needed.

  Generally, if a process isn't running for the entity and the entity receives events, the
  system will start a process for the entity. So the system doesn't have to spin up processes
  for everything at start up or when an item is created. It's done automatically later when the
  first event for the entity is queued.

  Each entity has an identifier as well as the module defining the entity's behavior.

  Events are used to respond to commands and environmental activities. They are not the same
  as an entities heartbeat or component-based processes and systems.
  """

  @callback preprocess(term) :: term
  @callback handle_event(term, String.t(), String.t(), map) :: term
  @callback can?(term, String.t(), String.t(), map) :: true | false | nil
  @callback is?(term, String.t(), map) :: true | false | nil
  @callback calculates?(term, String.t()) :: true | false | nil
  @callback validates?(term, String.t()) :: true | false | nil
  @callback calculate(term, String.t(), map) :: term
  @callback validate(term, String.t(), term, map) :: term

  defmacro __using__(opts) do
    based_on = Keyword.get(opts, :based_on)
    abilities = Keyword.get(opts, :abilities, [])
    components = Keyword.get(opts, :components, [])

    quote do
      import Militerm.ECS.Entity
      import Militerm.ECS.Ability

      @behaviour Militerm.ECS.Entity

      @based_on unquote(based_on)
      @components unquote(components)
      @abilities unquote(abilities)

      def defaults(), do: @components

      def create(entity_id, archetype, component_data) do
        Militerm.ECS.Entity.create_entity(
          __MODULE__,
          entity_id,
          archetype,
          __MODULE__.preprocess(component_data),
          @components
        )
      end

      def create(entity_id, archetype) when is_binary(archetype) do
        create(entity_id, archetype, [])
      end

      def create(entity_id, component_data) do
        Militerm.ECS.Entity.create_entity(
          __MODULE__,
          entity_id,
          __MODULE__.preprocess(component_data),
          @components
        )
      end

      def delete(entity_id), do: Militerm.ECS.Entity.delete_entity(entity_id)

      def preprocess(component_data), do: component_data

      @defoverridable preprocess: 1
    end
  end

  @doc false
  def create_entity(entity_module, entity_id, archetype \\ nil, component_data, defaults) do
    # we want to make sure the defaults are applied and components are added, but that not all
    # components have ot be listed in the defaults
    archetype_data = get_archetype_data(archetype)

    component_mapping = Militerm.Config.components()

    data =
      defaults
      |> with_string_keys()
      |> merge(with_string_keys(archetype_data))
      |> merge(with_string_keys(component_data))

    for {module_key, module_data} <- data do
      module = Map.get(component_mapping, as_atom(module_key), nil)

      if not is_nil(module), do: module.set(entity_id, module_data)
    end

    # N.B.: We don't start the entity controller until we need to send an event to it.
    Militerm.Components.Entity.register(entity_id, entity_module, archetype)

    entity_id
  end

  def get_archetype_data(nil), do: %{}

  def get_archetype_data(archetype) do
    case Militerm.Services.Archetypes.get(archetype) do
      %{data: data} -> data
      _ -> %{}
    end
  end

  def delete_entity(entity_id) do
    component_mapping = Militerm.Config.components()

    # make sure the entity isn't running
    Militerm.Systems.Entity.shutdown(entity_id)

    for {_, module} <- component_mapping do
      module.remove(entity_id)
    end

    Militerm.Components.Entity.remove(entity_id)
  end

  defp merge(a, b) when is_map(a) and is_map(b) do
    Map.merge(a, b, fn _, sa, sb -> merge(sa, sb) end)
  end

  defp merge(a, b) when is_map(a) and is_list(b) do
    if Keyword.keyword?(b), do: merge(a, Map.new(b)), else: a
  end

  defp merge(a, b) when is_list(a) and is_map(b) do
    if Keyword.keyword?(a), do: merge(Map.new(a), b), else: a
  end

  defp merge(a, b) when is_list(a) and is_list(b) do
    if Keyword.keyword?(a) and Keyword.keyword?(b),
      do: Keyword.merge(a, b),
      else: Enum.uniq(a ++ b)
  end

  defp merge(nil, b), do: b
  defp merge(a, nil), do: a
  defp merge(_, b), do: b

  defp as_atom(atom) when is_atom(atom), do: atom
  defp as_atom(bin) when is_binary(bin), do: String.to_atom(bin)

  defp with_string_keys(nil), do: %{}

  defp with_string_keys([]), do: %{}

  defp with_string_keys(list) when is_list(list) do
    if Keyword.keyword?(list) do
      list
      |> Enum.map(fn {k, v} -> {to_string(k), v} end)
      |> Enum.into(%{})
    else
      list
    end
  end

  defp with_string_keys(map) when is_map(map) do
    map
    |> Enum.map(fn
      {k, v} when is_atom(k) -> {to_string(k), v}
      otherwise -> otherwise
    end)
    |> Enum.into(%{})
  end

  defp with_string_keys(otherwise), do: otherwise
end
