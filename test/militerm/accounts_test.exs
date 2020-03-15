defmodule Militerm.AccountsTest do
  use Militerm.DataCase, async: false

  alias Militerm.Accounts

  describe "users" do
    alias Militerm.Accounts.User

    @valid_attrs %{email: "some email", uid: "some uid", username: "some username"}
    @update_attrs %{
      email: "some updated email",
      uid: "some updated uid",
      username: "some updated username"
    }
    @invalid_attrs %{email: nil, uid: nil, username: nil}

    def user_fixture(attrs \\ %{}) do
      {:ok, user} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Accounts.create_user()

      user
    end

    test "list_users/0 returns all users" do
      user = user_fixture()
      assert Accounts.list_users() == [user]
    end

    test "get_user!/1 returns the user with given id" do
      user = user_fixture()
      assert Accounts.get_user!(user.id) == user
    end

    test "create_user/1 with valid data creates a user" do
      assert {:ok, %User{} = user} = Accounts.create_user(@valid_attrs)
      assert user.email == "some email"
      assert user.uid == "some uid"
      assert user.username == "some username"
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_user(@invalid_attrs)
    end

    test "update_user/2 with valid data updates the user" do
      user = user_fixture()
      assert {:ok, %User{} = user} = Accounts.update_user(user, @update_attrs)
      assert user.email == "some updated email"
      assert user.uid == "some updated uid"
      assert user.username == "some updated username"
    end

    test "update_user/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Accounts.update_user(user, @invalid_attrs)
      assert user == Accounts.get_user!(user.id)
    end

    test "delete_user/1 deletes the user" do
      user = user_fixture()
      assert {:ok, %User{}} = Accounts.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(user.id) end
    end

    test "change_user/1 returns a user changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = Accounts.change_user(user)
    end
  end

  describe "characters" do
    alias Militerm.Accounts.Character

    @valid_attrs %{
      cap_name: "SomeCapName",
      name: "somecapname",
      # entity_id: "some entity",
      gender: "none"
    }
    @update_attrs %{
      cap_name: "SomeUpdatedCapName",
      name: "someupdatedcapname",
      gender: "female"
      # entity_id: "some updated entity"
    }
    @invalid_attrs %{cap_name: nil, name: nil, entity_id: nil, gender: nil}

    def character_fixture(attrs \\ %{}) do
      user = user_fixture()

      {:ok, character} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Map.put(:user_id, user.id)
        |> Accounts.create_character()

      character
    end

    test "list_characters/0 returns all characters" do
      character = character_fixture()
      assert Accounts.list_characters() == [character]
    end

    test "get_character!/1 returns the character with given id" do
      character = character_fixture()
      assert Accounts.get_character!(character.id) == character
    end

    test "create_character/1 with valid data creates a character" do
      user = user_fixture()
      attrs = Map.put(@valid_attrs, :user_id, user.id)
      assert {:ok, %Character{} = character} = Accounts.create_character(attrs)
      assert character.cap_name == "SomeCapName"
      assert character.name == "somecapname"
    end

    test "create_character/1 with valid data creates component data" do
      user = user_fixture()
      attrs = Map.put(@valid_attrs, :user_id, user.id)
      assert {:ok, %Character{} = character} = Accounts.create_character(attrs)
      identity_info = Militerm.Components.Identity.get(character.entity_id)
      detail_info = Militerm.Components.Details.get(character.entity_id, "default")
      assert identity_info.name == "SomeCapName"
      assert identity_info.nominative == "they"
      assert detail_info.nouns == ["somecapname"]
      {:ok, module} = Militerm.Components.Entity.module(character.entity_id)
      assert is_atom(module)
    end

    test "create_character/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_character(@invalid_attrs)
    end

    test "update_character/2 with valid data updates the character" do
      character = character_fixture()
      assert {:ok, %Character{} = character} = Accounts.update_character(character, @update_attrs)
      assert character.cap_name == "SomeUpdatedCapName"
      assert character.name == "someupdatedcapname"
    end

    test "update_character/2 with invalid data returns error changeset" do
      character = character_fixture()
      assert {:error, %Ecto.Changeset{}} = Accounts.update_character(character, @invalid_attrs)
      assert character == Accounts.get_character!(character.id)
    end

    test "delete_character/1 deletes the character" do
      character = character_fixture()
      assert {:ok, %Character{}} = Accounts.delete_character(character)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_character!(character.id) end
    end

    test "change_character/1 returns a character changeset" do
      character = character_fixture()
      assert %Ecto.Changeset{} = Accounts.change_character(character)
    end
  end
end