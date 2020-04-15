defmodule Militerm.Command.Pipeline do
  defstruct input: "",
            entity: nil,
            context: %{},
            error: nil,
            phase: nil,
            state: :unhandled

  def run_pipeline(info, pipeline) do
    pipeline
    |> List.flatten()
    |> run_phases(struct(__MODULE__, info))
  end

  def run_phases(pipeline, info) do
    Enum.reduce_while(
      pipeline,
      info,
      fn phase_config, info ->
        {phase, options} = phase_invocation(phase_config)

        case phase.run(info, options) do
          {:cont, new_info} ->
            {:cont, new_info}

          :cont ->
            {:cont, info}

          {:handled, new_info} ->
            {:halt, Map.put(new_info, :state, :handled)}

          :handled ->
            {:halt, Map.put(info, :state, :handled)}

          {:error, message} ->
            {:halt,
             info |> Map.put(:error, message) |> Map.put(:phase, phase) |> Map.put(:state, :error)}
        end
      end
    )
  end

  defp phase_invocation(module) when is_atom(module), do: {module, []}
  defp phase_invocation({_module, _opts} = phase), do: phase

  def pipeline(:players) do
    [
      Militerm.Command.Plugs.Aliases,
      Militerm.Command.Plugs.Commands,
      {Militerm.Command.Plugs.Parse,
       [parser: Militerm.Parsers.Command, service: Militerm.Services.Verbs]},
      Militerm.Command.Plugs.RunEvents,
      {Militerm.Command.Plugs.Parse,
       [parser: Militerm.Parsers.Command, service: Militerm.Services.Socials]},
      Militerm.Command.Plugs.RunSocial
    ]
  end
end
