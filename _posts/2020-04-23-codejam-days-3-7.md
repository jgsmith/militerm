---
title: Codejam Week 1
layout: post
categories: [exinfiltr8]
tags: [codejam,timers]
---
The first week is nearly gone and a fair amount has happened, though most of it is general system stuff.

Things specific to Exfiltr8:

- The start area is a ring and spoke layout with [a test that walks around the ring](https://github.com/jgsmith/exinfiltr8/blob/master/test/verbs/go_test.exs)
- The pub has a bar that you can [stand behind](https://github.com/jgsmith/exinfiltr8/blob/master/test/verbs/stand_behind_test.exs) to reach the kitchen

General things added to Militerm:
- A hospital allows the population of scenes with NPCs
- Support for timers allows for things like torches that run out of fuel over time

I'm still working on doors and other guarded movement between scenes, but we still have three weeks to get all of that done. We're making enough progress to have something interesting by the end of the codejam.

The goal for this coming weekend is to flesh out the opening level and the level below, add some NPCs, and start implementing the puzzles that will let you, the player, gain experience to advance a level, either with the government or the resistance.

There's not enough time in the codejam to write eight levels, so I'll settle for getting from the start area to the next level without having to sneak around as a win condition. After the codejam, I can add more levels and finish out the game content.

## Timers

The big addition to the Militerm system this week is timers. Timers let entities do things that aren't direct reactions to player input.

Take a torch, for example. It has some fuel, can be lit, and runs out eventually. A simple implementation would be something like the following (in the torch archetype):

```
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
```

The first reaction to the change in the flag simply narrates what happens: the torch lights up when it's lit and grows dark with it dies. What causes the transition isn't important to this narrative.

The `pre-light:item` reaction sets up the rest of the sequence if there's fuel and the torch isn't already burning.

If the item can be lit, then the `light:item` reaction gets things rolling. This sets the flag for it burning (which triggers the narrative) and creates a recurring timer that triggers the `timer:consume:fuel` event every second, storing the timer id for later use when the fuel runs out.

The final reaction, `timer:consume:fuel`, is triggered by the timer. This reaction decrements the fuel. If there's no fuel, it stops the timer and marks the torch as no longer burning.

The only timer function we didn't use is `Delay(event, seconds_delay)`. This will trigger the timer event after the given delay, but just once.

## Conclusion

Timers are the first step into making the game a more dynamic environment. This allows entities to have heartbeats and delayed reactions. Next on the menu for time-based support is chronic narrative: events that have a start, middle, and end that take place over an extended period of time. Like a dripping faucet that drips occasionally, or a blinking light, or a ringing bell.
