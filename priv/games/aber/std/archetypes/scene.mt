---
---
is viewable

##
# the `scene` trait is required for the web interface to recognize the
# archetype as a valid one for creating scenes.
#
is scene

can move:receive
can move:release

# reacts to pre-move:receive with do
#   Populate()
#   True
# end
#
# reacts to pre-move:release with
#   True
