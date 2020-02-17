defmodule Militerm.Repo.Migrations.CreateAreas do
  use Ecto.Migration

  def change do
    create table(:core_areas) do
      add :name, :string
      add :plug, :string
      add :description, :text
      add :domain_id, references(:core_domains, on_delete: :nothing)

      timestamps()
    end

    create index(:core_areas, [:domain_id])
    create unique_index(:core_areas, [:domain_id, :plug])
  end
end
