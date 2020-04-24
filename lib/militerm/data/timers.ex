defmodule Militerm.Data.Timers do
  use Ecto.Schema
  import Ecto.Changeset

  schema "timers" do
    field :entity_id, :string
    field :data, :map

    timestamps()
  end

  @doc false
  def changeset(timers, attrs) do
    timers
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
