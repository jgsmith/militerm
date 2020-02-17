defmodule Militerm.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :uid, :string
      add :username, :string
      add :email, :string

      timestamps()
    end

    create unique_index(:users, [:uid])
    create unique_index(:users, [:username])
    create unique_index(:users, [:email])
  end
end
