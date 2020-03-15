defmodule Militerm.Game.Scene do
  use Ecto.Schema
  import Ecto.Changeset

  alias Militerm.Game.Area

  schema "core_scenes" do
    field :archetype, :string
    field :plug, :string
    field :description, :string
    belongs_to :area, Area

    timestamps()
  end

  @doc false
  def changeset(scene, attrs) do
    scene
    |> cast(attrs, [:archetype, :plug, :description])
    |> validate_required([:archetype, :plug, :area_id])

    # |> unique_constraint(:plug)
  end
end
