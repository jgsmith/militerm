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
reacts to channel:receive with do
  Emit( "{channel name='{{name}}'}{{ message }}{/channel}")
end

##
# tell:remote supports player-to-player chat across games via gossip
#
reacts to tell:remote with do
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