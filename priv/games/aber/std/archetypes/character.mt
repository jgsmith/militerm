---
alias:
  l: look $*
  i: inventory
  n: go north
  s: go south
  e: go east
  w: go west
  ne: go northeast
  nw: go northwest
  se: go southeast
  sw: go southwest
  d: go down
  u: go up
  out: go out
  exa: look at $*
  p: @who
  help: @help $*
  quit: @quit
  northwest: go northwest
  northeast: go northeast
  southwest: go southwest
  southeast: go southeast
  north: go north
  south: go south
  east: go east
  west: go west
  up: go up
  down: go down
  inv: inventory
  x: look at $*
  "'": say $*
  ":": emote $*
  '"': say $*
---
based on std:mobile

is sentient
is living

##
# Marks the entity as a player
#
is player

##
# msg:sight
#
# Used to report on events around that can be seen
#
reacts to msg:sight with
  Emit( "{narrative class='sight'}{{ text }}{/narrative}" )

##
# msg:sound
#
# Used to report on events around that can be heard
#
reacts to msg:sound with
  Emit( "{narrative class='sound'}{{ text }}{/narrative}" )

##
# channel:* supports chat channels
#
reacts to channel:receive as player with do
  Emit( "{channel}[{{ channel }}] {{player}}: {{ message }}{/channel}")
end

##
# gossip:* supports gossip info messages
#
reacts to gossip:player:sign_in as player with do
  Emit( "{info}{{ player }}@{{ game }} signed in{/info}")
end

reacts to gossip:player:sign_out as player with do
  Emit( "{info}{{ player }}@{{ game }} signed out{/info}")
end

reacts to gossip:game:up as player with do
  Emit( "{info}{{ game }} came up{/info}")
end

reacts to gossip:game:down as player with do
  Emit( "{info}{{ game }} went down{/info}")
end

reacts to gossip:channel:broadcast as player with do
  Emit( "{channel}[{{ channel }}] {{ player }}@{{ game }}: {{ message }}{/channel}")
end

##
# local:* supports gossip-like info messages for local players
#
reacts to local:player:sign_in as player with do
  Emit( "{info}{{ player }} signed in{/info}")
end

reacts to local:player:sign_out as player with do
  Emit( "{info}{{ player }} signed out{/info}")
end

##
# tell:remote supports player-to-player chat across games via gossip
#
reacts to tell:remote as player with do
  Emit( "{remote-tell}{{from}}: {{ message }}{/remote-tell}")
end

##
# action:done - triggered after a verb's event set is run
#
# allows us to send a prompt.
#
reacts to action:done as actor with do
  Prompt("> ")
end

##
# enter:game
#
# Used when a character enters the game.
#
reacts to enter:game as actor with do
  [ <- scan:env as actor with actor: this ]
end

##
# leave:game
#
# Used when a character leaves the game.
#
reacts to leave:game as actor with
  Emit("Goodbye!")
