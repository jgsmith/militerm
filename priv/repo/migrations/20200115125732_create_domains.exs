defmodule Militerm.Repo.Migrations.CreateDomains do
  use Ecto.Migration

  def change do
    create table(:core_domains) do
      add :name, :string
      add :plug, :string
      add :description, :text

      timestamps()
    end

    create unique_index(:core_domains, [:plug])
  end
end
