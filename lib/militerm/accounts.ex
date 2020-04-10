defmodule Militerm.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Militerm.Config

  alias Ecto.Multi

  alias Militerm.Accounts.User

  @start_location {"in", {:thing, "scene:aber:start:between", "default"}}

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    Config.repo().all(User)
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Config.repo().get!(User, id)

  def get_user(nil), do: nil

  def get_user(id), do: Config.repo().get(User, id)

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Config.repo().insert()
  end

  def create_user!(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Config.repo().insert!()
  end

  def user_from_grapevine(auth) do
    params = %{
      uid: auth.uid,
      name: auth.info.name,
      email: auth.info.email
    }

    # look by uid first, then by email
    params
    |> maybe_find_user_by(:uid)
    |> maybe_find_user_by(params, :email)
    |> maybe_create_or_update_user(params)
  end

  defp maybe_find_user_by(opts, field) do
    maybe_find_user_by(nil, opts, field)
  end

  defp maybe_find_user_by(nil, opts, key) do
    value = Map.get(opts, key)

    User
    |> where([u], field(u, ^key) == ^value)
    |> Config.repo().one()
  end

  defp maybe_find_user_by(user, _, _), do: user

  defp maybe_create_or_update_user(nil, params) do
    params = Map.put(params, :is_admin, no_users?())
    create_user(params)
  end

  defp maybe_create_or_update_user(user, params) do
    update_user(user, params)
  end

  def no_users?() do
    User
    |> limit(1)
    |> Config.repo().one
    |> is_nil
  end

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Config.repo().update()
  end

  @doc """
  Deletes a User.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user) do
    Config.repo().delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{source: %User{}}

  """
  def change_user(%User{} = user) do
    User.changeset(user, %{})
  end

  alias Militerm.Accounts.Character

  @doc """
  Returns the list of characters.

  ## Examples

      iex> list_characters()
      [%Character{}, ...]

  """
  def list_characters(opts \\ []) do
    opts
    |> add_constraint(Character)
    |> Config.repo().all()
  end

  @doc """
  Gets a single character.

  Raises `Ecto.NoResultsError` if the Character does not exist.

  ## Examples

      iex> get_character!(123)
      %Character{}

      iex> get_character!(456)
      ** (Ecto.NoResultsError)

  """
  def get_character!(opts) do
    opts
    |> add_constraint(Character)
    |> Config.repo().one!()
  end

  def get_character(opts) do
    opts
    |> add_constraint(Character)
    |> Config.repo().one()
  end

  @doc """
  Creates a character.

  This also creates an entity to represent the character in the game.

  ## Examples

      iex> create_character(%{field: value})
      {:ok, %Character{}}

      iex> create_character(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_character(attrs \\ %{}) do
    entity_id = "std:character#" <> UUID.uuid4()

    using_atoms = Enum.any?(attrs, fn {k, _} -> is_atom(k) end)
    entity_id_key = if using_atoms, do: :entity_id, else: "entity_id"

    attrs =
      attrs
      |> Map.put(entity_id_key, entity_id)

    result =
      %Character{}
      |> Character.changeset(attrs)
      |> Config.repo().insert

    case result do
      {:ok, character} ->
        {nominative, objective, possessive} =
          case character.gender do
            "male" -> {"he", "him", "his"}
            "female" -> {"she", "her", "her"}
            "neuter" -> {"hi", "hir", "hir"}
            "none" -> {"they", "them", "their"}
          end

        Militerm.Entities.Thing.create(entity_id, "std:character",
          identity: %{
            name: character.cap_name,
            nominative: nominative,
            objective: objective,
            possessive: possessive
          },
          detail: %{
            "default" => %{
              nouns: [character.name],
              short: character.cap_name,
              adjectives: []
            }
          }
        )

        Militerm.Systems.Location.place({:thing, entity_id}, @start_location)
        Militerm.Systems.Entity.hibernate({:thing, entity_id})

        {:ok, character}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Updates a character.

  ## Examples

      iex> update_character(character, %{field: new_value})
      {:ok, %Character{}}

      iex> update_character(character, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_character(%Character{} = character, attrs) do
    character
    |> Character.changeset(attrs)
    |> Config.repo().update()
  end

  @doc """
  Deletes a Character.

  ## Examples

      iex> delete_character(character)
      {:ok, %Character{}}

      iex> delete_character(character)
      {:error, %Ecto.Changeset{}}

  """
  def delete_character(%Character{} = character) do
    Config.repo().delete(character)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking character changes.

  ## Examples

      iex> change_character(character)
      %Ecto.Changeset{source: %Character{}}

  """
  def change_character(%Character{} = character) do
    Character.changeset(character, %{})
  end

  defp add_constraint({key, value}, query) do
    where(query, [q], field(q, ^key) == ^value)
  end

  defp add_constraint(list, query) when is_list(list) do
    Enum.reduce(list, query, &add_constraint/2)
  end

  defp add_constraint(id, query) when is_binary(id) or is_number(id) do
    where(query, [q], q.id == ^id)
  end
end
