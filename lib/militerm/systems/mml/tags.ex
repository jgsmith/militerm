defmodule Militerm.Systems.MML.Tags do
  defmacro __using__(opts) do
    device = Keyword.fetch!(opts, :device)

    Module.put_attribute(__CALLER__.module, :device, device)

    quote do
      import Militerm.Systems.MML.Tags

      @tags []

      def render_children(children, bindings, pov, device \\ @device) do
        Militerm.Systems.MML.render({children, bindings}, pov, device)
      end

      @before_compile Militerm.Systems.MML.Tags
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def initialize() do
        Militerm.Services.MML.register_tags(__MODULE__, @device, @tags)
      end
    end
  end

  defmacro deftag(name, opts),
    do: Militerm.Systems.MML.Tags.define_tag(__CALLER__.module, name, opts)

  defmacro deftag(name, foo, bar, opts),
    do: Militerm.Systems.MML.Tags.define_tag(__CALLER__.module, name, [{:as, foo} | opts] ++ bar)

  defmacro deftag(name, foo, bar),
    do: Militerm.Systems.MML.Tags.define_tag(__CALLER__.module, name, foo ++ bar)

  def define_tag(module, {name, loc, args} = header, opts) do
    tag_name = Keyword.get(opts, :as, name |> to_string |> String.replace(~r/_/, "-"))
    function_name = String.to_atom("tag_" <> to_string(name))
    body = Keyword.fetch!(opts, :do)

    device_arg =
      case Module.get_attribute(module, :device) do
        :any ->
          Keyword.get(opts, :for, {:_, loc, nil})

        nil ->
          Keyword.get(opts, :for, {:_, loc, nil})

        device ->
          Keyword.get(opts, :for, device)
      end

    quote do
      def unquote({function_name, loc, args ++ [device_arg]}), do: unquote(body)

      @tags [
        {unquote(tag_name), unquote(function_name)} | @tags
      ]
    end
  end
end
