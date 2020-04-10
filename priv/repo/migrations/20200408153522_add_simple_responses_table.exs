defmodule Militerm.Repo.Migrations.AddSimpleResponsesTable do
  use Ecto.Migration

  def change do
    create table(:simple_responses) do
      add :entity_id, :string
      add :data, :map

      timestamps()
    end

    create unique_index(:simple_responses, [:entity_id])
  end
end
