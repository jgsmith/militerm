defmodule MilitermWeb.CharacterControllerTest do
  use MilitermWeb.ConnCase

  alias Militerm.Accounts

  @create_attrs %{cap_name: "SomeCap-Name", gender: "male"}
  @update_attrs %{cap_name: "SomeUpdatedCap-Name", gender: "female"}
  @invalid_attrs %{cap_name: "some-cap--name", gender: nil}

  @create_user_attrs %{
    email: "example@example.com",
    uid: "example@example.com",
    username: "example"
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
      fixture(:user)
      conn = get(conn, Routes.character_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Characters"
    end
  end

  describe "new character" do
    test "renders form", %{conn: conn} do
      fixture(:user)
      conn = get(conn, Routes.character_path(conn, :new))
      assert html_response(conn, 200) =~ "New Character"
    end
  end

  describe "create character" do
    test "redirects to show when data is valid", %{conn: conn} do
      fixture(:user)
      conn = post(conn, Routes.character_path(conn, :create), character: @create_attrs)

      assert %{id: "somecap-name"} = redirected_params(conn)
      assert redirected_to(conn) == Routes.character_path(conn, :show, "somecap-name")

      conn = get(conn, Routes.character_path(conn, :show, "somecap-name"))
      assert html_response(conn, 200) =~ "Show Character"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      fixture(:user)
      conn = post(conn, Routes.character_path(conn, :create), character: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Character"
    end
  end

  # describe "edit character" do
  #   setup [:create_character]
  #
  #   test "renders form for editing chosen character", %{conn: conn, character: character} do
  #     conn = get(conn, Routes.character_path(conn, :edit, character))
  #     assert html_response(conn, 200) =~ "Edit Character"
  #   end
  # end
  #
  # describe "update character" do
  #   setup [:create_character]
  #
  #   test "redirects when data is valid", %{conn: conn, character: character} do
  #     conn = put(conn, Routes.character_path(conn, :update, character), character: @update_attrs)
  #     assert redirected_to(conn) == Routes.character_path(conn, :show, character)
  #
  #     conn = get(conn, Routes.character_path(conn, :show, character))
  #     assert html_response(conn, 200) =~ "some updated cap_name"
  #   end
  #
  #   test "renders errors when data is invalid", %{conn: conn, character: character} do
  #     conn = put(conn, Routes.character_path(conn, :update, character), character: @invalid_attrs)
  #     assert html_response(conn, 200) =~ "Edit Character"
  #   end
  # end
  #
  # describe "delete character" do
  #   setup [:create_character]
  #
  #   test "deletes chosen character", %{conn: conn, character: character} do
  #     conn = delete(conn, Routes.character_path(conn, :delete, character))
  #     assert redirected_to(conn) == Routes.character_path(conn, :index)
  #     assert_error_sent 404, fn ->
  #       get(conn, Routes.character_path(conn, :show, character))
  #     end
  #   end
  # end

  defp create_character(_) do
    character = fixture(:character)
    {:ok, character: character}
  end
end
