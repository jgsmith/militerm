---
simple-response:
  default:
    - pattern: $_* level $level
      event: elevator:request
    - pattern: $_* level $level $_*
      event: elevator:request
---
based on std:scene

reacts to say:normal as observer with do
  SimpleResponseTriggerEvent("default", message)
  True
end

calculates detail:default:exits:out:target with do
  set $level to "level" _ trait:elevator-level
  thing:elevator:$level
end

#
# Provides a voice-activated elevator
#
# The exit for a level should be stored in
#    location:elevator:level:$level
#
reacts to elevator:request as responder with do
  if level = trait:elevator-level then
    :"<This> <stay> where it is."
  else
    set $level to "level" _ level # so we can use it as a property path
    if thing:elevator:$level then
      :"<This> announces: Getting ready to head to level {{ level }}."
      set trait:elevator-level to level
    else
      :"<This> announces: That level isn't available."
    end
  end
end