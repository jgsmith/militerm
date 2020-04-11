defmodule Militerm.Accounts.Character do
  use Ecto.Schema
  import Ecto.Changeset

  alias Militerm.Accounts.{Group, GroupMembership, User}

  schema "characters" do
    field :cap_name, :string
    field :name, :string
    # field :user_id, :id
    field :gender, :string, virtual: true
    field :entity_id, :string
    belongs_to :user, User

    many_to_many :groups, Group,
      join_through: GroupMembership,
      join_keys: [user_id: :user_id, group_id: :id],
      unique: true

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
