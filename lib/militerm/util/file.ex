defmodule Militerm.Util.File do
  @moduledoc """
  Provides path utilities to handle the game definition files.
  """

  alias Militerm.Config

  @spec clean_path([String.t()], [String.t()]) :: [String.t()]
  def clean_path(bits, acc \\ [])

  def clean_path([], acc), do: Enum.reverse(acc)

  def clean_path(["." | rest], acc), do: clean_path(rest, acc)

  def clean_path([".." | rest], []), do: clean_path(rest, [])

  def clean_path([".." | rest], [parent | acc]), do: clean_path(rest, acc)

  def clean_path([bit | rest], acc), do: clean_path(rest, [bit | acc])

  @spec resolve(String.t(), String.t(), String.t()) :: {:ok | :error, String.t()}
  def resolve(category, ur_name, sub_name) do
    [domain | bits] = sub_name |> String.split(":")

    domains =
      domain
      |> String.split("/")
      |> clean_path()
      |> List.foldl([""], fn bit, [last | _] = acc ->
        [last <> "/" <> bit | acc]
      end)
      |> Enum.map(fn x ->
        String.replace_leading(x, "/", "")
      end)

    paths =
      bits
      |> clean_path()
      |> Enum.reverse()
      |> Enum.drop(1)
      |> Enum.reverse()
      |> List.foldl([""], fn bit, [last | _] = acc ->
        [last <> ":" <> bit | acc]
      end)
      |> Enum.map(fn x ->
        String.replace_leading(x, ":", "")
      end)

    resolve_in_domain_path(category, ur_name, domains, paths)
  end

  defp resolve_in_domain_path(_, ur_name, [], _), do: {:error, "Unable to resolve #{ur_name}"}

  defp resolve_in_domain_path(category, ur_name, [domain | domains], paths) do
    case resolve_in_domain_and_paths(category, ur_name, domain, paths) do
      {:ok, resolved_name} -> {:ok, resolved_name}
      _ -> resolve_in_domain_path(category, ur_name, domains, paths)
    end
  end

  defp resolve_in_domain_and_paths(_, _, _, []), do: {:error, "Unable to resolve path"}

  defp resolve_in_domain_and_paths(category, ur_name, domain, [path | paths]) do
    case resolve_in_domain_and_path(category, ur_name, domain, path) do
      {:ok, resolved_name} -> {:ok, resolved_name}
      _ -> resolve_in_domain_and_paths(category, ur_name, domain, paths)
    end
  end

  defp resolve_in_domain_and_path(category, ur_name, "", path) do
    resolve_in_domain_and_path(category, ur_name, "std", path)
  end

  defp resolve_in_domain_and_path(category, ur_name, "std", "") do
    cleaned_ur_path =
      ur_name
      |> String.split(~r/[:\/]/)
      |> clean_path()

    filename =
      [
        Config.game_dir()
        | [
            "std"
            | [category | cleaned_ur_path]
          ]
      ]
      |> Enum.join("/")

    if File.exists?(filename <> ".mt") do
      {:ok, ["std" | cleaned_ur_path] |> Enum.join(":")}
    else
      {:error, "Unable to find #{ur_name}"}
    end
  end

  defp resolve_in_domain_and_path(category, ur_name, domain, "") do
    cleaned_ur_path =
      ur_name
      |> String.split(~r/[:\/]/)
      |> clean_path()

    filename =
      [
        Config.game_dir()
        | [
            "domains"
            | [
                domain
                | [category | cleaned_ur_path]
              ]
          ]
      ]
      |> Enum.join("/")

    if File.exists?(filename <> ".mt") do
      {:ok, [domain | cleaned_ur_path] |> Enum.join(":")}
    else
      {:error, "Unable to find #{ur_name}"}
    end
  end

  defp resolve_in_domain_and_path(category, ur_name, "std", path) do
    cleaned_ur_path =
      ur_name
      |> String.split(~r/[:\/]/)
      |> clean_path()

    filename =
      [
        Config.game_dir()
        | [
            "std"
            | [
                category
                | [path | cleaned_ur_path]
              ]
          ]
      ]
      |> Enum.join("/")

    if File.exists?(filename <> ".mt") do
      {:ok, ["std" | path ++ cleaned_ur_path] |> Enum.join(":")}
    else
      {:error, "Unable to find #{ur_name}"}
    end
  end

  defp resolve_in_domain_and_path(category, ur_name, domain, path) do
    cleaned_ur_path =
      ur_name
      |> String.split(~r/[:\/]/)
      |> clean_path()

    filename =
      [
        Config.game_dir()
        | [
            "domains"
            | [
                domain
                | [
                    category
                    | [path | cleaned_ur_path]
                  ]
              ]
          ]
      ]
      |> Enum.join("/")

    if File.exists?(filename <> ".mt") do
      {:ok, [domain | path ++ cleaned_ur_path] |> Enum.join(":")}
    else
      {:error, "Unable to find #{ur_name}"}
    end
  end
end
