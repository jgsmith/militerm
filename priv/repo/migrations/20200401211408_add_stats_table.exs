defmodule Militerm.Repo.Migrations.AddStatsTable do
  use Ecto.Migration

  def change do
    create table(:stats) do
      add :entity_id, :string
      add :data, :map

      timestamps()
    end

    create unique_index(:stats, [:entity_id])
  end
end
