defmodule Militerm.Repo.Migrations.AddFlagsTable do
  use Ecto.Migration

  def change do
    create table(:flags) do
      add :entity_id, :string
      add :flags, {:array, :string}

      timestamps()
    end

    create unique_index(:flags, [:entity_id])
  end
end
