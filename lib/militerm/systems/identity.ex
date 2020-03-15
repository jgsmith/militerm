defmodule Militerm.Systems.Identity do
  @moduledoc """
  The identity system manages matching entities and details with descriptions to support
  parsing.
  """

  alias Militerm.{Components, English}
  alias Militerm.Systems.Identity

  @doc """
  Returns `true` if the entity matches the words. The words already
  have articles, ordinals, cardinals, etc., removed.

  ## Examples

    iex> Components.Details.set("item", "default", %{nouns: ["coin"], adjectives: ["gold"]})
    ...>{ Identity.parse_match?({:thing, "item"}, ["coins"]),
    ...>  Identity.parse_match?({:thing, "item"}, ["gold"]),
    ...>  Identity.parse_match?({:thing, "item"}, ["gold", "coin"])}
    {true, true, true}
  """
  def parse_match?({:thing, entity_id, detail}, words) when is_binary(detail) do
    info = Components.Details.get(entity_id, detail)

    all_nouns = match_nouns(info)

    names =
      case info do
        %{"name" => nom} -> [nom]
        _ -> []
      end

    all_adjectives = match_adjectives(info)

    [noun | adj] = Enum.reverse(words)

    (noun in names or noun in all_nouns or noun in all_adjectives) and
      Enum.all?(adj, fn word -> word in all_adjectives end)
  end

  def parse_match?({:thing, entity_id}, words),
    do: parse_match?({:thing, entity_id, "default"}, words)

  defp match_nouns(%{"nouns" => nouns, "plural_nouns" => [_ | _] = plurals}) do
    Enum.uniq(nouns ++ plurals)
  end

  defp match_nouns(%{"nouns" => nouns}) do
    Enum.uniq(nouns ++ English.pluralize(nouns))
  end

  defp match_nouns(_), do: []

  defp match_adjectives(%{"adjectives" => adjectives, "plural_adjectives" => [_ | _] = plurals}) do
    Enum.uniq(adjectives ++ plurals)
  end

  defp match_adjectives(%{"adjectives" => adjectives}), do: adjectives

  defp match_adjectives(_), do: []
end
