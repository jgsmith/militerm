can go as actor

reacts to pre-go:direction as actor with do
  if direction & Exits() then
    set eflag:going
    set eflag:moving
    :"<actor> <go> {{ direction }}."
  else
    uhoh "You can't go that way."
  end
end

reacts to go:direction as actor with do
  if eflag:going then
    if not MoveTo("normal", Exit( direction ) ) then
      reset eflag:going
      uhoh "You can't go that way."
    end
  end
end

reacts to post-go:direction as actor with do
  if eflag:going then
    :"<actor> <verb:enter>."
    reset eflag:going
  end
end