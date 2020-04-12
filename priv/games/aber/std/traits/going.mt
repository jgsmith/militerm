can go as actor

reacts to pre-go:direction as actor with do
  if direction & Exits() then
    set eflag:going
    set eflag:moving
    if is standing then
      :"<Actor> <go> {{ direction }}."
    else
      :"<Actor> <crawl> {{ direction }}."
    end
  else
    uhoh "You can't go that way."
  end
end

reacts to go:direction as actor with do
  if eflag:going then
    if not MoveTo("normal", "in", Exit( direction ) ) then
      reset eflag:going
      reset eflag:moving
      uhoh "You can't go that way."
    end
  end
end

reacts to post-go:direction as actor with do
  if eflag:going then
    if is standing then
      :"<Actor> <walk> in."
    else
      :"<Actor> <crawl> in."
    end
    reset eflag:going
    reset eflag:moving
  end
end