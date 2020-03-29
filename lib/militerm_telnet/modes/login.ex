defmodule MilitermTelnet.Modes.Login do
  @moduledoc """
  A telnet mode to handle authentication and character selection/creation.
  """
  alias Militerm.Accounts

  def start_session(state) do
    # we spit out the banner and a link for authenticating the session
    welcome_filename = Path.join([Militerm.Config.game_dir(), "text", "welcome.txt"])

    if File.exists?(welcome_filename) do
      MilitermTelnet.Protocol.send_mml(state, File.read!(welcome_filename))
    end

    # If not using oauth over telnet (i.e., Grapevine)...
    session_key = make_ref()

    {:ok, binding} =
      Militerm.Systems.MML.bind("Please go to {{url}} to authenticate this session.\n", %{
        "url" =>
          Militerm.Services.Session.get_authentication_url(
            MilitermTelnet.Protocol,
            :authenticate_session,
            [session_key]
          )
      })

    MilitermTelnet.Protocol.send_mml(state, binding)

    state
    |> Map.put(:mode_state, :pending_authentication)
    |> Map.put(:session_key, session_key)
  end

  def authenticated(%{user_id: user_id, mode_state: :pending_authentication} = state) do
    # list characters in a menu, or offer to allow creation of a new character
    characters =
      Accounts.list_characters(user_id: user_id)
      |> Enum.sort_by(& &1.name)

    display_character_list(state, characters)

    state
    |> Map.put(:characters, characters)
    |> Map.put(:mode_state, :select_character)
  end

  def process_input(
        %{user_id: user_id, characters: characters, mode_state: :select_character} = state,
        input
      ) do
    input = String.trim(input)
    char_count = Enum.count(characters)

    if input in ["Q", "q"] do
      MilitermTelnet.Protocol.send_text(state, "See you next time...")
      Map.put(state, :mode_state, :disconnect)
    else
      case Integer.parse(String.trim(input)) do
        :error ->
          display_character_list(state, characters)

        {n, _} ->
          if n < 1 or n > char_count do
            display_character_list(state, characters)
          else
            # log them in...
            %{id: char_id, name: name, entity_id: entity_id} = Enum.at(characters, n - 1)
            MilitermTelnet.Protocol.send_text(state, "Entering game as #{name}...")

            state
            |> Map.put(:character_id, char_id)
            |> Map.put(:entity_id, entity_id)
            |> Map.put(:mode, MilitermTelnet.Modes.Play)
            |> MilitermTelnet.Modes.Play.start_session()
          end
      end
    end
  end

  def process_input(state, input), do: state

  defp display_character_list(state, characters) do
    choices =
      case Enum.count(characters) do
        0 -> "q"
        1 -> "1 or q"
        n -> "1..#{n} or q"
      end

    MilitermTelnet.Protocol.send_text(state, [
      "Please select a character (or 'q' to quit):\n",
      characters
      |> Enum.with_index(1)
      |> Enum.map(fn {%{name: name}, number} ->
        "  #{number}). #{name}\n"
      end)
    ])

    MilitermTelnet.Protocol.send_prompt(state, "Your choice (#{choices}): ")
  end
end
