can walk as actor

reacts to pre-walk:direction as actor with do
  if direction & Exits() then
    if is standing then
      set eflag:walking
      set eflag:moving
      :"<Actor> <walk> {{ direction }}."
    else
      uhoh "You can't walk if you're not standing!"
    end
  else
    uhoh "You can't walk that way."
  end
end

reacts to walk:direction as actor with do
  if eflag:walking then
    if not MoveTo("normal", "in", Exit( direction ) ) then
      reset eflag:walking
      reset eflag:moving
      uhoh "You can't walk that way."
    end
  end
end

reacts to post-walk:direction as actor with do
  if eflag:walking then
    :"<Actor> <walk> in."
    reset eflag:walking
    reset eflag:moving
  end
end