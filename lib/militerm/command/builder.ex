defmodule Militerm.Command.Builder do
  @moduledoc """
  Convenience methods for defining command pipelines.
  """

  @type plug :: module | atom

  @doc false
  defmacro __using__(opts) do
    quote do
      @behaviour Militerm.Command.Plug
      @militerm_command_builder_opts unquote(opts)

      def init(opts) do
        opts
      end

      def call(conn, opts) do
        plug_builder_call(conn, opts)
      end

      defoverridable init: 1, call: 2

      import Militerm.Command.Record
      import Militerm.Command.Builder, only: [plug: 1, plug: 2, builder_opts: 0]

      Module.register_attribute(__MODULE__, :plugs, accumulate: true)
      @before_compile Militerm.Command.Builder
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    plugs = Module.get_attribute(env.module, :plugs)

    plugs =
      if builder_ref = get_plug_builder_ref(env.module) do
        traverse(plugs, builder_ref)
      else
        plugs
      end

    builder_opts = Module.get_attribute(env.module, :plug_builder_opts)
    {record, body} = Militerm.Command.Builder.compile(env, plugs, builder_opts)

    quote do
      defp plug_builder_call(unquote(record), opts), do: unquote(body)
    end
  end

  defp traverse(tuple, ref) when is_tuple(tuple) do
    tuple |> Tuple.to_list() |> traverse(ref) |> List.to_tuple()
  end

  defp traverse(map, ref) when is_map(map) do
    map |> Map.to_list() |> traverse(ref) |> Map.new()
  end

  defp traverse(list, ref) when is_list(list) do
    Enum.map(list, &traverse(&1, ref))
  end

  defp traverse(ref, ref) do
    {:unquote, [], [quote(do: opts)]}
  end

  defp traverse(term, _ref) do
    term
  end

  defmacro plug(plug, opts \\ []) do
    plug = Macro.expand(plug, %{__CALLER__ | function: {:init, 1}})

    quote do
      @plugs {unquote(plug), unquote(opts), true}
    end
  end

  defmacro builder_opts() do
    quote do
      Plug.Builder.__builder_opts__(__MODULE__)
    end
  end

  @doc false
  def __builder_opts__(module) do
    get_plug_builder_ref(module) || generate_plug_builder_ref(module)
  end

  defp get_plug_builder_ref(module) do
    Module.get_attribute(module, :plug_builder_ref)
  end

  defp generate_plug_builder_ref(module) do
    ref = make_ref()
    Module.put_attribute(module, :plug_builder_ref, ref)
    ref
  end
end
