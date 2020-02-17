defmodule Militerm.Data.Location do
  use Ecto.Schema
  import Ecto.Changeset

  schema "locations" do
    field :detail, :string
    field :entity_id, :string
    field :point, {:array, :integer}
    field :relationship, :string
    field :position, :string
    field :t, :integer
    field :target_id, :string
    field :hibernated, :boolean, default: false

    timestamps()
  end

  @doc false
  def changeset(location, attrs) do
    location
    |> cast(attrs, [
      :entity_id,
      :target_id,
      :t,
      :detail,
      :relationship,
      :position,
      :point,
      :hibernated
    ])
    |> validate_required([:entity_id, :target_id])
    |> unique_constraint(:entity_id)
  end
end
