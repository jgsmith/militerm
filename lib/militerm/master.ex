defmodule Militerm.Master do
  @moduledoc ~S"""
  The Master module provides a central place to define the parts of the game engine.
  This includes the pipeline for processing commands, the different services used, and any
  components.
  """

  defmacro __using__(opts) do
    prior = Keyword.get(opts, :based_on)

    if prior do
      quote do
        import Militerm.Master

        @components unquote(prior).components
        @systems unquote(prior).systems
        @services unquote(prior).services
        @tags unquote(prior).tags

        @before_compile Militerm.Master
      end
    else
      quote do
        import Militerm.Master

        @components [{:entity, Militerm.Components.Entity}]
        @systems []
        @services []
        @tags []

        @before_compile Militerm.Master
      end
    end
  end

  defmacro __before_compile__(env) do
    quote do
      def services, do: @services
      def systems, do: @systems
      def components, do: Map.new(@components)
      def tags, do: @tags
    end
  end

  defmacro component(name, module, opts \\ []) do
    quote do
      @components [{unquote(name), unquote(module)} | @components]
    end
  end

  defmacro system(module, opts \\ []) do
    quote do
      @systems [unquote(module) | @systems]
    end
  end

  defmacro service(module, opts \\ []) do
    quote do
      @services [unquote(module) | @services]
    end
  end

  defmacro tags(module, opts \\ []) do
    quote do
      @tags [unquote(module) | @tags]
    end
  end
end
