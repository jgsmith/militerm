defmodule Militerm do
  @moduledoc """
  Militerm keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  def version() do
    militerm =
      :application.loaded_applications()
      |> Enum.find(&(elem(&1, 0) == :militerm))

    "Militerm v#{elem(militerm, 2)}"
  end
end
