#
# Add positioning
#

can sit as actor if is living
can stand as actor if is living
can kneel as actor if is living
can crouch as actor if is living

is standing if location:position = "standing"
is kneeling if location:position = "kneeling"
is sitting if location:position = "sitting"
is crouching if location:position = "crouching"

validates location:position with
  if value & trait:allowed:positions then
    True
  else
    False
  end

calculates trait:allowed:positions with do
  if location:location.detail:default:allowed-proximities then
    location:location.detail:default:allowed-proximities & ([ "standing", "sitting", "kneeling", "crouching" ])
  else
    Debug( ([ "standing", "sitting", "kneeling", "crouching" ]) )
    ([ "standing", "sitting", "kneeling", "crouching" ])
  end
end

calculates trait:foo:bar with do
  "Trait Foo Bar"
end

reacts to change:physical:position with
  if value = "standing" then
    :"<this:name> <stand> up."
  elsif value = "sitting" then
    :"<this:name> <sit> down."
  elsif value = "crouching" then
    :"<this:name> <crouch>."
  elsif value = "kneeling" then
    :"<this:name> <kneel>."
  end

reacts to pre-act:sit as actor with
  if is sitting then
    uhoh "You are already sitting."
  elsif can sit as actor then
    if "sitting" & trait:allowed:positions then
      set flag:is-about-to-sit
    else
      uhoh "You can't sit there."
    end
  else
    uhoh "Something prevents you from sitting."
  end

reacts to post-act:sit as actor with
  if flag:is-about-to-sit then
    reset flag:is-about-to-sit
    set location:position to "sitting"
  end

reacts to pre-act:crouch as actor with
  if is crouching then
    uhoh "You are already crouching."
  elsif can crouch as actor then
    if "crouching" & trait:allowed:positions then
      set flag:is-about-to-crouch
    else
      uhoh "You can't crouch there."
    end
  else
    uhoh "Something prevents you from crouching."
  end

reacts to post-act:crouch as actor with
  if flag:is-about-to-crouch then
    reset flag:is-about-to-crouch
    set location:position to "crouching"
  end

reacts to pre-act:kneel as actor with
  if is kneeling then
    uhoh "You are already kneeling."
  elsif can kneel then
    if "kneeling" & trait:allowed:positions then
      set flag:is-about-to-kneel
    else
      uhoh "You can't kneel there."
    end
  else
    uhoh "Something prevents you from kneeling."
  end

reacts to post-act:kneel as actor with
  if flag:is-about-to-kneel then
    reset flag:is-about-to-kneel
    set location:position to "kneeling"
  end

reacts to pre-act:stand as actor with
  if is standing then
    uhoh "You are already standing."
  elsif can stand then
    if "standing" & trait:allowed:positions then
      set flag:is-about-to-stand
    else
      uhoh "You can't stand there."
    end
  else
    uhoh "Something prevents you from standing."
  end

reacts to post-act:stand as actor with
  if flag:is-about-to-stand then
    reset flag:is-about-to-stand
    set location:position to "standing"
  end
