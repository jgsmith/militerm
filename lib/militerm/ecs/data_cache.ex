defmodule Militerm.ECS.DataCache do
  @moduledoc """
  Provides a node-local cache of data.
  """

  @type callback :: {mfa, [term]} | function
  @type path :: String.t() | [String.t()]

  defmacro __using__(opts) do
    quote do
      @behaviour Militerm.ECS.DataCache

      @default unquote(Keyword.get(opts, :default, quote(do: %{})))

      @callback get(term) :: term
      @callback get(term, term) :: term
      @callback fetch(term) :: term
      @callback reset() :: :ok

      def child_spec(opts \\ []) do
        %{
          id: __MODULE__,
          start: {Cachex, :start_link, [__MODULE__, [fallback: &__MODULE__.fetch(&1)]]},
          type: :worker,
          restart: :permanent,
          shutdown: 500
        }
      end

      def get(thing), do: Militerm.ECS.Component.get(__MODULE__, thing, @default)
      def get(thing, default), do: Militerm.ECS.Component.get(__MODULE__, thing, default)
      def reset(), do: Militerm.ECS.Component.reset(__MODULE__)

      defoverridable child_spec: 1, get: 1, get: 2, reset: 0
    end
  end

  ###
  ### Public API
  ###

  @doc """
  ## Example
    iex> Component.Levels.set("123", %{xp: 123, level: 2})
    :ok
    iex> Component.Levels.get("123")
    %{xp: 123, level: 2}
  """
  def get(component, thing, default \\ %{}) do
    case Cachex.get(component, thing) do
      {:ok, nil} ->
        default

      {:ok, value} ->
        value

      {:error, :no_cache} ->
        value = component.fetch(thing)
        Cachex.put(component, thing, value)
        value

      _ ->
        default
    end
  end

  def reset(component) do
    Cachex.reset(component)
    :ok
  end
end
