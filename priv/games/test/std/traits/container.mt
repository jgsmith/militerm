#
# container
#
# Handles object massiveness and weight
#
# physical:mass - mass of object, not including any carried items
# physical:carried-mass - mass of all carried items
# physical:total-mass - mass + carried-mass
#

# direct being put into indirect
reacts to pre-move:receive as indirect with
  if physical:carried-mass + direct.physical:total-mass > physical:carried-mass:max then
    False
  else
    True
  end
