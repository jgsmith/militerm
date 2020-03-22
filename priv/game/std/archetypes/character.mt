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
# enter:game
#
# Used when a character enters the game.
#
reacts to enter:game as actor with
  Emit( "{env sense='sight'}" _ Describe() _ "{/env}")

##
# leave:game
#
# Used when a character leaves the game.
#
reacts to leave:game as actor with
  Emit("Goodbye!")