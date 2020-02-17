defmodule Militerm.Data.Entity do
  use Ecto.Schema
  import Ecto.Changeset

  schema "entities" do
    field :entity_id, :binary
    field :data, :map

    timestamps()
  end

  @doc false
  def changeset(entity, attrs) do
    entity
    |> cast(attrs, [:entity_id, :data])
    |> validate_required([:entity_id])
    |> unique_constraint(:entity_id)
  end
end
