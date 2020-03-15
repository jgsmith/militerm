defmodule Militerm.Data.Flags do
  use Ecto.Schema
  import Ecto.Changeset

  schema "flags" do
    field :entity_id, :string
    field :flags, {:array, :string}

    timestamps()
  end

  @doc false
  def changeset(flags, attrs) do
    flags
    |> cast(attrs, [
      :entity_id,
      :flags
    ])
    |> validate_required([
      :entity_id
    ])
    |> unique_constraint(:entity_id)
  end
end
