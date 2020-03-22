defmodule MilitermWeb.CharacterControllerTest do
  use MilitermWeb.ConnCase

  alias Militerm.Accounts

  @create_attrs %{cap_name: "SomeCap-Name", gender: "male"}
  @update_attrs %{cap_name: "SomeUpdatedCap-Name", gender: "female"}
  @invalid_attrs %{cap_name: "some-cap--name", gender: nil}

  @create_user_attrs %{
    email: "example@example.com",
    uid: "example@example.com",
    name: "example"
  }

  def fixture(:character) do
    {:ok, character} = Accounts.create_character(@create_attrs)
    character
  end

  def fixture(:user) do
    {:ok, user} = Accounts.create_user(@create_user_attrs)
    user
  end

  describe "index" do
    test "lists all characters", %{conn: conn} do
      user = fixture(:user)

      conn =
        conn
        |> authenticate(user)
        |> get(Routes.character_path(conn, :index))

      assert html_response(conn, 200) =~ "Listing Characters"
    end
  end

  describe "new character" do
    test "renders form", %{conn: conn} do
      user = fixture(:user)

      conn =
        conn
        |> authenticate(user)
        |> get(Routes.character_path(conn, :new))

      assert html_response(conn, 200) =~ "New Character"
    end
  end

  describe "create character" do
    test "redirects to show when data is valid", %{conn: conn} do
      user = fixture(:user)

      conn =
        conn
        |> authenticate(user)
        |> post(Routes.character_path(conn, :create), character: @create_attrs)

      assert %{id: "somecap-name"} = redirected_params(conn)
      assert redirected_to(conn) == Routes.character_path(conn, :show, "somecap-name")

      conn =
        conn
        |> recycle()
        |> authenticate(user)
        |> get(Routes.character_path(conn, :show, "somecap-name"))

      assert html_response(conn, 200) =~ "Show Character"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      user = fixture(:user)

      conn =
        conn
        |> authenticate(user)
        |> post(Routes.character_path(conn, :create), character: @invalid_attrs)

      assert html_response(conn, 200) =~ "New Character"
    end
  end

  defp create_character(_) do
    character = fixture(:character)
    {:ok, character: character}
  end

  defp authenticate(conn, %{} = user) do
    conn
    |> MilitermWeb.UserAuth.Guardian.Plug.sign_in(user)
  end
end
