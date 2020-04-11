defmodule Militerm.Repo.Migrations.AddGroupsTable do
  use Ecto.Migration

  def change do
    create table(:groups) do
      add :name, :string
      add :description, :text

      timestamps()
    end

    create table(:group_memberships) do
      add :user_id, references(:users, on_delete: :nothing)
      add :group_id, references(:groups, on_delete: :nothing)

      timestamps()
    end

    create unique_index(:groups, [:name])
    create unique_index(:group_memberships, [:user_id, :group_id])
    create index(:group_memberships, [:group_id])
  end
end
