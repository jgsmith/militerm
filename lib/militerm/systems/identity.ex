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

    all_nouns =
      case info do
        %{"nouns" => nouns, "plural_nouns" => [_ | _] = plurals} ->
          Enum.uniq(nouns ++ plurals)

        %{"nouns" => nouns} ->
          Enum.uniq(nouns ++ English.pluralize(nouns))

        _ ->
          []
      end

    names =
      case info do
        %{"name" => nom} -> [nom]
        _ -> []
      end

    all_adjectives =
      case info do
        %{"adjectives" => adjectives, "plural_adjectives" => [_ | _] = plurals} ->
          Enum.uniq(adjectives ++ plurals)

        %{"adjectives" => adjectives} ->
          Enum.uniq(adjectives ++ English.pluralize(adjectives))

        _ ->
          []
      end

    [noun | adj] = Enum.reverse(words)

    (noun in names or noun in all_nouns or noun in all_adjectives) and
      Enum.all?(adj, fn word -> word in all_adjectives end)
  end

  def parse_match?({:thing, entity_id}, words),
    do: parse_match?({:thing, entity_id, "default"}, words)
end
