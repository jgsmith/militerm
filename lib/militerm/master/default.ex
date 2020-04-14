defmodule Militerm.Master.Default do
  @moduledoc ~S"""
  The default master module provides as reasonable baseline for the components,
  services, systems, and tag sets in a game.
  
  To use this as a base for your game:
  
  ```
  defmodule MyGame.Master do
    use Militerm.Master, based_on: Militerm.Master.Default
    
    ...
  end
  ```
  """

  use Militerm.Master

  alias Militerm.{Components, Services, Systems}

  component(:counter, Components.Counters)
  component(:detail, Components.Details)
  component(:eflag, Components.EphemeralFlag)
  component(:egroup, Components.EphemeralGroup)
  component(:epad, Components.EphemeralPad)
  component(:flag, Components.Flags)
  component(:identity, Components.Identity)
  component(:location, Components.Location)
  component(:resource, Components.Resources)
  component(:skill, Components.Skills)
  component(:stat, Components.Stats)
  component(:"simple-response", Components.SimpleResponses)
  component(:thing, Components.Things)
  component(:trait, Components.Traits)

  service(Services.Commands)
  service(Services.Events)
  service(Services.GlobalMap)
  service(Services.Verbs)
  service(Services.Socials)
  service(Services.Archetypes)
  service(Services.Mixins)
  service(Services.MML)
  service(Services.Script)

  system(Systems.Logger)
  system(Systems.Entity)
  system(Systems.Gossip)
  system(Systems.Groups)
  system(Systems.Help)
  system(Systems.MML)
  system(Systems.Location)
  system(Systems.SimpleResponse)

  tags(MilitermWeb.Tags.Colors)
  tags(MilitermWeb.Tags.Environment)
  tags(Militerm.Tags.English)
end
