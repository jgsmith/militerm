defmodule Militerm.Repo.Migrations.AddTraitsTable do
  use Ecto.Migration

  def change do
    create table(:traits) do
      add :entity_id, :string
      add :data, :map

      timestamps()
    end

    create unique_index(:traits, [:entity_id])
  end
end
