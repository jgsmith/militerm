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
    %{id: user_id} = current_user(conn)
    characters = Accounts.list_characters(user_id: user_id)
    render(conn, "index.html", characters: characters)
  end

  def play(conn, %{"character" => character}) do
    render(conn, "play.html", character: character, current_user: current_user(conn))
  end

  def new(conn, _params) do
    %{id: user_id} = current_user(conn)
    changeset = Accounts.change_character(%Character{user_id: user_id})
    render(conn, "new.html", changeset: changeset, genders: @genders)
  end

  def create(conn, %{"character" => %{"cap_name" => cap_name} = character_params}) do
    %{id: user_id} = current_user(conn)

    params =
      character_params
      |> Map.put("name", name_from_cap(cap_name))
      |> Map.put("user_id", user_id)

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
    %{id: user_id} = current_user(conn)
    character = Accounts.get_character!(name: id, user_id: user_id)
    render(conn, "show.html", character: character)
  end

  defp name_from_cap(nil), do: nil

  defp name_from_cap(cap_name) do
    cap_name |> String.trim() |> String.downcase() |> String.replace(~r{[^-a-z]}, "")
  end
end
