defmodule Militerm.Systems.Help do
  use Militerm.ECS.System

  @moduledoc """
  A basuc help system that can provide overviews of verb syntaxes and show
  the contents of help documentation.
  """

  defcommand help(bits), for: %{"this" => this} do
    # look first for a document - then for a verb
    # needs to be a pipeline so we can include other options down the road
    # like spells or crafting
    request = %{arg: bits, actor: this, handled: false, nroff: nil, mml: nil, text: nil}

    pipeline()
    |> Enum.reduce(request, &apply(&1, :call, [&2]))
    |> interpret_pipeline_results()
  end

  def pipeline do
    [
      Militerm.Systems.Help.Verbs,
      Militerm.Systems.Help.Documents
      # Militerm.Systems.Help.Souls,
    ]
  end

  def interpret_pipeline_results(%{actor: actor, mml: mml}) when not is_nil(mml) do
    Militerm.Systems.Entity.receive_message(
      actor,
      "help",
      Militerm.Systems.MML.bind(mml, %{}),
      %{}
    )
  end

  def interpret_pipeline_results(%{actor: actor, nroff: nroff}) when not is_nil(nroff) do
    # we want to convert nroff to mml
    # we only do titles, headings, and paragraphs for now
  end

  def interpret_pipeline_results(%{actor: actor, text: text}) when not is_nil(text) do
    # just send the text as-is
    Militerm.Systems.Entity.receive_message(actor, "help", text, %{})
  end

  def interpret_pipeline_results(%{arg: bits, actor: actor} = result) do
    # unable to find help
    Militerm.Systems.Entity.receive_message(
      actor,
      "help:error",
      "Unable to find help for #{Enum.join(bits, " ")}",
      %{}
    )
  end
end
