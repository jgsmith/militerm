defmodule Militerm.Repo.Migrations.AddAliasesTable do
  use Ecto.Migration

  def change do
    create table(:aliases) do
      add :entity_id, :string
      add :data, :map

      timestamps()
    end

    create unique_index(:aliases, [:entity_id])
  end
end
