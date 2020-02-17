defmodule Militerm.Data.Identity do
  use Ecto.Schema
  import Ecto.Changeset

  schema "identities" do
    field :entity_id, :binary
    field :data, :map

    timestamps()
  end

  @doc false
  def changeset(identity, attrs) do
    identity
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
