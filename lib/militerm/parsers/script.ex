defmodule Militerm.Parsers.Script do
  @moduledoc """
  Parse event scripting language.
  """

  require YamlElixir
  alias Militerm.Util.Scanner

  @sensations "(sight|sound|cold|heat|vibration)"

  @binops %{
    :prop => {".", 20, :left},
    # :can          => {"can", 15, :left},
    # :is           => {"is", 15, :left},
    :default => {"//", 10, :left},
    :mpy => {"*", 4, :left},
    :div => {"/", 4, :left},
    :mod => {"%", 4, :left},
    :plus => {"+", 3, :left},
    :concat => {"_", 3, :left},
    :minus => {"-", 3, :left},
    :lt => {"<", 2, :left},
    :le => {"<=", 2, :left},
    :eq => {"=", 2, :left},
    :ge => {">=", 2, :left},
    :gt => {">", 2, :left},
    :ne => {"<>", 2, :left},
    :and => {"and", 1, :left},
    :or => {"or", 0, :left},
    :near => {"near", 2, :left},
    :under => {"under", 2, :left},
    :in => {"in", 2, :left},
    :above => {"above", 2, :left},
    :on => {"on", 2, :left},
    :intersection => {"&", 4, :left},
    :union => {"|", 3, :left},
    :diff => {"~", 3, :left}
  }

  @binop_nary [:plus, :minus, :mpy, :div, :mod, :and, :or, :default, :prop, :concat]

  @binop_code @binops
              |> Map.keys()
              |> Enum.into([], fn k ->
                {elem(@binops[k], 0), k}
              end)
              |> Map.new()

  @binop_regex elem(
                 Regex.compile(
                   "(" <>
                     (@binops
                      |> Map.keys()
                      |> Enum.sort(fn a, b ->
                        String.length(elem(@binops[a], 0)) > String.length(elem(@binops[b], 0))
                      end)
                      |> Enum.map(fn k ->
                        @binops[k]
                        |> elem(0)
                        |> String.replace(~r/[*.?()+{}\[\]|]/, "\\\\\\0")
                        |> String.replace(~r/[a-zA-Z]$/, "\\0\\b")
                      end)
                      |> Enum.join("|")) <> ")"
                 ),
                 1
               )

  @doc """
  Parses an archetype, trait/mixin, verb, or adverb.
  ## Examples

  ### Archetype

      iex> info = Script.parse(:archetype, "")
      iex> info[:errors]
      []
      iex> info = Script.parse(:archetype, ~s\"\"\"
      ...>     ---
      ...>     flags:
      ...>        living: false
      ...>     ---
      ...>     based on foo:bar
      ...>     is positional, movable, gendered
      ...>     is reading, smelling, viewing
      ...>
      ...>     can scan:brief as actor
      ...>     can scan:item as actor
      ...>
      ...>     can move:accept
      ...>     can see
      ...>     can smell
      ...>
      ...>     reacts to post-foo:bar with do
      ...>       sight:"<actor:name> <foo> around."
      ...>     end
      ...>
      ...>     reacts to some:event with do
      ...>       [ <- foo:bar ]
      ...>       [ direct <- bar:baz as observer with bit: 4]
      ...>     end
      ...>
      ...>     calculates fooo with direct.detail:default:enter:target
      ...>
      ...>     reacts to post-foo:gaz with do
      ...>       :"<Actor:name> <foo> around."
      ...>     end
      ...>
      ...>     reacts to pre-move:accept with
      ...>       True
      ...>
      ...>     reacts to post-move:accept with
      ...>       if physical:location.detail:default:position and not (this.physical:position & trait:allowed:positions) then
      ...>         set physical:position to physical:location.detail:default:position
      ...>       end
      ...>
      ...>     reacts to post-scan:env:brief as actor with
      ...>       if eflag:brief-scan then
      ...>         :"<Actor:name> <look> around."
      ...>         Emit( "{title}{{ location:environment }}{/title}" )
      ...>         Emit( "{env sense='sight'}{{ Describe() }}{/env}" ) #"
      ...>         Emit( "Obvious exits: {{ ItemList( Exits() ) }}." ) #"
      ...>         reset eflag:brief-scan
      ...>         reset eflag:scanning
      ...>       end
      ...>
      ...>     reacts to msg:sight with
      ...>       Emit("narrative:sight", text)
      ...>
      ...>     calculates foo with 1 + 1 * 2 * 3 + 4 * 5
      ...>
      ...>     calculates bar with "Strings " _ "are " _ "joinable."
      ...>     \"\"\")
      iex> info[:errors]
      []
      iex> info[:data]["flags"]["living"]
      false
      iex> info[:ur_name]
      "foo:bar"
      iex> info[:mixins]
      ["positional", "movable", "gendered", "reading", "smelling", "viewing"]
      iex> info[:calculations]
      [
        {"bar", {
                  :concat,
                  [
                    {:string, "Strings "},
                    {:string, "are "},
                    {:string, "joinable."}
                  ]
                }},
        {"foo", {
                  :plus,
                  [
                    {:int, 1},
                    {:mpy, [{:int, 1}, {:int, 2}, {:int, 3}]},
                    {:mpy, [{:int, 4}, {:int, 5}]}
                  ]
                }},
        {"fooo", {
                 :prop,
                 [
                  {:prop, "detail:default:enter:target"},
                  {:context, "direct"}
               ]
        }}
      ]

  ### Quality or Mixin

      iex> info = Script.parse(:trait, ~s\"\"\"
      ...>     ---
      ...>     flags:
      ...>        living: false
      ...>     ---
      ...>     \"\"\")
      iex> info[:data]["flags"]["living"]
      false

  ### Verb

      iex> verb = Script.parse(:verb, ~s\"\"\"
      ...>     ---
      ...>     verbs:
      ...>       - look
      ...>     brief: Examine your environment
      ...>     see also:
      ...>       - examine
      ...>     actions:
      ...>       - scan:brief
      ...>     senses:
      ...>       - see
      ...>     class: action
      ...>     ---
      ...>
      ...>     This command allows you to see a description of the area around you,
      ...>     including what other things are there with you.
      ...>     \"\"\")
      iex> verb["brief"]
      "Examine your environment"
      iex> verb["help"]
      "This command allows you to see a description of the area around you,\\n" <>
      "including what other things are there with you."
  """
  @spec parse(:archetype | :trait | :verb | :adverb, String.t()) :: Map
  def parse(:archetype, source) do
    source
    |> Scanner.new()
    |> parse_allowing(
      "archetype",
      MapSet.new([
        :mixins,
        :traits,
        :abilities,
        :calculations,
        :data,
        :archetype,
        :finally,
        :reactions,
        :validators
      ])
    )
  end

  def parse(:trait, source) do
    source
    |> Scanner.new()
    |> parse_allowing(
      "trait",
      MapSet.new([
        :mixins,
        :traits,
        :abilities,
        :calculations,
        :data,
        :finally,
        :reactions,
        :validators
      ])
    )
  end

  def parse(:verb, source) do
    with source_with_newlines <- "\n" <> source <> "\n",
         [_ | [yaml_source | help_bits]] <- source_with_newlines |> String.split(~r/\n---\n/),
         {:ok, data} <- YamlElixir.read_from_string(yaml_source) do
      Map.merge(data, %{"help" => help_bits |> Enum.join("\n---\n") |> String.trim()})
    else
      _ -> %{}
    end
  end

  def parse(:adverb, source), do: parse(:verb, source)

  defp parse_allowing({:error, _} = error, _, _), do: error

  defp parse_allowing(source, item_type, parts) do
    parse_statements({source, item_type, parts}, %{
      mixins: [],
      abilities: %{},
      traits: [],
      calculations: [],
      reactions: %{},
      validators: [],
      data: extract_yaml(source, %{}),
      ur_name: nil,
      finally: nil,
      errors: []
    })
  end

  defp extract_yaml(source, struct) do
    skip_all_space(source)

    cond do
      Scanner.scan(source, ~r/---\n\s*---\n/) ->
        struct

      Scanner.scan(source, ~r/---\n/) ->
        body =
          case Scanner.scan_until(source, ~r/\n---\n/) do
            nil ->
              text = Scanner.rest(source)
              # doesn"t kill it - just marks it as eos
              Scanner.terminate(source)
              text

            otherwise ->
              otherwise
          end

        case YamlElixir.read_from_string(body) do
          {:ok, yaml} ->
            if is_map(yaml), do: merge_yaml(struct, yaml), else: struct

          _ ->
            struct
        end

      true ->
        struct
    end
  end

  defp merge_yaml(map1, map2) when is_map(map1) and is_map(map2) do
    Map.merge(map1, map2, fn _, m1, m2 -> merge_yaml(m1, m2) end)
  end

  defp merge_yaml(_, value), do: value

  defp skip_all_space(source) do
    Scanner.skip(source, ~r/([ \t\r\f\n]*(#[^\n]*)?)*[ \t\r\f\n]*/)
    source
  end

  defp skip_space(source) do
    Scanner.skip(source, ~r/[ \t\r\f]*/)
    source
  end

  defp at_end_of_statement?(source, sep \\ ~r/;/) do
    skip_space(source)

    case Regex.compile("(\n|#{Regex.source(sep)})") do
      {:ok, pat} ->
        Scanner.eos?(source) || Scanner.match?(source, pat) ||
          Scanner.match?(source, ~r/\#[^\n]*\n/)

      _ ->
        false
    end
  end

  defp expect_end_of_statement(source, sep \\ ~r/;/) do
    if at_end_of_statement?(source, sep) do
      skip_all_space(source)
      :ok
    else
      {:ok, regex} = Regex.compile("\\n|#{Regex.source(sep)}")

      {
        :error,
        Scanner.error(
          source,
          "Expected new line or expression separator",
          regex
        )
      }
    end
  end

  defp parse_statements(config, info) do
    case select_and_run_parse_method(config, info) do
      {:done, info} -> info
      {:ok, info} -> parse_statements(config, info)
    end
  end

  defp select_and_run_parse_method({source, _, _} = config, info) do
    source
    |> skip_all_space
    |> select_parse_method
    |> run_parse_method(config, info)
  end

  defp run_parse_method(nil, _, info), do: {:done, info}

  defp run_parse_method({:error, error}, _, info) do
    {:ok, %{info | errors: [error | info[:errors]]}}
  end

  defp run_parse_method(method, {source, _, _} = config, info) do
    skip_space(source)

    case apply(__MODULE__, method, [config, info]) do
      {:ok, new_info} -> {:ok, new_info}
      {:error, error} -> {:ok, %{info | errors: [error | info[:errors]]}}
    end
  end

  defp select_parse_method(source) do
    method =
      cond do
        Scanner.eos?(source) -> nil
        Scanner.scan(source, ~r/based\s+on\b/) -> :parse_archetype
        Scanner.scan(source, ~r/is\b/) -> :parse_trait_or_mixin
        Scanner.scan(source, ~r/calculates\b/) -> :parse_calculation
        Scanner.scan(source, ~r/reacts\s+to\b/) -> :parse_reaction
        Scanner.scan(source, ~r/validates\b/) -> :parse_validation
        Scanner.scan(source, ~r/can\b/) -> :parse_ability
        true -> :parse_data_setting
      end

    skip_all_space(source)
    method
  end

  def parse_data_setting({source, item_type, parts} = config, info) do
    case parse_nc_name(source) do
      nil ->
        {:error, Scanner.error(source, "Expected a NCNAME", ~r/\s/)}

      {:ok, name} ->
        if Scanner.scan(source, ~r/^starts\s+as\b/) do
          skip_all_space(source)

          case parse_expression(source) do
            {:ok, parsed_expression} ->
              if :data in parts do
                {:ok, %{info | data: Map.put(info[:data], name, parsed_expression)}}
              else
                {:error, Scanner.error(source, "Data is not allowed in #{item_type} definitions")}
              end

            {:error, error} = otherwise ->
              otherwise
          end
        else
          {:error, Scanner.error(source, "Unable to parse directive (#{name})", ~r/[\n;]/)}
        end

      {:error, _} = otherwise ->
        otherwise
    end
  end

  def parse_trait_or_mixin({source, item_type, parts}, info) do
    can_have_mixins = :mixins in parts

    cond do
      !can_have_mixins || Scanner.match?(source, ~r/[^,\n]+?[ \t\f\r](if|unless|when)\b/) ->
        if :traits in parts do
          case parse_trait(source) do
            {:ok, trait} ->
              {:ok, %{info | traits: [trait | info[:traits]]}}

            otherwise ->
              otherwise
          end
        else
          Scanner.error(
            source,
            "Qualities are not allowed in #{item_type} definitions",
            ~r/[\n;]/
          )
        end

      can_have_mixins ->
        case parse_mixin(source) do
          {:ok, mixins} ->
            {:ok, %{info | mixins: info[:mixins] ++ mixins}}

          otherwise ->
            otherwise
        end

      true ->
        Scanner.error(
          source,
          "Inherited traits are not allowed in #{item_type} definitions",
          ~r/[\n;]/
        )
    end
  end

  defp parse_trait(source) do
    skip_space(source)
    negated = Scanner.scan(source, ~r/not\b/)
    skip_space(source)

    case parse_nc_name(source) do
      {:ok, name} ->
        exp =
          if Scanner.scan(source, ~r/(if|unless|when)\b/) do
            negated =
              case Scanner.matches(source) do
                ["unless" | _] -> !negated
                _ -> negated
              end

            skip_space(source)

            negated =
              if Scanner.scan(source, ~r/not\b/) do
                !negated
              else
                negated
              end

            skip_all_space(source)

            case parse_expression(source) do
              {:ok, exp} ->
                if negated do
                  case exp do
                    {:not, clause} -> {:ok, clause}
                    otherwise -> {:ok, {:not, otherwise}}
                  end
                else
                  {:ok, exp}
                end

              otherwise ->
                otherwise
            end
          else
            truth =
              if negated do
                "False"
              else
                "True"
              end

            case expect_end_of_statement(source) do
              :ok -> {:ok, {:const, truth}}
              otherwise -> otherwise
            end
          end

        case exp do
          {:ok, expression} -> {:ok, {name, expression}}
          otherwise -> otherwise
        end

      _ ->
        {:error, Scanner.error(source, "Expected an NCNAME", ~r/[\n;]/)}
    end
  end

  defp parse_ability_clause(source) do
    skip_space(source)
    negated = Scanner.scan(source, ~r/not\b/)
    skip_space(source)

    with {:ok, name} <- parse_nc_name(source),
         {:ok, pov} <- parse_pov(source) do
      if Scanner.scan(source, ~r/(if|unless|when)\b/) do
        negated =
          case Scanner.matches(source) do
            ["unless" | _] -> !negated
            _ -> negated
          end

        skip_all_space(source)

        case parse_expression(source) do
          {:ok, exp} ->
            if negated do
              case exp do
                {:not, clause} -> {:ok, {name, pov, clause}}
                otherwise -> {:ok, {name, pov, {:not, otherwise}}}
              end
            else
              {:ok, {name, pov, exp}}
            end

          otherwise ->
            otherwise
        end
      else
        truth =
          if negated do
            "False"
          else
            "True"
          end

        case expect_end_of_statement(source) do
          :ok -> {:ok, {name, pov, {:const, truth}}}
          otherwise -> otherwise
        end
      end
    else
      _ -> {:error, Scanner.error(source, "Expected an NCNAME", ~r/[\n;]/)}
    end
  end

  def parse_ability({source, _, _}, info) do
    case parse_ability_clause(source) do
      {:ok, {name, role, ast}} ->
        {:ok, %{info | abilities: Map.put(info[:abilities], {name, role}, ast)}}

      otherwise ->
        otherwise
    end
  end

  defp parse_mixin(source, acc \\ []) do
    skip_all_space(source)

    case parse_nc_name(source) do
      {:ok, name} ->
        skip_space(source)

        if Scanner.scan(source, ~r/,\s*/) do
          skip_all_space(source)
          parse_mixin(source, [name | acc])
        else
          case expect_end_of_statement(source) do
            :ok -> {:ok, Enum.reverse([name | acc])}
            otherwise -> otherwise
          end
        end

      _ ->
        {:error, Scanner.error(source, "Expected a trait name", ~r/[\n;]/)}
    end
  end

  def parse_archetype({source, item_type, parts}, info) do
    if :archetype in parts do
      if info[:ur_name] do
        {:error, Scanner.error(source, "Archetype base is already defined", ~r/[\n;]/)}
      else
        case parse_nc_name(source) do
          {:ok, ur_name} ->
            {:ok, %{info | ur_name: ur_name}}

          _ ->
            {:error,
             Scanner.error(
               source,
               "#{item_type |> String.capitalize()} is noted as based on another archetype but no archetype is named",
               ~r/[\n;]/
             )}
        end
      end
    else
      {:error,
       Scanner.error(source, "Archetypes are not allowed in #{item_type} definitions", ~r/[\n;]/)}
    end
  end

  def parse_calculation({source, _, _}, info) do
    with {:ok, quantity} <- parse_nc_name(source),
         :ok <- Scanner.expect(source, ~r/with\b/),
         {:ok, exp} <- parse_expression(source) do
      {:ok, %{info | calculations: [{quantity, exp} | info[:calculations]]}}
    else
      otherwise -> otherwise
    end
  end

  def parse_reaction({source, _, _}, info) do
    with {:ok, event} <- parse_nc_name(source),
         {:ok, pov} <- parse_pov(source),
         :ok <- Scanner.expect(source, ~r/with\b/),
         {:ok, exp} <- parse_expression(source) do
      {:ok, %{info | reactions: Map.put(info[:reactions], {event, pov}, exp)}}
    else
      otherwise -> otherwise
    end
  end

  defp parse_pov(source) do
    skip_space(source)

    if Scanner.scan(source, ~r/as\b/) do
      skip_all_space(source)

      case parse_nc_name(source) do
        {:ok, pov} ->
          skip_space(source)
          {:ok, pov}

        nil ->
          {:error, Scanner.error(source, "Expected a point of view")}

        otherwise ->
          otherwise
      end
    else
      {:ok, "any"}
    end
  end

  def parse_validation({source, _, _}, info) do
    with {:ok, quantity} <- parse_nc_name(source),
         :ok <- Scanner.expect(source, ~r/with\b/),
         {:ok, exp} <- parse_expression(source) do
      {:ok, %{info | validators: [{quantity, exp} | info[:validators]]}}
    else
      otherwise -> otherwise
    end
  end

  defp scan_token(source, regex) do
    if Scanner.scan(source, regex) do
      [_ | [match | _]] =
        source
        |> Scanner.matches()

      skip_space(source)
      {:ok, match}
    else
      Scanner.scan_until(source, ~r/\s/)
      skip_space(source)
      {:error, Scanner.error(source, "Expected #{Regex.source(regex)}")}
    end
  end

  defp parse_nc_name(source) do
    skip_space(source)
    scan_token(source, ~r/([a-z][-a-z_A-Z0-9]*(:\$?[a-z][-a-z_A-Z0-9]*)*)/)
  end

  defp parse_method_name(source) do
    skip_space(source)
    scan_token(source, ~r/\#([a-z][-a-z_A-Z0-9]*(:\$?[a-z][-a-z_A-Z0-9]*)*)/)
  end

  defp parse_named_argument_name(source) do
    skip_space(source)
    scan_token(source, ~r/([a-z][-a-z_A-Z0-9]*)/)
  end

  defp parse_uhoh(source) do
    skip_space(source)

    case parse_expression(source) do
      {:ok, exp} ->
        {:ok, {:uhoh, exp}}

      otherwise ->
        otherwise
    end
  end

  defp parse_var_name(source) do
    scan_token(source, ~r/\$([a-zA-Z][-a-zA-Z0-9_]*)/)
  end

  defp parse_obj_name(source) do
    scan_token(source, ~r/\@([a-zA-Z][-a-zA-Z0-9_]*)/)
  end

  def parse_expression(source, regex \\ nil) do
    with {:ok, term} <- parse_term(source),
         {:ok, terms, ops} <- gather_terms_and_ops(source, regex, [term], []) do
      case terms do
        [term | []] ->
          {:ok, term}

        [left | [right | []]] ->
          [op | _] = ops
          {:ok, {op, [left, right]}}

        _ ->
          {:ok, flatten_tree(precedence_tree(terms, ops, [], []))}
      end
    else
      {:error, _} = otherwise -> otherwise
    end
  end

  # this is because if we aren't careful, the precedence tree will get pretty deep
  defp flatten_tree([list | []]), do: flatten_tree(list)

  defp flatten_tree(list), do: list

  defp gather_terms_and_ops(source, sep, terms, ops) do
    skip_space(source)

    cond do
      sep != nil && Scanner.scan(source, sep) ->
        {:ok, terms, ops}

      Scanner.scan(source, @binop_regex) ->
        [op | _] = Scanner.matches(source)
        skip_all_space(source)
        op_code = @binop_code[op]

        case parse_term(source) do
          {:ok, term} ->
            gather_terms_and_ops(source, sep, [term | terms], [op_code | ops])

          _ = otherwise ->
            if sep != nil do
              Scanner.scan_until(source, sep)
              skip_space(source)
            end

            {:error, Scanner.error(source, "Expected a term following #{op}")}
        end

      true ->
        {:ok, terms, ops}
    end
  end

  defp precedence_tree([], [], [val | _] = _val_stack, []), do: val

  defp precedence_tree([], [], val_stack, [op | op_stack]) do
    precedence_tree([], [], combine_top_vals(val_stack, op), op_stack)
  end

  defp precedence_tree([term | []], [], val_stack, [op | more_ops]) do
    precedence_tree([], [], combine_top_vals([term | val_stack], op), more_ops)
  end

  defp precedence_tree([term | terms], [op | ops], [], []) do
    precedence_tree(terms, ops, [term], [op])
  end

  defp precedence_tree([term | terms], [op | ops], val_stack, [top_op | _] = op_stack) do
    cond do
      operator_precedence(op) > operator_precedence(top_op) ->
        precedence_tree(terms, ops, [term | val_stack], [op | op_stack])

      operator_precedence(op) == operator_precedence(top_op) ->
        precedence_tree(terms, ops, combine_top_vals([term | val_stack], op), op_stack)

      true ->
        {new_val_stack, new_op_stack} = unroll_precedence_stack([term | val_stack], op, op_stack)
        precedence_tree(terms, ops, new_val_stack, [op | new_op_stack])
    end
  end

  def unroll_precedence_stack(val_stack, _, []) do
    {val_stack, []}
  end

  def unroll_precedence_stack(val_stack, op, [sop | op_stack]) do
    if operator_precedence(sop) >= operator_precedence(op) do
      unroll_precedence_stack(combine_top_vals(val_stack, op, sop), op, op_stack)
    else
      {val_stack, [sop | op_stack]}
    end
  end

  defp operator_precedence(op) when is_binary(op) do
    elem(@binops[@binop_code[op]], 1)
  end

  defp operator_precedence(op) when is_atom(op) do
    elem(@binops[op], 1)
  end

  defp operator_precedence(_), do: -1

  defp combine_top_vals(val_stack, op, sop \\ nil)

  defp combine_top_vals(val_stack, op, nil), do: combine_top_vals(val_stack, op, op)

  defp combine_top_vals([val | []], _, _), do: [val]

  defp combine_top_vals([{op, left} | [{op, right} | val_stack]], op, _)
       when is_list(left) and is_list(right) do
    [collapse_expressions({op, left ++ right}) | val_stack]
  end

  defp combine_top_vals([{op, left} | [{op, right} | val_stack]], op, _)
       when not is_list(left) and is_list(right) do
    [collapse_expressions({op, [left | right]}) | val_stack]
  end

  defp combine_top_vals([{op, left} | [{op, right} | val_stack]], op, _)
       when is_list(left) and not is_list(right) do
    [collapse_expressions({op, left ++ [right]}) | val_stack]
  end

  defp combine_top_vals([{op, left} | [{op, right} | val_stack]], op, _) do
    [collapse_expressions({op, [left, right]}) | val_stack]
  end

  defp combine_top_vals([left | [{op, right} | val_stack]], op, _) when is_list(right) do
    [collapse_expressions({op, [left] ++ right}) | val_stack]
  end

  defp combine_top_vals([left | [{op, right} | val_stack]], op, _) do
    [collapse_expressions({op, [left, right]}) | val_stack]
  end

  defp combine_top_vals([{op, left} | [right | val_stack]], op, _) when is_list(left) do
    [collapse_expressions({op, left ++ [right]}) | val_stack]
  end

  defp combine_top_vals([{op, left} | [right | val_stack]], op, _) do
    [collapse_expressions({op, [left, right]}) | val_stack]
  end

  defp combine_top_vals([left | [right | val_stack]], _, sop) do
    [collapse_expressions({sop, [left, right]}) | val_stack]
  end

  defp parse_not(source) do
    skip_all_space(source)

    case parse_term(source) do
      {:ok, {:not, exp}} -> {:ok, exp}
      {:ok, exp} -> {:ok, {:not, exp}}
      otherwise -> otherwise
    end
  end

  defp parse_indices(source, acc) do
    if Scanner.scan(source, ~r/\[/) do
      case parse_expression(source, ~r/]/) do
        {:ok, exp} ->
          parse_indices(source, [exp | acc])

        otherwise ->
          otherwise
      end
    else
      {:ok, acc |> Enum.reverse()}
    end
  end

  defp parse_term(source) do
    case parse_term_start(source) do
      {:ok, term_head} ->
        if Scanner.match?(source, ~r/\[/) do
          parse_indices(source, [term_head, :index])
        else
          {:ok, term_head}
        end

      {:error, _} = otherwise ->
        otherwise
    end
  end

  defp parse_term_start(source) do
    skip_all_space(source)

    cond do
      Scanner.scan(source, ~r/if\b/) ->
        parse_if_then_else(source, :if)

      Scanner.scan(source, ~r/unless\b/) ->
        parse_if_then_else(source, :unless)

      Scanner.scan(source, ~r/mapping\b/) ->
        parse_list_processing(source, :map)

      Scanner.scan(source, ~r/selecting\b/) ->
        parse_list_processing(source, :select)

      Scanner.scan(source, ~r/foreach\b/) ->
        parse_list_processing(source, :loop)

      Scanner.scan(source, ~r/not\b/) ->
        parse_not(source)

      Scanner.scan(source, ~r/is\b/) ->
        parse_is_can_q(source, :this_is)

      Scanner.scan(source, ~r/can\b/) ->
        parse_is_can_q(source, :this_can)

      Scanner.scan(source, ~r/\(\{/) ->
        case parse_dictionary_entry(source) do
          {dict, []} ->
            {:ok, {:make_dict, dict}}

          {_, errors} ->
            {:error, errors}
        end

      Scanner.scan(source, ~r/\(\[/) ->
        case parse_list(source) do
          {:ok, list} -> {:ok, {:make_list, list}}
          otherwise -> otherwise
        end

      Scanner.scan(source, ~r/\(\s*(\d+(\.\d*)?|\.\d+)\s*([a-z][a-z\/^0-9]*)\s*\)/) ->
        case Scanner.matches(source) do
          [scalar, units] ->
            {:ok, {:units, scalar, units}}

          _ ->
            {:error, Scanner.error(source, "Unparsable units", ~r/[\s;]/)}
        end

      Scanner.scan(source, ~r/\(/) ->
        skip_all_space(source)
        parse_expression(source, ~r/\)/)

      # Scanner.match?(source, ~r/(sight|sound|cold|heat|vibration)?:\s*(.)/) ->
      #   {sense, l} = case Scanner.matches(source) do
      #     [_, sense, l] ->
      #       {sense, l}
      #     [_, l] ->
      #       {"sight", l, r}
      #   end
      #
      #   r =
      #     case l do
      #       "[" -> "]"
      #       "(" -> ")"
      #       "{" -> "}"
      #       "<" -> ">"
      #       anything_else -> anything_else
      #     end
      #
      #   parse_sensation(source, sense, r)

      Scanner.scan(source, ~r/\{/) ->
        skip_all_space(source)
        parse_compound_expression(source, ~r/\}/)

      Scanner.scan(source, ~r/do\b/) ->
        skip_all_space(source)
        parse_compound_expression(source, ~r/end\b/)

      Scanner.scan(source, ~r/%([sw])(.)/) ->
        [_, sigil, l | _] = Scanner.matches(source)

        r =
          case l do
            "[" -> "]"
            "(" -> ")"
            "{" -> "}"
            "<" -> ">"
            anything_else -> anything_else
          end

        {:ok, regex} = Regex.compile("([^#{Regex.escape(r)}]|\\\\.)*")
        Scanner.scan(source, regex)
        [raw_content | _] = Scanner.matches(source)
        {:ok, regex} = Regex.compile(Regex.escape(r))

        if Scanner.scan(source, regex) do
          raw_content
          |> String.trim()
          |> String.replace(~r/\\(.)/, "\\1")
          |> process_sigil(sigil, source)
        else
          {:error, Scanner.error(source, "Unterminated sigil found", ~r/[;\n]/)}
        end

      Scanner.scan(source, ~r/([-+]?\d*\.\d+)/) ->
        [float | _] = Scanner.matches(source)
        {:ok, {:float, String.to_float(float)}}

      Scanner.scan(source, ~r/([-+]?0b[01]+)/) ->
        [bin | _] = Scanner.matches(source)
        {:ok, {:int, convert_binary(bin)}}

      Scanner.scan(source, ~r/([-+]?0x[0-9a-fA-F]+)/) ->
        [hex | _] = Scanner.matches(source)
        {:ok, {:int, convert_hex(hex)}}

      Scanner.scan(source, ~r/([-+]?0[0-7]+)/) ->
        [oct | _] = Scanner.matches(source)
        {:ok, {:int, convert_octal(oct)}}

      Scanner.scan(source, ~r/([-+]?[1-9]\d*)/) ->
        [int | _] = Scanner.matches(source)
        {:ok, {:int, String.to_integer(int)}}

      Scanner.scan(source, ~r/0\b/) ->
        {:ok, {:int, 0}}

      Scanner.scan(source, ~r/-\(/) ->
        case parse_expression(source, ~r/\)/) do
          {:ok, {:negate, exp}} -> {:ok, exp}
          {:ok, exp} -> {:ok, {:negate, exp}}
          {:error, _} = otherwise -> otherwise
        end

      Scanner.scan(source, ~r/\+?\(/) ->
        parse_expression(source, ~r/\)/)

      Scanner.scan(source, ~r/['"]/) ->
        [q | _] = Scanner.matches(source)
        parse_quoted_string(source, q)

      Scanner.scan(source, ~r/:\s*/) ->
        case parse_expression(source) do
          {:ok, exp} ->
            {:sensation, "sight", 0, exp}

          {:error, _} = otherwise ->
            otherwise
        end

      Scanner.scan(source, ~r/#{@sensations}\s*:\b/) ->
        with [_, sense | _] <- Scanner.matches(source),
             {:ok, exp} <- parse_expression(source),
             {:ok, strength} <- maybe_parse_sensation_strength(source) do
          {:sensation, sense, strength, exp}
        else
          {:error, _} = otherwise ->
            otherwise
        end

      Scanner.scan(source, ~r/[A-Z][-a-z0-9A-Z]*/) ->
        [const | _] = Scanner.matches(source)
        skip_space(source)

        if Scanner.scan(source, ~r/\(/) do
          case parse_arg_list(source) do
            {:ok, args} ->
              {:ok, {:function, const, args}}

            {:error, _} = otherwise ->
              otherwise
          end
        else
          {:ok, {:const, const}}
        end

      Scanner.match?(source, ~r/\$/) ->
        case parse_var_name(source) do
          {:ok, var_name} ->
            {:ok, {:var, var_name}}

          {:error, _} = otherwise ->
            otherwise
        end

      Scanner.match?(source, ~r/\@/) ->
        case parse_obj_name(source) do
          {:ok, obj_name} ->
            {:ok, {:obj, obj_name}}

          {:error, _} = otherwise ->
            otherwise
        end

      true ->
        case parse_nc_name(source) do
          {:ok, nc_name} ->
            if String.contains?(nc_name, ":") do
              {:ok, {:prop, nc_name}}
            else
              if Scanner.scan(source |> skip_space, ~r/:/) do
                case parse_expression(source) do
                  {:ok, exp} ->
                    {:ok, {:sensation, nc_name, exp}}

                  {:error, _} = otherwise ->
                    otherwise
                end
              else
                {:ok, {:context, nc_name}}
              end
            end

          {:error, _} ->
            {:error,
             Scanner.error(
               source,
               "Expected a dictionary, list, number, string, constant, variable, or expression"
             )}
        end
    end
  end

  defp maybe_parse_sensation_strength(source) do
    if Scanner.scan(source, ~r/\s*@\s*(([+-]\d+)|(whisper|normal|shout))/) do
      case Scanner.matches(source) do
        [_, _, "", word] ->
          case word do
            "whisper" -> {:ok, -2}
            "normal" -> {:ok, 0}
            "shout" -> {:ok, +2}
          end

        [_, _, number, _] ->
          {:ok, String.to_integer(number)}
      end
    else
      {:ok, 0}
    end
  end

  defp convert_binary(<<"+0b", digits::binary>>) do
    String.to_integer(digits, 2)
  end

  defp convert_binary(<<"-0b", digits::binary>>) do
    -String.to_integer(digits, 2)
  end

  defp convert_binary(<<"0b", digits::binary>>) do
    String.to_integer(digits, 2)
  end

  defp convert_octal(<<"+0", digits::binary>>) do
    String.to_integer(digits, 8)
  end

  defp convert_octal(<<"-0", digits::binary>>) do
    -String.to_integer(digits, 8)
  end

  defp convert_octal(<<"0", digits::binary>>) do
    String.to_integer(digits, 8)
  end

  defp convert_hex(<<"+0x", digits::binary>>) do
    String.to_integer(digits, 16)
  end

  defp convert_hex(<<"-0x", digits::binary>>) do
    -String.to_integer(digits, 16)
  end

  defp convert_hex(<<"0x", digits::binary>>) do
    String.to_integer(digits, 16)
  end

  defp process_sigil(content, "w", _) do
    {:ok,
     [
       :list
       | content
         |> String.split(~r/\s+/)
         |> Enum.map(fn s ->
           {:string, s}
         end)
     ]}
  end

  defp process_sigil(content, "s", _) do
    {:ok, {:string, content}}
  end

  defp process_sigil(_, sigil, source) do
    {:error, Scanner.error(source, "Unknown sigil (#{sigil})")}
  end

  defp collapse_expressions({op, args}) do
    if Map.has_key?(@binops, op) do
      {op, collapse_expressions(op, args, [])}
    else
      {op, args}
    end
  end

  defp collapse_expressions(_, [], acc), do: Enum.reverse(acc)

  defp collapse_expressions(op, [{op, args} | rest], acc) when is_list(args) do
    collapse_expressions(op, rest, Enum.reverse(args) ++ acc)
  end

  defp collapse_expressions(op, [{op, arg} | rest], acc) do
    collapse_expressions(op, rest, [arg | acc])
  end

  defp collapse_expressions(op, [otherwise | rest], acc),
    do: collapse_expressions(op, rest, [otherwise | acc])

  # defp collapse_expressions(op, [{not_op, args} | rest], acc) when is_atom(not_op) and is_list(args) do
  #   collapse_expressions(op, rest, [{not_op, args} | acc])
  # end

  # defp collapse_expressions(op, [not_list | rest], acc) do
  #   collapse_expressions(op, rest, [not_list | acc])
  # end

  defp parse_if_then_else(source, sense, acc \\ []) do
    reversed = sense == :unless
    skip_space(source)

    with {:ok, condition} <- parse_expression(source, ~r/then\b/),
         {:ok, then_exp} <- parse_compound_expression(source, ~r/(else|elsif|end)\b/) do
      condition =
        case {reversed, condition} do
          {true, {:not, exp}} -> exp
          {true, exp} -> {:not, exp}
          {false, exp} -> exp
        end

      case Scanner.matches(source) do
        ["else" | _] ->
          case parse_compound_expression(source, ~r/end\b/) do
            {:ok, else_exp} ->
              {
                :ok,
                {
                  :when,
                  Enum.reverse([
                    {else_exp}
                    | [
                        {condition, then_exp}
                        | acc
                      ]
                  ])
                }
              }

            {:error, _} = otherwise ->
              otherwise
          end

        ["elsif" | _] ->
          parse_if_then_else(source, :if, [{condition, then_exp} | acc])

        ["end" | _] ->
          {:ok, {:when, Enum.reverse([{condition, then_exp} | acc])}}
      end
    else
      {:error, _} = otherwise ->
        otherwise
    end
  end

  defp parse_list_processing(source, style) do
    if Scanner.scan(source, ~r/as\b/) do
      skip_space(source)

      if Scanner.scan(source, ~r/(\$[a-z][-a-zA-Z0-9_]*)\b/) do
        [_, var_name | _] = Scanner.matches(source)

        case parse_expression(source) do
          {:ok, expression} ->
            {style, var_name, expression}

          {:error, _} = error ->
            error
        end
      else
        {:error, Scanner.error(source, "Expected a variable name following 'as'")}
      end
    else
      case parse_expression(source) do
        {:ok, expression} ->
          {style, "$it", expression}

        {:error, _} = error ->
          error
      end
    end
  end

  defp parse_is_can_q(source, style) do
    negated = Scanner.scan(source |> skip_space, ~r/not\b/)

    with {:ok, adjective} <- source |> skip_space |> parse_nc_name,
         {:ok, pov} <- source |> skip_space |> parse_pov do
      {:ok, {style, negated, {adjective, pov}}}
    else
      otherwise -> otherwise
    end
  end

  defp parse_compound_expression(source, ending, acc \\ []) do
    skip_all_space(source)

    cond do
      Scanner.scan(source, ending) ->
        {:ok, Enum.reverse(acc)}

      Scanner.eos?(source) ->
        {:error,
         Scanner.error(source, "Missing '#{Regex.source(ending)}' for compound expression")}

      Scanner.scan(source, ~r/\$([a-z][-a-zA-Z0-9_]*)\s+starts\s+as\b/) ->
        with [_, var_name | _] <- Scanner.matches(source),
             {:ok, expression} <- parse_expression(source) do
          parse_compound_expression(source, ending, [
            {:set, var_name, expression}
            | acc
          ])
        else
          {:error, _} = otherwise ->
            Scanner.scan_until(source, ending)
            otherwise
        end

      Scanner.scan(source, ~r/uhoh\b/) ->
        case parse_uhoh(source) do
          {:ok, exp} ->
            parse_compound_expression(source, ending, [exp | acc])

          {:error, _} = otherwise ->
            Scanner.scan_until(source, ending)
            otherwise
        end

      Scanner.scan(source, ~r/\[/) ->
        # skip_all_space(source)
        # msg_type: %w(env whisper spoken shout yell scream)
        # msg_itensity: [+-] integer
        # message: (string | expression) ('@' msg_type msg_intensity?)?
        # messages: message
        # messages: messages ',' message
        #
        # message_output: messages
        #
        # acute_sensation: sense ':' message_output
        # chronic_sensation: sense { sensation_steps } 'for' time_spec
        # sensations: sensation
        # sensations: sensations ',' sensation
        # sensation_set: '(*' sensations '*)' (acute)
        # sensation_set: '(*' sensations '*)' 'for' time_spec
        #
        # sensation_chain: sensation_set
        # sensation_chain: sensation_chain '->' sensation_set
        #
        # sensation_steps:
        # sensation_steps: sensation_step
        # sensation_steps: sensation_steps ',' sensation_step
        #
        # sensation_step: sense_step ':' message_output
        # sense_step: %w(start narrative end)
        # sense: %w(light sound heat cold vibration)
        #
        # (* *) -> (* *) ...
        # light {
        #   start:"A light grows brighter.",
        #   narrative:"A light pulses.",
        #   end:"A light grows dim and winks out."
        # }
        # this is an event invocation
        # [ exp '#' nc_name ]
        # [ '#' nc_name ]
        # [ exp '#' nc_name ':' arg list ]
        # [ '#' nc_name ':' arg list ]
        case parse_event_invocation(source) do
          {:ok, exp} ->
            parse_compound_expression(source, ending, [exp | acc])

          {:error, _} = otherwise ->
            Scanner.scan_until(source, ending)
            otherwise
        end

      # {:error, Scanner.error(source, "Who knows?")}

      # Scanner.scan(source, ~r/:(["'(])/) ->
      #   with [ _,  _, q | _ ] <- Scanner.matches(source),
      #        {:ok, sensation} <- parse_sensation(source, "sight", q) do
      #     parse_compound_expression(source, ending, [sensation | acc])
      #   else
      #     {:error, _} = otherwise ->
      #       Scanner.scan_until(source, ending)
      #       otherwise
      #   end

      #   r =
      #     case l do
      #       "[" -> "]"
      #       "(" -> ")"
      #       "{" -> "}"
      #       "<" -> ">"
      #       anything_else -> anything_else
      #     end

      Scanner.scan(source, ~r/:\s*/) ->
        case parse_expression(source) do
          {:ok, exp} ->
            parse_compound_expression(source, ending, [{:sensation, "sight", exp} | acc])

          {:error, _} = otherwise ->
            Scanner.scan_until(source, ending)
            otherwise
        end

      Scanner.scan(source, ~r/#{@sensations}\s*:\b/) ->
        with [_, sense | _] <- Scanner.matches(source),
             {:ok, exp} <- parse_expression(source) do
          parse_compound_expression(source, ending, [{:sensation, sense, exp} | acc])
        else
          {:error, _} = otherwise ->
            Scanner.scan_until(source, ending)
            otherwise
        end

      # Scanner.scan(source, ~r/:\b/) |> IO.inspect ->
      #   with {:ok, exp} <- parse_expression(source) |> IO.inspect do
      #     parse_compound_expression(source, ending, [{:sensation, "sight", exp} | acc])
      #   else
      #     {:error, _} = otherwise ->
      #       Scanner.scan_until(source, ending)
      #       otherwise
      #   end

      # Scanner.scan(source, ~r/#{@sensations}:(["'(])/) ->
      #   with [ _ | [ sense | [ q | _ ]]] <- Scanner.matches(source),
      #        {:ok, sensation} <- parse_sensation(source, sense, q) do
      #     parse_compound_expression(source, ending, [sensation | acc])
      #   else
      #     {:error, _} = otherwise ->
      #       Scanner.scan_until(source, ending)
      #       otherwise
      #   end
      Scanner.scan(source, ~r/set\b/) ->
        case parse_set(source) do
          {:ok, set} ->
            parse_compound_expression(source, ending, [set | acc])

          {:error, _} = otherwise ->
            Scanner.scan_until(source, ending)
            otherwise
        end

      Scanner.scan(source, ~r/(un|re)set\b/) ->
        with [_ | [type | _]] <- Scanner.matches(source),
             {:ok, set} <- parse_reset(source, type) do
          parse_compound_expression(source, ending, [set | acc])
        else
          {:error, _} = otherwise ->
            Scanner.scan_until(source, ending)
            otherwise
        end

      true ->
        case parse_expression(source) do
          {:ok, exp} ->
            parse_compound_expression(source, ending, [exp | acc])

          {:error, _} = otherwise ->
            Scanner.scan_until(source, ending)
            otherwise
        end
    end
  end

  defp parse_set(source) do
    skip_all_space(source)

    if Scanner.match?(source, ~r/\$/) do
      case parse_var_name(source) do
        {:ok, var} ->
          if Scanner.scan(source |> skip_space, ~r/to\b/) do
            case parse_expression(source |> skip_all_space) do
              {:ok, exp} ->
                {:ok, {:set_var, var, exp}}

              {:error, _} = otherwise ->
                otherwise
            end
          else
            {:ok, {:set_var, var}}
          end

        {:error, _} = otherwise ->
          otherwise

        nil ->
          {:error, Scanner.error(source, "Expected 'to' after 'set'")}
      end
    else
      case parse_nc_name(source) do
        {:ok, prop} ->
          if Scanner.scan(source |> skip_space, ~r/to\b/) do
            case parse_expression(source |> skip_all_space) do
              {:ok, exp} ->
                {:ok, {:set_prop, prop, exp}}

              {:error, _} = otherwise ->
                otherwise
            end
          else
            {:ok, {:set_prop, prop}}
          end

        {:error, _} = otherwise ->
          otherwise

        nil ->
          {:error, Scanner.error(source, "Expected 'to' after 'set'")}
      end
    end
  end

  # this is an event invocation
  # [ exp <- nc_name ]
  # [ <- nc_name ]
  # [ exp <- nc_name as role with arg list ]
  # [ <- nc_name as role with arg list ]
  #

  defp parse_event_invocation(source) do
    item =
      if Scanner.scan(source, ~r{\s*<-}) do
        {:ok, {:context, "this"}}
      else
        parse_expression(source, ~r{\s*<-})
      end

    as =
      if Scanner.scan(source |> skip_space, ~r/as\b/) do
        source |> skip_space |> parse_pov
      else
        {:ok, "any"}
      end

    with {:ok, item} <- item,
         {:ok, event} <- parse_nc_name(source),
         {:ok, pov} <- parse_pov(source) do
      skip_all_space(source)

      if Scanner.scan(source, ~r/with\b/) do
        skip_all_space(source)

        case parse_named_args(source, ~r/\]/) do
          {args, _errors} ->
            {:ok, {:event, item, event, pov, args}}

          _ ->
            {:error, Scanner.error(source, "Expected argument list for event", ~r/\]/)}
        end
      else
        skip_all_space(source)

        cond do
          Scanner.eos?(source) ->
            {:error, Scanner.error(source, "Unterminated event invocation")}

          Scanner.scan(source, ~r/]/) ->
            skip_all_space(source)

            {:ok, {:event, item, event, pov, []}}

          true ->
            {:error, Scanner.error(source, "Expected \"]\" to terminate an event invocation")}
        end
      end
    else
      {:error, _} = otherwise -> otherwise
    end
  end

  defp parse_reset(source, _type) do
    skip_all_space(source)

    if Scanner.match?(source, ~r/\$/) do
      case parse_var_name(source) do
        {:ok, var} ->
          {:ok, {:reset_var, var}}

        {:error, _} = otherwise ->
          otherwise
      end
    else
      case parse_nc_name(source) do
        {:ok, prop} ->
          {:ok, {:reset_prop, prop}}

        {:error, _} = otherwise ->
          otherwise
      end
    end
  end

  defp parse_sensation(source, sense, r) do
    sense =
      if sense == "" do
        "sight"
      else
        sense
      end

    case parse_quoted_string(source, r) do
      {:ok, {:string, content}} ->
        {:ok, {:sensation, sense, content}}

      {:error, _} = otherwise ->
        otherwise
    end
  end

  @spec parse_dictionary_entry(PID, List, List, Regex.t()) :: List
  defp parse_dictionary_entry(source, dict \\ [], errors \\ [], ending \\ ~r/\}\)/) do
    skip_all_space(source)

    cond do
      Scanner.eos?(source) ->
        {dict,
         [Scanner.error(source, "End of file unexpected in dictionary definition") | errors]}

      Scanner.scan(source, ending) ->
        {dict, errors}

      true ->
        case parse_quoted_string_or_nc_name(source) do
          {:error, message} ->
            Scanner.scan_until(source, ~r/[,\n]/)
            parse_dictionary_entry(source, dict, [message | errors], ending)

          nil ->
            parse_dictionary_entry(
              source,
              dict,
              [
                Scanner.error(source, "Expected a key name", ~r/[,\n]/)
                | errors
              ],
              ending
            )

          {:ok, {:string, key}} ->
            skip_all_space(source)

            if Scanner.scan(source, ~r/:/) do
              skip_all_space(source)

              case parse_expression(source, ~r/,|#{Regex.source(ending)}/) do
                {:error, message} ->
                  parse_dictionary_entry(source, dict, [message | errors], ending)

                nil ->
                  parse_dictionary_entry(
                    source,
                    dict,
                    [
                      Scanner.error(source, "Expected an expression")
                      | errors
                    ],
                    ending
                  )

                value ->
                  parse_dictionary_entry(source, [{key, value} | dict], errors, ending)
              end
            else
              parse_dictionary_entry(
                source,
                dict,
                [
                  Scanner.error(
                    source,
                    "Expected a \":\" separating the key from the value",
                    ~r/[,\n]/
                  )
                  | errors
                ],
                ending
              )
            end

          {:ok, key} ->
            skip_all_space(source)

            if Scanner.scan(source, ~r/:/) do
              skip_all_space(source)

              case parse_expression(source, ~r/,|#{Regex.source(ending)}/) do
                {:error, message} ->
                  parse_dictionary_entry(source, dict, [message | errors], ending)

                nil ->
                  parse_dictionary_entry(
                    source,
                    dict,
                    [
                      Scanner.error(source, "Expected an expression")
                      | errors
                    ],
                    ending
                  )

                {:ok, value} ->
                  parse_dictionary_entry(source, [{key, value} | dict], errors, ending)
              end
            else
              parse_dictionary_entry(
                source,
                dict,
                [
                  Scanner.error(
                    source,
                    "Expected a \":\" separating the key from the value",
                    ~r/[,\n]/
                  )
                  | errors
                ],
                ending
              )
            end
        end
    end
  end

  @spec parse_named_args(PID, Regex.t(), List, List) :: List
  defp parse_named_args(source, ending \\ ~r/\]/, dict \\ [], errors \\ []) do
    skip_all_space(source)

    cond do
      Scanner.eos?(source) ->
        {dict, [Scanner.error(source, "End of file unexpected in named argument list") | errors]}

      Scanner.scan(source, ending) ->
        {dict, errors}

      true ->
        case parse_named_argument_name(source) do
          {:error, message} ->
            Scanner.scan_until(source, ~r/[,\n]/)
            parse_named_args(source, ending, dict, [message | errors])

          nil ->
            parse_named_args(
              source,
              ending,
              dict,
              [
                Scanner.error(source, "Expected a key name", ~r/[,\n]/)
                | errors
              ]
            )

          {:ok, key} ->
            skip_all_space(source)

            if Scanner.scan(source, ~r/:/) do
              skip_all_space(source)

              case parse_expression(source, ~r/,/) do
                {:error, message} ->
                  parse_named_args(source, ending, dict, [message | errors])

                nil ->
                  parse_named_args(
                    source,
                    ending,
                    dict,
                    [
                      Scanner.error(source, "Expected an expression")
                      | errors
                    ]
                  )

                {:ok, value} ->
                  parse_named_args(source, ending, [{key, value} | dict], errors)
              end
            else
              parse_named_args(
                source,
                ending,
                dict,
                [
                  Scanner.error(
                    source,
                    "Expected a \":\" separating the key from the value",
                    ~r/[,\n]/
                  )
                  | errors
                ]
              )
            end
        end
    end
  end

  defp parse_list(source, items \\ [], ending \\ ~r/\]\)/) do
    skip_all_space(source)

    cond do
      Scanner.eos?(source) ->
        {:error, Scanner.error(source, "End of file unexpected in list")}

      Scanner.scan(source, ending) ->
        {:ok, Enum.reverse(items)}

      true ->
        skip_all_space(source)

        case parse_expression(source, ~r/,|#{Regex.source(ending)}/) do
          {:ok, value} ->
            case Scanner.matches(source) do
              [sep | _] ->
                if sep == "," do
                  parse_list(source, [value | items], ending)
                else
                  {:ok, Enum.reverse([value | items])}
                end

              _ ->
                {:error, Scanner.error(source, "Expecting a comma or #{Regex.source(ending)}")}
            end

          {:error, _} = otherwise ->
            otherwise
        end
    end
  end

  defp parse_arg_list(source, sep \\ ~r/\)/), do: parse_list(source, [], sep)

  defp parse_quoted_string_or_nc_name(source) do
    case parse_quoted_string(source) do
      {:ok, key} -> {:ok, key}
      _ -> parse_nc_name(source)
    end
  end

  defp parse_quoted_string(source) do
    if Scanner.scan(source, ~r/["']/) do
      [q | _] = Scanner.matches(source)
      parse_quoted_string(source, q)
    else
      {:error, Scanner.error(source, "Expected a ' or \" to start a quoted string")}
    end
  end

  def parse_quoted_string(source, q) do
    with quotedr <- Regex.escape(q),
         {:ok, regex} <- Regex.compile("([^\\#{quotedr}]|\\.)*"),
         {:ok, qr} <- Regex.compile(quotedr) do
      if Scanner.scan(source, regex) do
        [content | _] = Scanner.matches(source)

        if Scanner.eos?(source) || !Scanner.scan(source, qr) do
          {:error, Scanner.error(source, "End of file unexpected in quoted string")}
        else
          {:ok, {:string, unescape_string(content)}}
        end
      else
        {:ok, {:string, ""}}
      end
    end
  end

  defp unescape_string(string, acc \\ "")
  defp unescape_string("", acc), do: acc
  defp unescape_string(<<"\\n", rest::binary>>, acc), do: unescape_string(rest, acc <> "\n")
  defp unescape_string(<<"\\r", rest::binary>>, acc), do: unescape_string(rest, acc <> "\r")
  defp unescape_string(<<"\\e", rest::binary>>, acc), do: unescape_string(rest, acc <> "\e")
  defp unescape_string(<<"\\f", rest::binary>>, acc), do: unescape_string(rest, acc <> "\f")
  defp unescape_string(<<"\\t", rest::binary>>, acc), do: unescape_string(rest, acc <> "\t")

  defp unescape_string(<<"\\", x::utf8, rest::binary>>, acc),
    do: unescape_string(rest, acc <> <<x>>)

  defp unescape_string(<<x::utf8, rest::binary>>, acc), do: unescape_string(rest, acc <> <<x>>)
end
