defmodule Militerm.Metrics.PlayerInstrumenter do
  use Prometheus.Metric

  def setup() do
    Gauge.declare(
      name: :militerm_player_count,
      help: "Number of players signed in currently",
      labels: [:role]
    )

    Counter.declare(
      name: :militerm_player_session_start,
      help: "Count of player session starts",
      labels: [:interface, :security, :richness, :compression]
    )

    Counter.declare(
      name: :militerm_player_session_end,
      help: "Count of player session stops",
      labels: [:interface, :security, :richness, :compression]
    )
  end

  def set_player_count(counts) do
    Enum.each(counts, fn {role, count} ->
      Gauge.set([name: :militerm_player_count, labels: [role]], count)
    end)
  end

  def start_session(interface, security, richness, compression) do
    Counter.inc(
      name: :militerm_player_session_start,
      labels: [interface, security, richness, compression]
    )
  end

  def stop_session(interface, security, richness, compression) do
    Counter.inc(
      name: :militerm_player_session_end,
      labels: [interface, security, richness, compression]
    )
  end
end
