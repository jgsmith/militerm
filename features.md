---
title: Features
---

## Narrative Space

Militerm expands on the traditional MUD environment to include relative positioning within a scene.
Rather than creating a series of rooms that link to each other through standard exits, Militerm
defines scenes with components that can hide or reveal exits or other details. This allows for richer
descriptions that allow more exploration of the game world.

Initial development is focused on scenes, but support for paths and terrains is on the roadmap.

## Probabilistic Content

Rather than specify which NPC goes where in which scene, or what might be foraged where, Militerm
lets you what might be found in certain areas with probabilities. The game then populates scenes
as-needed to provide interactive content for players.

## Persistent World

Militerm saves everything to a database, so even if the server restarts, everything will be where it was
before the restart. We've designed the server to allow rolling upgrades, so players don't have to
experience a shutdown or restart just to allow a server update. However, players connecting via telnet
might need to reconnect if the node they are on is replaced.
