defmodule Militerm.Game.Area do
  use Ecto.Schema
  import Ecto.Changeset

  alias Militerm.Game.{Domain, Scene}

  schema "core_areas" do
    field :description, :string
    field :name, :string
    field :plug, :string
    belongs_to :domain, Domain
    has_many :scenes, Scene

    timestamps()
  end

  @doc false
  def changeset(area, attrs) do
    area
    |> cast(attrs, [:name, :description])
    |> update_plug()
    |> validate_required([:name, :plug, :description])

    # |> unique_constraint(:name)
    # TODO: unique_constraint - core_areas_domain_id_name_index
  end

  def update_plug(%{changes: %{name: nil}} = changeset), do: changeset

  def update_plug(%{changes: %{name: name}} = changeset) do
    plug =
      name
      |> String.downcase()
      |> String.replace(~r{[^-a-z_0-9]+}, "-")
      |> String.replace(~r{-+}, "-")
      |> String.replace(~r{_+}, "_")

    changeset
    |> put_change(:plug, plug)
  end

  def update_plug(changeset), do: changeset
end
