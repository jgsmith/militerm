defmodule MilitermWeb.DomainControllerTest do
  use MilitermWeb.ConnCase

  alias Militerm.{Accounts, Game}

  @create_attrs %{description: "some description", name: "some name", plug: "some-name"}
  @update_attrs %{
    description: "some updated description",
    name: "some updated name",
    plug: "some-updated-name"
  }
  @invalid_attrs %{description: nil, name: nil, plug: nil}

  @create_user_attrs %{
    email: "example@example.com",
    uid: "example@example.com",
    name: "example",
    is_admin: true
  }

  def fixture(:domain) do
    {:ok, domain} = Game.create_domain(@create_attrs)
    domain
  end

  def fixture(:user) do
    {:ok, user} = Accounts.create_user(@create_user_attrs)
    user
  end

  describe "index" do
    test "lists all domains", %{conn: conn} do
      conn =
        conn
        |> authenticate()
        |> get(AdminRoutes.domain_path(conn, :index))

      assert html_response(conn, 200) =~ "Listing Domains"
    end
  end

  describe "new domain" do
    test "renders form", %{conn: conn} do
      conn =
        conn
        |> authenticate()
        |> get(AdminRoutes.domain_path(conn, :new))

      assert html_response(conn, 200) =~ "New Domain"
    end
  end

  describe "create domain" do
    setup [:create_user]

    test "redirects to show when data is valid", %{conn: conn, user: user} do
      conn =
        conn
        |> authenticate(user)
        |> post(AdminRoutes.domain_path(conn, :create), domain: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == AdminRoutes.domain_path(conn, :show, id)

      conn =
        conn
        |> recycle
        |> authenticate(user)
        |> get(AdminRoutes.domain_path(conn, :show, id))

      assert html_response(conn, 200) =~ "Show Domain"
    end

    test "renders errors when data is invalid", %{conn: conn, user: user} do
      conn =
        conn
        |> authenticate(user)
        |> post(AdminRoutes.domain_path(conn, :create), domain: @invalid_attrs)

      assert html_response(conn, 200) =~ "New Domain"
    end
  end

  describe "edit domain" do
    setup [:create_domain]

    test "renders form for editing chosen domain", %{conn: conn, domain: domain} do
      conn =
        conn
        |> authenticate()
        |> get(AdminRoutes.domain_path(conn, :edit, domain))

      assert html_response(conn, 200) =~ "Edit Domain"
    end
  end

  describe "update domain" do
    setup [:create_domain, :create_user]

    test "redirects when data is valid", %{conn: conn, user: user, domain: domain} do
      conn =
        conn
        |> authenticate(user)
        |> put(AdminRoutes.domain_path(conn, :update, domain), domain: @update_attrs)

      assert redirected_to(conn) == AdminRoutes.domain_path(conn, :show, domain)

      conn =
        conn
        |> recycle()
        |> authenticate(user)
        |> get(AdminRoutes.domain_path(conn, :show, domain))

      assert html_response(conn, 200) =~ "some updated description"
    end

    test "renders errors when data is invalid", %{conn: conn, user: user, domain: domain} do
      conn =
        conn
        |> authenticate(user)
        |> put(AdminRoutes.domain_path(conn, :update, domain), domain: @invalid_attrs)

      assert html_response(conn, 200) =~ "Edit Domain"
    end
  end

  describe "delete domain" do
    setup [:create_domain, :create_user]

    test "deletes chosen domain", %{conn: conn, user: user, domain: domain} do
      conn =
        conn
        |> authenticate(user)
        |> delete(AdminRoutes.domain_path(conn, :delete, domain))

      assert redirected_to(conn) == AdminRoutes.domain_path(conn, :index)

      assert_error_sent 404, fn ->
        conn
        |> recycle()
        |> authenticate(user)
        |> get(AdminRoutes.domain_path(conn, :show, domain))
      end
    end
  end

  defp create_domain(_) do
    domain = fixture(:domain)
    {:ok, domain: domain}
  end

  defp create_user(_) do
    user = fixture(:user)
    {:ok, user: user}
  end

  defp authenticate(conn, %{} = user) do
    conn
    |> MilitermWeb.UserAuth.Guardian.Plug.sign_in(user)
  end

  defp authenticate(conn) do
    authenticate(conn, fixture(:user))
  end
end
