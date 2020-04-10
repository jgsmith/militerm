defmodule Militerm.Data.SimpleResponses do
  use Ecto.Schema
  import Ecto.Changeset

  schema "simple_responses" do
    field :entity_id, :string
    field :data, :map

    timestamps()
  end

  @doc false
  def changeset(record, attrs) do
    record
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
