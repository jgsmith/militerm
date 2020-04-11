defmodule Militerm.Accounts.GroupMembership do
  use Ecto.Schema
  import Ecto.Changeset

  alias Militerm.Accounts.{Group, User}

  schema "group_memberships" do
    belongs_to :group, Group
    belongs_to :user, User
    timestamps()
  end

  @doc false
  def changeset(group, attrs) do
    group
    |> cast(attrs, [:group_id, :user_id])
    |> validate_required([:group_id])
    |> validate_required([:user_id])
  end
end
