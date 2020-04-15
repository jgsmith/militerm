defmodule Militerm.Data.Aliases do
  use Ecto.Schema
  import Ecto.Changeset

  schema "aliases" do
    field :entity_id, :string
    field :data, :map

    timestamps()
  end

  @doc false
  def changeset(aliases, attrs) do
    aliases
    |> cast(attrs, [
      :entity_id,
      :data
    ])
    |> validate_required([
      :entity_id
    ])
    |> unique_constraint(:entity_id)
  end
end
