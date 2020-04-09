defmodule Militerm.Repo.Migrations.AddSkillsTable do
  use Ecto.Migration

  def change do
    create table(:skills) do
      add :entity_id, :string
      add :data, :map

      timestamps()
    end

    create unique_index(:skills, [:entity_id])
  end
end
