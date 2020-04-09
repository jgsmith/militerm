defmodule Militerm.Repo.Migrations.AddCountersTable do
  use Ecto.Migration

  def change do
    create table(:counters) do
      add :entity_id, :string
      add :data, :map

      timestamps()
    end

    create unique_index(:counters, [:entity_id])
  end
end
