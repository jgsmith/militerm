defmodule Militerm.Accounts.Character do
  use Ecto.Schema
  import Ecto.Changeset

  schema "characters" do
    field :cap_name, :string
    field :name, :string
    field :user_id, :id
    field :gender, :string
    field :entity_id, :string

    timestamps()
  end

  @doc false
  def changeset(character, attrs) do
    character
    |> cast(attrs, [:name, :cap_name, :gender, :entity_id, :user_id])
    |> validate_required([:name, :cap_name, :gender, :entity_id, :user_id])
    |> unique_constraint(:name)
    |> unique_constraint(:cap_name)
    |> unique_constraint(:entity_id)
  end
end
