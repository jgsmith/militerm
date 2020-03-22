defmodule Militerm.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :uid, :string
      add :name, :string
      add :email, :string
      add :is_admin, :boolean

      timestamps()
    end

    create unique_index(:users, [:uid])
    create unique_index(:users, [:email])
  end
end
