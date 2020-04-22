defmodule Militerm.Cache.Hospital do
  use Militerm.ECS.DataCache

  def fetch(key) do
    hospital_file = file_path(key)

    if File.exists?(hospital_file) do
      YamlElixir.read_from_file!(hospital_file)
    else
      nil
    end
  end

  defp file_path({domain, area}) do
    Path.join([Militerm.Config.game_dir(), "domains", domain, "areas", area, "hospital.yaml"])
  end

  defp file_path(domain) when is_binary(domain) do
    Path.join([Militerm.Config.game_dir(), "domains", domain, "hospital.yaml"])
  end
end
