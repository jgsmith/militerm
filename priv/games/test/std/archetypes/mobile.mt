---
flag:
  - living
location:
  position: standing
detail:
  default:
    nouns:
      - human
    adjectives:
      - simple
---
based on std:item

is positional, movable, gendered
is reading, smelling, viewing
is listening

can scan:brief as actor
can scan:item as actor

can move:accept as actor
can move:prox:near as actor
can see as actor
can smell as actor
can go as actor

reacts to pre-move:prox as actor with do
  set eflag:moving-prox
  set eflag:moving
  :"<Actor> <move> toward <direct>."
end

reacts to move:prox:near as actor with do
  if eflag:moving then
    if not MoveTo("normal", "near", direct) then
      reset eflag:moving
      uhoh "You can't get there from here."
    end
  end
end

reacts to post-move:prox as actor with do
  reset eflag:moving-prox
  reset eflag:moving
end

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
    if not MoveTo("normal", "in", Exit( direction ) ) then
      reset eflag:going
      reset eflag:moving
      uhoh "You can't go that way"
    end
  end
end

reacts to post-go:direction as actor with do
  if eflag:going then
    reset eflag:moving
    :"<Actor> <verb:enter>."
  end
end

reacts to pre-move:accept with do
  Emit("Accepting the move!")
  True
end

reacts to move:normal as actor with do
  if eflag:moving then
    Place(moving_to)
  end
end

reacts to post-move:accept with
  if physical:location.detail:default:position and not (physical:position & trait:allowed:positions) then
    set physical:position to physical:location.detail:default:position
  end
