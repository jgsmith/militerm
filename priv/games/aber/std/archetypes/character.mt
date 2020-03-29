---
---
based on std:mobile

is sentient

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
  Emit( "{channel name='{{name}}'}{{ message }}{/channel}")
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
  Emit( "{remote-tell from='{{from}}'}{{ message }}{/remote-tell}")
end

##
# enter:game
#
# Used when a character enters the game.
#
reacts to enter:game as actor with do
  Emit( "{title}{{ location:environment }}{/title}" )
  Emit( "{env sense='sight'}{{ DescribeLong() }}{/env}") #"
  Emit( "Obvious exits: {{ ItemList( Exits() ) }}." ) #"
end

##
# leave:game
#
# Used when a character leaves the game.
#
reacts to leave:game as actor with
  Emit("Goodbye!")
