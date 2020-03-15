defmodule Militerm.Repo.Migrations.CreateScenes do
  use Ecto.Migration

  def change do
    create table(:core_scenes) do
      add :archetype, :string, null: false
      add :description, :text
      add :plug, :string, null: false
      add :area_id, references(:core_areas, on_delete: :nothing), null: false

      timestamps()
    end

    create unique_index(:core_scenes, [:area_id, :plug])
    create index(:core_scenes, [:area_id])
  end
end
