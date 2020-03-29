defmodule Militerm.Command.Record do
  @moduledoc """
  The command record.

  This module defines a `Militerm.Command.Record` struct and the main functions for working
  with these structs.

  ## Request Fields

    * `command` - the list of words making up the command

  ## Response Fields

    * `slots` - map of slot name to entity/entities or strings named in the syntax
    * `events` - list of events that should fire to enact the command
    * `syntax` - the matching syntax

  ## Game Session Fields

  Game session fields are usually provided when the command record is initialized. These usually
  don't change during the processing of the command. They are useful in sending feedback to the
  right interface.

    * `actor` - the entity performing the actions of the command
    * `owner` - the entity owning the performance of the command
    * `groups` - group memberships in effect for this command
  """

  defstruct owner: nil,
            actor: nil,
            groups: [],
            command: [],
            slots: %{},
            events: [],
            syntax: nil,
            # true if subsequent plugs should pass on the record unchanged without taking action
            handled: false
end
