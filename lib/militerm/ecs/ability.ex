defmodule Militerm.ECS.Ability do
  @doc false
  defmacro __using__(_opts) do
    quote do
      import Militerm.ECS.Ability
    end
  end

  @doc """
  Defines an event handler for the given `event`.

  Takes the following args:
    - as: the role
    - for: the entity playing the role
    - args: the map of slots from the command parse
  """
  defmacro defevent(event, opts), do: Militerm.ECS.Ability.define_event_handler(event, opts)

  defmacro defevent(event, foo, bar, opts) do
    Militerm.ECS.Ability.define_event_handler(event, [{:as, foo} | opts] ++ bar)
  end

  defmacro defevent(event, foo, bar) do
    Militerm.ECS.Ability.define_event_handler(event, foo ++ bar)
  end

  @doc """
  Defines an ability handler for the given `ability` and `role`.

  Takes the following args:
    - as: the role for the ability
    - for: the entity with the ability
  """
  defmacro defability(ability, opts),
    do: Militerm.ECS.Ability.define_ability_responder(ability, opts)

  defmacro defability(ability, foo, bar, opts) do
    Militerm.ECS.Ability.define_ability_responder(ability, [{:as, foo} | opts] ++ bar)
  end

  defmacro defability(ability, foo, bar) do
    Militerm.ECS.Ability.define_ability_responder(ability, foo ++ bar)
  end

  @doc false
  def define_ability_responder(ability, opts) do
    body = Keyword.fetch!(opts, :do)
    role = Keyword.fetch!(opts, :as)

    case Keyword.get(opts, :for) do
      nil ->
        quote do
          def handle_ability(_, unquote(ability), unquote(role)), do: unquote(body)
        end

      entity_id ->
        quote do
          def handle_ability(unquote(entity_id), unquote(ability), unquote(role)),
            do: unquote(body)
        end
    end
  end

  @doc false
  def define_event_handler(event, opts) do
    body = Keyword.fetch!(opts, :do)
    role = Keyword.fetch!(opts, :as)

    case {Keyword.get(opts, :for), Keyword.get(opts, :args)} do
      {nil, nil} ->
        quote do
          def handle_event(_, unquote(event), unquote(role), _), do: unquote(body)
        end

      {entity_id, nil} ->
        quote do
          def handle_event(unquote(entity_id), unquote(event), unquote(role), _),
            do: unquote(body)
        end

      {nil, args} ->
        quote do
          def handle_event(_, unquote(event), unquote(role), unquote(args)), do: unquote(body)
        end

      {entity_id, args} ->
        quote do
          def handle_event(unquote(entity_id), unquote(event), unquote(role), unquote(args)),
            do: unquote(body)
        end
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote do
      def handle_event(_, _, _, _), do: nil
      def handle_ability(_, _, _), do: nil
    end
  end
end
