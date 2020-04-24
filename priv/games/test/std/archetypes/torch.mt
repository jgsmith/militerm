---
resource:
  torch:
    fuel: 100
---
based on std:item

can light:item as direct

reacts to change:flag:torch:burning with do
  if value then
    :"<This> <light> up."
  else
    :"<This> <grow> dark as the flame dies out."
  end
end

reacts to pre-light:item as direct with do
  if (0 < resource:torch:fuel) and not flag:torch:burning then
    set eflag:lighting-torch
  end
end

reacts to light:item as direct with do
  if eflag:lighting-torch then
    set flag:torch:burning
    set trait:torch:flame:timer_id to Every("consume:fuel", 1)
    reset eflag:lighting-torch
  end
end

reacts to timer:consume:fuel as timer with do
  if resource:torch:fuel > 0 then
    set resource:torch:fuel to resource:torch:fuel - 1
  else
    reset flag:torch:burning
    StopTimer(trait:torch:flame:timer_id)
    reset trait:torch:flame:timer_id
  end
end
