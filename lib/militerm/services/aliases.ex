defmodule Militerm.Services.Aliases do
  def expand({:thing, entity_id}, input) do
    [bit | bits] =
      if String.first(input) in ~w{' " : ]} do
        <<initial::binary-1, rest::binary>> = input
        [initial | String.split(rest, ~r{\s+}, trim: true)]
      else
        String.split(input, ~r{\s+}, trim: true)
      end

    aliases = Militerm.Components.Aliases.get(entity_id)

    case Map.get(aliases, bit) do
      nil ->
        input

      expansion ->
        expansion
        |> String.replace(~r{\$(\*|\d+)}, fn
          "$*" ->
            Enum.join(bits, " ")

          <<"$", index>> ->
            i = String.to_integer(index)
            Enum.at(bits, i, "")
        end)
        |> String.replace(~r{\s+}, " ")
        |> String.trim()
    end
  end
end
