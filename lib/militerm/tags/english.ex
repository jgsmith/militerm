defmodule Militerm.Tags.English do
  @moduledoc """
  Some generic tags for MML that aren't device-specific.
  """

  use Militerm.Systems.MML.Tags, device: :any

  deftag capitalize(_attributes, children, bindings, pov) do
    {bits, _} =
      children
      |> render_children(bindings, pov)
      |> to_list
      |> Enum.reduce({[], false}, fn
        bit, {acc, false} when is_binary(bit) ->
          {[String.capitalize(bit) | acc], true}

        bit, {acc, flag} ->
          {[bit | acc], flag}
      end)

    Enum.reverse(bits)
  end

  defp to_list(list) when is_list(list), do: list
  defp to_list(text), do: [text]
end
