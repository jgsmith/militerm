#
# environment
#
# Handles object massiveness and weight
#
# physical:mass - mass of object, not including any carried items
# physical:carried-mass - mass of all carried items
# physical:total-mass - mass + carried-mass
#

reacts to pre-move:receive with
  if direct then
    physical:carried-mass + direct.physical:total-mass <= physical:carried-mass:max
  elsif actor then
    physical:carried-mass + actor.physical:total-mass <= physical:carried-mass:max
  else
    False
  end
