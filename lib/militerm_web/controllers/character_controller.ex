defmodule MilitermWeb.CharacterController do
  use MilitermWeb, :controller

  alias Militerm.Accounts
  alias Militerm.Accounts.Character

  @genders [
    {"They/Them/Their", "none"},
    {"He/Him/His", "male"},
    {"She/Her/Her", "female"},
    {"Hi/Hir/Hir", "neuter"}
  ]

  def index(conn, _params) do
    characters = Accounts.list_characters(user_id: 1)
    render(conn, "index.html", characters: characters)
  end

  def new(conn, _params) do
    [user | _] = Accounts.list_users()
    changeset = Accounts.change_character(%Character{user_id: user.id})
    render(conn, "new.html", changeset: changeset, genders: @genders)
  end

  def create(conn, %{"character" => %{"cap_name" => cap_name} = character_params}) do
    [user | _] = Accounts.list_users()

    params =
      character_params
      |> Map.put("name", name_from_cap(cap_name))
      |> Map.put("user_id", user.id)

    case Accounts.create_character(params) do
      {:ok, character} ->
        conn
        |> put_flash(:info, "Character created successfully.")
        |> redirect(to: Routes.character_path(conn, :show, character.name))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset, genders: @genders)
    end
  end

  def show(conn, %{"id" => id}) do
    character = Accounts.get_character!(name: id)
    render(conn, "show.html", character: character)
  end

  defp name_from_cap(nil), do: nil

  defp name_from_cap(cap_name) do
    cap_name |> String.trim() |> String.downcase() |> String.replace(~r{[^-a-z]}, "")
  end
end
