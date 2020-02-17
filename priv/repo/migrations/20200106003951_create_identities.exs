defmodule Militerm.Repo.Migrations.CreateIdentities do
  use Ecto.Migration

  def change do
    create table(:identities) do
      add :entity_id, :string
      add :data, :map

      timestamps()
    end

    create unique_index(:identities, [:entity_id])
  end
end
