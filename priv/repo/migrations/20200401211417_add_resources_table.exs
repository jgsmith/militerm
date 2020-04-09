defmodule Militerm.Repo.Migrations.AddResourcesTable do
  use Ecto.Migration

  def change do
    create table(:resources) do
      add :entity_id, :string
      add :data, :map

      timestamps()
    end

    create unique_index(:resources, [:entity_id])
  end
end
