defmodule Militerm.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias Militerm.Accounts.Character

  schema "users" do
    field :email, :string
    # TODO: modify as needed for grapevine auth
    field :uid, :string
    field :username, :string
    has_many :characters, Character

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:uid, :username, :email])
    |> validate_required([:uid, :username, :email])
    |> unique_constraint(:uid)
    |> unique_constraint(:username)
    |> unique_constraint(:email)
  end
end
