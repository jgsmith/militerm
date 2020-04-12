---
flag:
  - living
location:
  position: standing
detail:
  default:
    noun:
      - human
    adjective:
      - simple
---
based on std:item

is positional, movable, gendered
is reading, smelling, viewing
is listening

can scan:brief as actor
can scan:item as actor

can move:accept as actor
can see as actor
can smell as actor
can go as actor

reacts to pre-go:direction as actor with do
  if direction & Exits() then
    set eflag:going
    set eflag:moving
    :"<Actor> <go> {{ direction }}."
  else
    uhoh "You can't go that way."
  end
end

reacts to go:direction as actor with do
  if eflag:going then
    if not MoveTo("normal", Exit( direction ) ) then
      reset eflag:going
      uhoh "You can't go that way"
    end
  end
end

reacts to post-go:direction as actor with do
  if eflag:going then
    :"<Actor> <verb:enter>."
    reset eflag:going
  end
end

reacts to pre-move:accept with do
  Emit("Accepting the move!")
  True
end

reacts to move:normal as actor with do
  Debug("We're moving!!!")
  if eflag:moving then
    reset eflag:moving
    Place(moving_to)
  end
end

reacts to post-move:accept with
  if physical:location.detail:default:position and not (physical:position & trait:allowed:positions) then
    set physical:position to physical:location.detail:default:position
  end
