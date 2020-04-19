---
title: Codejam Day 2
layout: post
categories: [exinfiltr8]
tags: [codejam, caching, multi-node]
excerpt:
---
So day two has come and gone. I'm still focused on getting the starting area built out. Today was all about getting movement a bit more nuanced and the voice activated elevator working.

How does the elevator work? Glad you asked.

There's a `say` verb that lets a player say things:

```yaml
verbs:
  - say
syntaxes:
  - <string'message>
actions:
  - say:normal
```

So when a player types `say something`, then the parser sees this syntax match and associates
the action/event `say:normal`. This event is called on a number of objects. In this case, it's the actor (player) and anything nearby that might observe the action.

So the player gets to run the following reactions to the event:

{% raw %}
```
reacts to pre-say:normal as actor with do
  set eflag:speaking
  set eflag:say-normal
end

reacts to post-say:normal as actor with do
  if eflag:say-normal then
    reset eflag:speaking
    reset eflag:say-normal

    :"<Actor> <say>: {{ message }}"
  end
end
```
{% endraw %}

The main reason for breaking this into two reactions (`pre-` and `post-`) is to allow an observer or other participant to interrupt the action. Typically, the `post-` reactions are used to narrate what happened.

The above two reactions are everything needed for the player to say things in a scene. Everyone nearby will see the narrative. Not much else needs to be done there.

But there are similar events sent to observers. This is where the voice activated elevator is able to get in on the action. In this case, we define a simple pair of reactions and use a simple response system to match text against regular expressions.

{% raw %}
```
reacts to post-say:normal as observer with do
  if coord = "default" then
    if trait:lift:level & actor.trait:allowed:levels then
      if not eflag:responding-to-speach then
        set eflag:responding-to-speech
        if not SimpleResponseTriggerEvent("lift", message) then
          reset eflag:responding-to-speech
        end
      end
    else
      unset eflag:responding-to-speech
      :"<This> <say>: <actor>, you are not allowed here!"
      :"<This> <say>: This will be reported to the authorities."
      set $level to actor.trait:government:trust
      MoveTo("elevator", actor, "on", thing:lift:$level)
    end
  end
  True
end

reacts to elevator:request as responder with do
  unset eflag:responding-to-speech
  set $level to level
  if thing:lift:$level and $level & actor.trait:allowed:levels then
    if level = trait:lift:level then
      :"<This> <say>: you are already there."
    else
      :"<This> <whisk> <actor> to their destination."
      MoveTo("elevator", actor, "in", thing:lift:$level)
    end
  else
    :"<This> <say>: {{level}} is not a valid level."
  end
end
```
{% endraw %}

Let's unpack this a little.

The `if coord = "default" then ...` guard is to make sure we don't respond to the speech more than once. Multiple details in the scene may get the event as an observer, and we only want to react if the player can be heard by the root detail in the scene.

Then, we make sure that the player is the right trust level to use the elevator. If not, then they are violating the government's trust and need to be sent down to an appropriate level in the complex. This means that a player who doesn't say anything won't be noticed by the elevator's computer.

If the player is of the right level to be using this lift, then we send their speech to the `SimpleResponseTriggerEvent` function. This uses patterns from the `simple-response` component to see if there's a match against the text. If so, then it will trigger the corresponding event with any text captures.

In this case, if a player says something that matches `level ___`, then the `elevator:request` event will be triggered with `level` set to the match. The rest of that event handler then makes sure the level makes sense, is accessible, and isn't where the player already is.

See [the elevator archetype](https://github.com/jgsmith/exinfiltr8/blob/master/priv/game/std/archetypes/elevator.mt) for all of the details.

## Multi-Node Support

I'm designing Militerm to work in a multi-node topology out of the box. I have two kinds of processes based on the types of data the processes manage: static or dynamic. Processes for static data focus on serving the needs of other processes on the same node. Processes for dynamic data focus on serving the needs of other processes across all of the nodes.

Static data is the same across all of the nodes. It's probably built from data that's distributed with the game application (e.g., verb definitions). There's no need to make sure all nodes have the same view since they already do (except during a rolling deployment, but I'll worry about that later).

Dynamic data is associated with entities. These are the scenes, things, players, etc., in the game. These should be represented by a single process across all of the nodes.

So static data processes are managed as part of the application process tree in the usual Elixir/Erlang way. Nothing too surprising. Each node that spins up runs its own copy of all of the static data processes.

Dynamic data processes are managed via [`Swarm`](https://hex.pm/packages/Swarm) so that they can be balanced across nodes and found regardless of where they are running. With [`libcluster`](https://hex.pm/packages/libcluster), nodes can come and go without impacting the game *too* much. Or that's the plan.

There are a few race conditions to work out around updating data, but this is good enough for now.

## Caching

At the last minute, I went ahead and switched from [`Cachex`](https://hex.pm/packages/cachex) to [`Nebulex`](https://hex.pm/packages/nebulex) for caching component data. Both modules profess to support distributed caches, but my reading of the documentation makes me more hopeful for `Nebulex` over `Cachex`.

My impression of `Cachex` distributed caching is that the topology is set at start-up time. Once the number of nodes is known, the distribution algorithm is set and things go from there.

On the other hand, my impression of `Nebulex` is that it might be able to work with changes in node topology. I'm okay with cached data getting dropped since it's either ephemeral (just needed to coordinate events when executing an action) or stored in a permanent data store.

I need to test, but my hope is that as `libcluster` adds and removes nodes, `Nebulex` will keep up and coordinate its cache across all of the nodes.

## Conclusion

So that's what all went into the second day. Not a lot of content, but enough other stuff to make tomorrow a bigger push on getting the basic map fleshed out. Then during the week, I can work on the hospital (populating random NPCs in a non-random way) and itemization. Getting and dropping things.
