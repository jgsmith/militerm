defmodule Militerm.EnglishMacros do
  @moduledoc false

  defmacro pluralize(ending, replacement) do
    rending = ending |> String.reverse()
    rreplacement = replacement |> String.reverse()

    quote do
      defp do_reverse_plural(unquote(rending) <> rest),
        do: unquote(rreplacement) <> rest
    end
  end
end
