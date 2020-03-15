defmodule Militerm.Repo.Migrations.CreateLocations do
  use Ecto.Migration

  def change do
    create table(:locations) do
      add :entity_id, :string
      add :target_id, :string
      add :t, :integer
      add :detail, :string
      add :relationship, :string
      add :position, :string
      add :point, {:array, :integer}
      add :hibernated, :boolean, null: false, default: false

      timestamps()
    end

    create unique_index(:locations, [:entity_id])
    create index(:locations, [:target_id])
  end
end
