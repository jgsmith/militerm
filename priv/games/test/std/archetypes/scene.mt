---
flag:
  - not-living
  - is-darkened
---
based on std:item

can move:receive
can move:release
can move:prox as direct

can scan:item as direct

reacts to pre-move:receive with
  True

reacts to pre-move:release with
  True

is dark when do
  if flag:is-darkened then
    # check if anything here has light
    set $lighters to selecting Inventory() as $thing with $thing is lit

    if $lighters then
      False
    else
      True
    end
  else
    False
  end
end
