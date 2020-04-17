---
title: Codejam FTW!
layout: post
categories: [exinfiltr8]
tags: [codejam]
excerpt: In which Exinfiltr8 is introduced.
---
For [the 2020 Enter the (Multi-User) Dungeon codejam](https://itch.io/jam/enterthemud3), I'm building out a game based on a combination of [The Resistance](https://en.wikipedia.org/wiki/The_Resistance_(game)) and [Paranoia](https://en.wikipedia.org/wiki/Paranoia_(role-playing_game)). The former comes with some boards, so I'm going with it: it's a board game.

I'm using this opportunity to make sure the Militerm game engine has all the pieces needed to build a basic multi-player text game. Exinfiltr8 will be the example game showing how Militerm works. Feel free to follow along in [the exinfiltr8 repo](https://github.com/jgsmith/exinfiltr8) if you're interested in the code, or here if you just want some narrative from time to time. Once I get enough built, I'll deploy it for play testing.

For the first day, I'm working on bootstrapping the basic game so that I can look around and move from scene to scene. Some of the more sophisticated things, like entering a lift to whisk me from place to place can wait for another time. Today is building out the starting area a bit and defining some basic verbs.

## Exinfiltr8

In a world made up of walls and corridors, without windows or any hint of an outside, do you believe the government? Or do you trust the rumors that there's a resistance ferreting out the truth? Can you build up trust with the government to find out what's really going on? Or do you work your way from cell to cell in the resistance? Or do you try to do both?

As a player, you have trust levels with both the government and the resistance rather than a single level. You gain experience with each as well.

I'm not designing the game to be strong on combat -- not going for a hack-n-slash. I'm going more for a role-playing game that lets you figure out puzzles and discover a story.

## Verbs

So today's verbs will be: `enter`, `examine`, `go`, and `look`. Those will let me run a test character through the first level of scenes.

Militerm defines verbs as a mapping of syntax patterns to sets of events, or actions. Let's take a look at a simple verb like `examine`:

```yaml
verbs:
  - examine
  - look at
brief: Examine something nearby
see also:
  - look
actions:
  - scan:item
syntaxes:
  - "<direct:object:near'thing>"
```

This sets up a few things. The syntaxes that the game will accept are `examine <thing>` and `look at <thing>`. If there's a match, then the `scan:item` event will be triggered with the `direct` variable set to the thing that we're wanting to look at. The rest of the information is useful for the help system.

In this example, we only have a single action that we take when we run the verb. But other verbs, like `go`, will use multiple actions: `go:direction` and `scan:env:brief`. By breaking the verb into multiple actions, we can reuse those actions with other verbs.

## Scenes

You might have noticed that I've used the word "scene" rather than "room". Militerm allows a richer narrative placement than just being in a room. This is the "scene", a sense of place with details that can act as locations within the scene. Eventually, I'll add support for paths (one-dimensional spaces like streets) and terrains (two-dimensional spaces). But I'm designing Exinfiltr8 to work with just scenes for now.

Let's look at how this sense of narrative place plays out. Depending on where you are in a scene, you might see or notice different details. For example, if you're standing on the floor in a storage room, you might see a vent in the ceiling, but be unable to reach it. But if you stood on the crate, you might be able to. Nothing complicated -- just that the exit for the vent is associated with the crate rather than the floor. So you can go from standing on the floor to standing on the crate. Then the vent is reachable and you can climb up or enter the vent. All of this is in the same scene, but you are in different places in that scene.

## Conclusion

So there's a taste of what I'm working on over the next month. I'll try to share a mix of game design, story telling, and technical details every day or two as the codejam unfolds. Feel free to ask questions or provide comments on Slack. I hang out in the Mud Coders Guild in several channels including #coding-elixir.
