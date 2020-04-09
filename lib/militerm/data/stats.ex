defmodule Militerm.Data.Stats do
  use Ecto.Schema
  import Ecto.Changeset

  schema "stats" do
    field :entity_id, :string
    field :data, :map

    timestamps()
  end

  @doc false
  def changeset(traits, attrs) do
    traits
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
