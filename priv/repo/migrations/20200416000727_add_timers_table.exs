defmodule Militerm.Repo.Migrations.AddTimersTable do
  use Ecto.Migration

  def change do
    create table(:timers) do
      add :entity_id, :string
      add :data, :map

      timestamps()
    end

    create unique_index(:timers, [:entity_id])
  end
end
