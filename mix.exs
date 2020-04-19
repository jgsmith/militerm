defmodule Militerm.MixProject do
  use Mix.Project

  def project do
    [
      app: :militerm,
      version: "0.1.0",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Militerm.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:cachex, "~> 3.2"},
      {:ecto_sql, "~> 3.0"},
      {:gettext, "~> 0.11"},
      {:gossip, "~> 1.0", runtime: false},
      {:guardian, "~> 2.0"},
      {:jason, "~> 1.0"},
      {:libcluster, "~> 3.1.1"},
      {:nebulex, "~> 1.2.1"},
      {:oauth2, "~> 0.9"},
      {:phoenix, "~> 1.4.0"},
      {:phoenix_ecto, "~> 4.0"},
      {:phoenix_html, "~> 2.11"},
      {:phoenix_live_view, "~> 0.10.0"},
      {:phoenix_pubsub, "~> 1.1"},
      {:plug_cowboy, "~> 2.0"},
      {:postgrex, ">= 0.0.0"},
      {:prometheus_ex, "~> 3.0"},
      {:prometheus_ecto, "~> 1.4.1"},
      {:prometheus_phoenix, "~> 1.3.0"},
      {:prometheus_plugs, "~> 1.1.1"},
      {:secure_random, "~> 0.5"},
      {:swarm, "~> 3.0"},
      {:yaml_elixir, "~> 2.0"},
      {:ueberauth, "~> 0.4"},

      # Dev-only
      {:file_system, "~> 0.2.8", only: :dev},
      {:phoenix_live_reload, "~> 1.2", only: :dev},

      # Dev- or test-only
      {:floki, ">= 0.0.0", only: :test},
      {:credo, "~> 1.1.0", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      # , "run priv/repo/seeds.exs"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "run priv/repo/seeds.exs", "test"]
    ]
  end
end
