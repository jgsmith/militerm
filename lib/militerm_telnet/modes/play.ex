defmodule MilitermTelnet.Modes.Play do
  @moduledoc """
  A telnet mode to handle normal game play after character creation/selection.
  """
  def start_session(%{entity_id: entity_id} = state) do
    # we spit out news and other information done when entering the game
    Militerm.Services.Characters.enter_game({:thing, entity_id}, receiver: MilitermTelnet.Protocol)

    MilitermTelnet.Protocol.send_prompt(state, "> ")
    %{state | mode_state: :normal}
  end

  def process_input(%{entity_id: entity_id, mode_state: :normal} = state, input)
      when not is_nil(entity_id) do
    input = String.downcase(String.trim(input))

    if input == "@quit" || input == "quit" do
      %{state | mode_state: :disconnect}
    else
      Militerm.Systems.Entity.process_input({:thing, entity_id}, input)

      GenServer.cast(self(), {:prompt, "> "})
      state
    end
  end

  def process_input(state, _input), do: state
end
