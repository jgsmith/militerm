defmodule Militerm.Repo.Migrations.CreateDetails do
  use Ecto.Migration

  def change do
    create table(:details) do
      add :entity_id, :string
      add :data, :map

      timestamps()
    end

    create unique_index(:details, [:entity_id])
  end
end
