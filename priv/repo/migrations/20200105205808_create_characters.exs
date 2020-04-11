defmodule Militerm.Repo.Migrations.CreateCharacters do
  use Ecto.Migration

  def change do
    create table(:characters) do
      add :name, :string
      add :cap_name, :string
      add :user_id, references(:users, on_delete: :nothing)
      add :entity_id, :string

      timestamps()
    end

    create unique_index(:characters, [:entity_id])
    create unique_index(:characters, [:name])
    create unique_index(:characters, [:cap_name])
    create index(:characters, [:user_id])
  end
end
