defmodule Militerm.Repo.Migrations.CreateEntities do
  use Ecto.Migration

  def change do
    create table(:entities) do
      add :entity_id, :string
      add :data, :map

      timestamps()
    end

    create unique_index(:entities, [:entity_id])
  end
end
