defmodule Militerm.Systems.Identity do
  @moduledoc """
  The identity system manages matching entities and details with descriptions to support
  parsing.
  """
  use Militerm.ECS.System

  alias Militerm.{Components, English}
  alias Militerm.Systems.Identity

  defscript parse_match_q(string, nouns, adjectives), for: %{"this" => this} do
    bits =
      string
      |> English.remove_article()
      |> String.downcase()
      |> String.split(~r{\s+})

    plural_nouns = Enum.map(nouns, &English.pluralize/1)
    plural_adjs = Enum.map(adjectives, &English.pluralize/1)

    [noun | adj] = Enum.reverse(bits)

    all_nouns = Enum.uniq(nouns ++ plural_nouns)
    all_adjs = Enum.uniq(adjectives ++ plural_adjs)

    (noun in all_nouns) and
      Enum.all?(adj, fn word -> word in all_adjs end)
  end

  @doc """
  Returns `true` if the entity matches the words. The words already
  have articles, ordinals, cardinals, etc., removed.

  ## Examples

    iex> Components.Details.set("item", "default", %{nouns: ["coin"], adjectives: ["gold"]})
    ...>{ Identity.parse_match?({:thing, "item"}, ["coins"]),
    ...>  Identity.parse_match?({:thing, "item"}, ["gold"]),
    ...>  Identity.parse_match?({:thing, "item"}, ["gold", "coin"])}
    {true, false, true}
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

    (noun in names or noun in all_nouns) and
      Enum.all?(adj, fn word -> word in all_adjectives end)
  end

  def parse_match?({:thing, entity_id}, words),
    do: parse_match?({:thing, entity_id, "default"}, words)

  defp match_nouns(%{"nouns" => nouns, "plural_nouns" => [_ | _] = plurals})
       when is_list(nouns) do
    Enum.uniq(nouns ++ plurals)
  end

  defp match_nouns(%{"nouns" => nouns}) when is_list(nouns) do
    Enum.uniq(nouns ++ English.pluralize(nouns))
  end

  defp match_nouns(_), do: []

  defp match_adjectives(%{"adjectives" => adjectives, "plural_adjectives" => [_ | _] = plurals}) do
    Enum.uniq(adjectives ++ plurals)
  end

  defp match_adjectives(%{"adjectives" => adjectives}) when is_list(adjectives), do: adjectives

  defp match_adjectives(_), do: []
end
