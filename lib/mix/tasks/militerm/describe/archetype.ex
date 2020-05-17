defmodule Mix.Tasks.Militerm.Describe.Archetype do
  use Mix.Task

  @shortdoc "Describe where all reactions, calculations, etc., come from in an archetype"
  def run(archetypes) do
    Mix.Task.run("app.start")
    Enum.each(archetypes, &describe(&1))
  end

  def describe(archetype) do
    data = Militerm.Systems.Archetypes.introspect(archetype)

    IO.puts([
      "Archetype: ",
      archetype,
      "\n\n",
      "Calculations:\n",
      Enum.sort(
        for {k, v} <- data.calculations do
          ["  ", k, " -> ", v, "\n"]
        end
      ),
      "\n",
      "Traits:\n",
      Enum.sort(
        for {k, provider} <- data.traits do
          ["  ", k, " -> ", provider, "\n"]
        end
      ),
      "\n",
      "Validators:\n",
      Enum.sort(
        for {k, provider} <- data.validators do
          [" ", k, " -> ", provider, "\n"]
        end
      ),
      "\n",
      "Abilities:\n",
      Enum.sort(
        for {{path, role}, provider} <- data.abilities do
          ["  ", Enum.join(Enum.reverse(path), ":"), " as ", role, " -> ", provider, "\n"]
        end
      ),
      "\n",
      "Reactions:\n",
      Enum.sort(
        for {{path, role}, provider} <- data.reactions do
          ["  ", Enum.join(Enum.reverse(path), ":"), " as ", role, " -> ", provider, "\n"]
        end
      )
    ])
  end
end
