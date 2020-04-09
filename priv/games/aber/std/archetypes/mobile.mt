---
resource:
  health: 100
  stamina: 100
  mana: 100
counter:
  experience: 0
  level: 1
---
based on std:thing

is going, positioning

can move:accept as actor

reacts to pre-move:accept with do
  True
end

reacts to move:normal as actor with do
  if eflag:moving then
    reset eflag:moving
    Place(moving_to)
  end
end

reacts to post-move:accept with
  if physical:location.detail:default:position and not (physical:position & trait:allowed:positions) then
    set physical:position to physical:location.detail:default:position
  end
