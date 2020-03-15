defmodule Militerm.Repo.Migrations.AddThingsTable do
  use Ecto.Migration

  def change do
    create table(:things) do
      add :entity_id, :string
      add :data, :map

      timestamps()
    end

    create unique_index(:things, [:entity_id])
  end
end
