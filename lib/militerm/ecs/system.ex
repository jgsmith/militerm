defmodule Militerm.ECS.System do
  defmacro __using__(_opts) do
    quote do
      import Militerm.ECS.System

      @script_functions []

      @commands []

      @before_compile Militerm.ECS.System
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def initialize() do
        Militerm.Services.Script.register_functions(__MODULE__, @script_functions)
        Militerm.Services.Commands.register_commands(__MODULE__, @commands)
      end
    end
  end

  defmacro defscript(name, opts),
    do: Militerm.ECS.System.define_script_function(name, opts)

  defmacro defscript(name, foo, bar, opts) do
    Militerm.ECS.System.define_script_function(name, [{:as, foo} | opts] ++ bar)
  end

  defmacro defscript(name, foo, bar) do
    Militerm.ECS.System.define_script_function(name, foo ++ bar)
  end

  defmacro defcommand(name, opts),
    do: Militerm.ECS.System.define_command_function(name, opts)

  defmacro defcommand(name, foo, bar, opts) do
    Militerm.ECS.System.define_command_function(name, [{:as, foo} | opts] ++ bar)
  end

  defmacro defcommand(name, foo, bar) do
    Militerm.ECS.System.define_command_function(name, foo ++ bar)
  end

  @doc false
  def define_script_function({name, loc, args} = header, opts) do
    arity = Enum.count(args)
    script_name = Keyword.get(opts, :as, name |> to_string |> String.capitalize())
    # script_name = as |> to_string() |> String.capitalize()
    function_name = String.to_atom("script_" <> to_string(name))
    body = Keyword.fetch!(opts, :do)
    object_ref = Keyword.get(opts, :for, {:_, loc, nil})

    quote do
      def unquote({function_name, loc, args ++ [object_ref]}), do: unquote(body)

      @script_functions [
        {{unquote(script_name), unquote(arity)}, {unquote(function_name), []}}
        | @script_functions
      ]
    end
  end

  @doc false
  def define_command_function({name, loc, args} = header, opts) do
    command = name |> to_string()
    function_name = String.to_atom("cmd_" <> to_string(name))
    body = Keyword.fetch!(opts, :do)
    object_ref = Keyword.get(opts, :for, {:_, loc, nil})

    quote do
      def unquote({function_name, loc, args ++ [object_ref]}), do: unquote(body)

      @commands [
        {unquote(command), {unquote(function_name), []}} | @commands
      ]
    end
  end
end
