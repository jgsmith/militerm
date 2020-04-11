defmodule Militerm.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias Militerm.Accounts.{Character, Group, GroupMembership}

  schema "users" do
    field :email, :string
    field :uid, :string
    field :name, :string
    field :is_admin, :boolean
    has_many :characters, Character
    many_to_many :groups, Group, join_through: GroupMembership, unique: true

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:uid, :name, :email, :is_admin])
    |> validate_required([:uid, :name, :email])
    |> unique_constraint(:uid)
    |> unique_constraint(:email)
  end
end
