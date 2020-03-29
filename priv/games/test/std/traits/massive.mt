#
# massive
#
# Handles object massiveness and weight
#
# physical:mass - mass of object, not including any carried items
# physical:carried-mass - mass of all carried items
# physical:total-mass - mass + carried-mass
#

calculates physical:carried-mass with
  0 + physical:inventory.physical:total-mass

calculates physical:total-mass with
  physical:mass + physical:carried-mass

calculates physical:weight with
  physical:total-mass * (physical:environment.physical:gravity // (9.8))

# actor entering the environment
reacts to pre-move:receive as environment with
  if physical:carried-mass + actor.physical:total-mass > physical:carried-mass:max then
    False
  else
    True
  end

# direct being put into indirect
reacts to pre-move:receive as indirect with
  if physical:carried-mass + direct.physical:total-mass > physical:carried-mass:max then
    False
  else
    True
  end
