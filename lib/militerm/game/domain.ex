defmodule Militerm.Game.Domain do
  use Ecto.Schema
  import Ecto.Changeset

  alias Militerm.Game.Area

  schema "core_domains" do
    field :description, :string
    field :name, :string
    field :plug, :string
    has_many :areas, Area

    timestamps()
  end

  @doc false
  def changeset(domain, attrs) do
    domain
    |> cast(attrs, [:name, :description])
    |> update_plug()
    |> validate_required([:name, :plug, :description])
    |> unique_constraint(:plug)
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
