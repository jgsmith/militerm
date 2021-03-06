defmodule Militerm.Command.Plugs.Parse do
  def run(%{parse: parse, parser: parser}, _) when not is_nil(parser) and not is_nil(parse),
    do: :cont

  def run(%{input: <<"@", _::binary>>}, _), do: :cont

  def run(%{context: context, input: input} = info, opts) do
    parser = Keyword.fetch!(opts, :parser)
    fetcher = Keyword.fetch!(opts, :service)

    case parser.parse(input, context, fetcher) do
      %{} = parse ->
        {:cont, info |> Map.put(:parse, parse) |> Map.put(:parser, parser)}

      _ ->
        {:cont, info |> Map.put(:error, "I can't #{input}.")}
    end
  end

  def run(_, _), do: :cont
end
