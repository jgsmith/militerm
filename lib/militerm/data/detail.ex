defmodule Militerm.Data.Detail do
  use Ecto.Schema
  import Ecto.Changeset

  schema "details" do
    field :entity_id, :string
    field :data, :map

    timestamps()
  end

  @doc false
  def changeset(detail, attrs) do
    detail
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
