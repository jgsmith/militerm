---

---
based on std:mobile

##
# Marks this entity as a player.
#
is player

can finish:verb as actor

can say as actor

can light:item as actor

calculates foo:bar with "Foo is Bar"

##
# msg:sight:env
#
# Used to report on events around that can be seen.
#
reacts to msg:sight with
  Emit("{narrative class='sight'}{{ text }}{/narrative}")

##
# enter:game
#
# Used when a character enters the game.
#
reacts to enter:game as actor with do
  [ <- scan:env:brief as actor with actor: this ]
  # Emit("{env sense='sight'}{{ Describe() }}{/env}")
end

##
# leave:game
#
# Used when a character leaves the game.
#
reacts to leave:game as actor with
  Emit("Goodbye!")

reacts to pre-light:item as actor with
  True

reacts to post-light:item as actor with do
  :"<Actor> <light> <direct>."
end
