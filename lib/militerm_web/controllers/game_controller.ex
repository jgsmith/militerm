defmodule MilitermWeb.GameController do
  use MilitermWeb, :controller

  alias Militerm.Repo
  import Ecto.Query

  def index(conn, _params) do
    %{id: user_id} = current_user(conn)

    characters =
      [user: user_id]
      |> Militerm.Accounts.list_characters()
      |> Enum.map(fn %{name: name, entity_id: entity_id} ->
        case Militerm.Components.Identity.get(entity_id) do
          %{name: ""} -> {name, name}
          %{name: cap_name} -> {name, cap_name}
          _ -> {name, name}
        end
      end)

    render(conn, "index.html", characters: characters)
  end

  def show(conn, %{"character" => character}) do
    %{id: user_id} = current_user(conn)

    record = Militerm.Accounts.get_character!(user_id: user_id, name: character)
    id_info = Militerm.Components.Identity.get(record.entity_id)

    info = %{
      name: character
    }

    render(conn, "show.html", character: info, identity: id_info)
  end
end
