defmodule Militerm.Compilers.Script do
  @moduledoc false

  @constants %{
    "True" => true,
    "False" => false
  }

  @spec compile([]) :: {}
  def compile(parse_tree) do
    compile([], parse_tree)
    |> Enum.reverse()
    |> List.to_tuple()
  end

  @spec compile([], {}) :: []
  def compile(acc, tuple) when is_tuple(tuple), do: compile(acc, [tuple])

  @spec compile([], []) :: []
  def compile(acc, []), do: acc

  def compile(acc, [{:noop} | rest]) do
    acc
    |> encode(:noop)
    |> compile(rest)
  end

  def compile(acc, [:noop | rest]) do
    acc
    |> encode(:noop)
    |> compile(rest)
  end

  def compile(acc, [{:int, int} | rest]) do
    acc
    |> push(int)
    |> compile(rest)
  end

  def compile(acc, [{:float, float} | rest]) do
    acc
    |> push(float)
    |> compile(rest)
  end

  def compile(acc, [{:string, string} | rest]) do
    acc
    |> push(string)
    |> compile(rest)
  end

  def compile(acc, [{:make_list, list} | rest]) do
    acc
    |> compile(Enum.reverse(list))
    |> push(Enum.count(list))
    |> encode(:make_list)
    |> compile(rest)
  end

  def compile(acc, [{:make_dict, list} | rest]) do
    list
    |> Enum.reverse()
    |> Enum.reduce(acc, fn {key, expr}, acc ->
      acc
      |> compile(expr)
      |> push(key)
    end)
    |> push(Enum.count(list))
    |> encode(:make_dict)
    |> compile(rest)
  end

  def compile(acc, [{:event, target, event, pov, args}]) do
    args
    |> compile([{:make_dict, args}])
    |> push(pov)
    |> push(event)
    |> push(target)
    |> encode(:get_obj)
    |> encode(:trigger_event)
  end

  def compile(acc, [{:const, name} | rest]) do
    acc
    |> push(Map.get(@constants, name, nil))
    |> compile(rest)
  end

  def compile(acc, [{:var, name} | rest]) do
    acc
    |> push(name)
    |> encode(:get_var)
    |> compile(rest)
  end

  def compile(acc, [{:obj, name} | rest]) do
    acc
    |> push(name)
    |> encode(:get_obj)
    |> compile(rest)
  end

  def compile(acc, [{:set_var, name} | rest]) do
    acc
    |> push(true)
    |> push(name)
    |> encode(:set_var)
    |> compile(rest)
  end

  def compile(acc, [{:set_var, name, exp} | rest]) do
    acc
    |> compile(exp)
    |> push(name)
    |> encode(:set_var)
    |> compile(rest)
  end

  def compile(acc, [{:set_prop, name} | rest]) do
    acc
    |> push(true)
    |> push(name)
    |> encode(:set_this_prop)
    |> compile(rest)
  end

  def compile(acc, [{:set_prop, name, exp} | rest]) do
    acc
    |> compile(exp)
    |> push(name)
    |> encode(:set_this_prop)
    |> compile(rest)
  end

  def compile(acc, [{:reset_prop, name} | rest]) do
    acc
    |> push(name)
    |> encode(:reset_this_prop)
    |> compile(rest)
  end

  def compile(acc, [{:this_can, false, {adjective, pov}} | rest]) do
    acc
    |> push(pov)
    |> push(adjective)
    |> encode(:this_can)
    |> compile(rest)
  end

  def compile(acc, [{:this_can, true, {adjective, pov}} | rest]) do
    acc
    |> push(pov)
    |> push(adjective)
    |> encode(:this_can)
    |> encode(:not)
    |> compile(rest)
  end

  def compile(acc, [{:this_is, false, {adjective, _pov}} | rest]) do
    acc
    |> push(adjective)
    |> encode(:this_is)
    |> compile(rest)
  end

  def compile(acc, [{:this_is, true, {adjective, _pov}} | rest]) do
    acc
    |> push(adjective)
    |> encode(:this_is)
    |> encode(:not)
    |> compile(rest)
  end

  def compile(acc, [{:uhoh, exp} | rest]) do
    acc
    |> compile(exp)
    |> encode(:uhoh)
    |> encode(:done)
    |> compile(rest)
  end

  def compile(acc, [{:function, name, args} | rest]) do
    args
    |> Enum.reverse()
    |> Enum.map(&[&1])
    |> List.foldl(acc, &compile(&2, &1))
    |> encode(:call)
    |> encode(name)
    |> encode(Enum.count(args))
    |> compile(rest)
  end

  def compile(acc, [{:when, conditionals} | rest]) do
    acc
    |> compile_conditionals(conditionals)
    |> compile(rest)
  end

  def compile(acc, [[:index | indices] | rest]) do
    acc
    |> compile_indices(indices)
    |> encode(:index)
    |> encode(Enum.count(indices))
    |> compile(rest)
  end

  def compile(acc, [{:context, name} | rest]) do
    acc
    |> push(name)
    |> encode(:get_context_var)
    |> compile(rest)
  end

  # :near         => {"near", 2, :left},
  # :under        => {"under", 2, :left},
  # :in           => {"in", 2, :left},
  # :above        => {"above", 2, :left},
  # :on           => {"on", 2, :left},
  #
  # :intersection => {"&", 4, :left},
  # :union        => {"|", 3, :left},
  # :diff         => {"~", 3, :left}

  def compile(acc, [{:mod, list} | rest]) do
    (List.duplicate(:mod, Enum.count(list) - 1) ++
       (list
        |> Enum.reverse()
        |> Enum.map(&[&1])
        |> List.foldl(acc, &compile(&2, &1))))
    |> compile(rest)
  end

  def compile(acc, [{:default, [left | [right | _]]} | rest]) do
    acc
    |> compile(left)
    |> dup
    |> push(nil)
    |> push(2)
    |> encode(:eq)
    |> do_if(fn code ->
      code
      |> drop
      |> compile(right)
    end)
  end

  def compile(acc, [{:prop, [{:context, context} | list]} | rest]) when is_list(list) do
    acc
    |> compile_prop_args(list)
    |> push(Enum.count(list))
    |> push(context)
    |> encode(:get_context_var)
    |> encode(:get_prop)
    |> compile(rest)
  end

  def compile(acc, [{:prop, list} | rest]) when is_list(list) do
    acc
    |> compile_prop_args(list)
    |> push(Enum.count(list))
    |> push("this")
    |> encode(:get_context_var)
    |> encode(:get_prop)
    |> compile(rest)
  end

  def compile(acc, [{:prop, name} | rest]) do
    acc
    |> push(name)
    |> encode(:get_this_prop)
    |> compile(rest)
  end

  def compile(acc, [{:mpy, list} | rest]) do
    acc
    |> compile_series(:product, list)
    |> compile(rest)
  end

  def compile(acc, [{:plus, list} | rest]) do
    acc
    |> compile_series(:sum, list)
    |> compile(rest)
  end

  def compile(acc, [{:minus, [first | list]} | rest]) do
    acc
    |> compile_series(:sum, list)
    |> compile([first])
    |> encode(:difference)
    |> compile(rest)
  end

  def compile(acc, [{:concat, list} | rest]) do
    acc
    |> compile_series(:concat, list)
    |> compile(rest)
  end

  def compile(acc, [{:div, [first | list]} | rest]) do
    acc
    |> compile_series(:product, list)
    |> compile([first])
    |> encode(:div)
    |> compile(rest)
  end

  def compile(acc, [{:intersection, list} | rest]) do
    acc
    |> compile_series(:set_intersection, list)
    |> compile(rest)
  end

  def compile(acc, [{:union, list} | rest]) do
    acc
    |> compile_series(:set_union, list)
    |> compile(rest)
  end

  def compile(acc, [{:diff, [first | list]} | rest]) do
    acc
    |> compile_series(:set_union, list)
    |> compile([first])
    |> encode(:set_diff)
    |> compile(rest)
  end

  def compile(acc, [{:and, list} | rest]) do
    acc
    |> compile_series(:and, list)
    |> compile(rest)
  end

  def compile(acc, [{:or, list} | rest]) do
    acc
    |> compile_series(:or, list)
    |> compile(rest)
  end

  def compile(acc, [{:not, exp} | rest]) do
    acc
    |> compile([exp])
    |> encode(:not)
    |> compile(rest)
  end

  def compile(acc, [{:lt, list} | rest]) do
    acc
    |> compile_series(:lt, list)
    |> compile(rest)
  end

  def compile(acc, [{:gt, list} | rest]) do
    acc
    |> compile_series(:gt, list)
    |> compile(rest)
  end

  def compile(acc, [{:ne, list} | rest]) do
    acc
    |> compile_series(:ne, list)
    |> compile(rest)
  end

  def compile(acc, [{:eq, list} | rest]) do
    acc
    |> compile_series(:eq, list)
    |> compile(rest)
  end

  def compile(acc, [{:le, list} | rest]) do
    acc
    |> compile_series(:le, list)
    |> compile(rest)
  end

  def compile(acc, [{:ge, list} | rest]) do
    acc
    |> compile_series(:ge, list)
    |> compile(rest)
  end

  def compile(acc, [{:sensation, sense, message} | rest]) do
    acc
    |> compile(message)
    |> push(0)
    |> push(sense)
    |> encode(:narrate)
    |> compile(rest)
  end

  def compile(acc, [{:sensation, sense, volume, message} | rest]) do
    acc
    |> compile(message)
    |> push(volume)
    |> push(sense)
    |> encode(:narrate)
    |> compile(rest)
  end

  def compile(acc, list) do
    []
  end

  defp compile_indices(acc, indices)

  defp compile_indices(acc, []), do: acc

  defp compile_indices(acc, [index | indices]) do
    case compile(acc, index) do
      [_ | [:push | _]] = acc ->
        acc
        |> encode(:get_prop)
        |> compile_indices(indices)

      _ = acc ->
        acc
        |> encode(:index)
        |> compile_indices(indices)
    end
  end

  defp compile_conditionals(acc, conditionals, locs \\ [])

  defp compile_conditionals(acc, [], []), do: acc

  defp compile_conditionals(acc, [], locs) do
    List.foldl(locs, acc, fn loc, acc -> jump_from(acc, loc) end)
  end

  defp compile_conditionals(acc, [{guard, block}], locs) do
    {next_loc, acc} =
      acc
      |> compile(guard)
      |> jump_unless

    acc
    |> compile(block)
    |> jump_from(next_loc)
    |> compile_conditionals([], locs)
  end

  defp compile_conditionals(acc, [{guard, block} | rest], locs) do
    {next_loc, acc} =
      acc
      |> compile(guard)
      |> jump_unless

    {loc, acc} =
      acc
      |> compile(block)
      |> jump

    acc
    |> jump_from(next_loc)
    |> compile_conditionals(rest, [loc | locs])
  end

  defp compile_conditionals(acc, [{block}], locs) do
    acc
    |> compile(block)
    |> compile_conditionals([], locs)
  end

  defp compile_series(acc, op, list) do
    list
    |> Enum.reverse()
    |> List.foldl(acc, &compile(&2, &1))
    |> push(Enum.count(list))
    |> encode(op)
  end

  def compile_prop_args(acc, []), do: acc

  def compile_prop_args(acc, [{:prop, name} | rest]) when is_binary(name) do
    acc
    |> push(name)
    |> compile_prop_args(rest)
  end

  def compile_prop_args(acc, [name | rest]) when is_binary(name) do
    acc
    |> push(name)
    |> compile_prop_args(rest)
  end

  def compile_prop_args(acc, [exp | rest]) do
    acc
    |> compile(exp)
    |> compile_prop_args(rest)
  end

  defp dup(acc), do: [:dup | acc]

  defp drop(acc), do: [:drop | acc]

  defp jump_unless(acc) do
    {
      Enum.count(acc) + 1,
      acc
      |> encode(:jump_unless)
      |> encode(0)
    }
  end

  @spec do_if([Any], Any) :: [Any]
  defp do_if(acc, function) do
    {loc, code} = jump_unless(acc)

    code
    |> function.()
    |> jump_from(loc)
  end

  @spec jump([Any]) :: {integer, [Any]}
  defp jump(acc) do
    {
      Enum.count(acc) + 1,
      acc
      |> encode(:jump)
      |> encode(0)
    }
  end

  @spec jump([Any], Any) :: [Any]
  defp jump(acc, function) do
    {loc, code} = jump(acc)

    code
    |> function.()
    |> jump_from(loc)
  end

  @spec jump_from([Any], integer) :: [Any]
  defp jump_from(acc, loc) do
    length = Enum.count(acc)
    List.replace_at(acc, -loc - 1, length - loc - 1)
  end

  @spec push([Any], Any) :: [Any]
  defp push(acc, value) do
    acc
    |> encode(value)
  end

  @spec encode([Any], Any) :: [Any]
  defp encode(acc, op), do: [op | acc]
end
