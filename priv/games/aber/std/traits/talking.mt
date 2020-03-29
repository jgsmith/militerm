##
# talking
#
# Let's the entity speak. Reacting is handled elsewhere.
#

can say as actor
can whisper as actor
can shout as actor
can tell as actor

reacts to pre-say with do
  set eflag:speaking
  set eflag:say-normal
end

reacts to post-say with do
  if eflag:say-normal then
    reset eflag:speaking
    reset eflag:say-normal
    
    sound:"<Actor> <say> {{ message }}"
  end
end

reacts to pre-whisper with do
  set eflag:speaking
  set eflag:say-whisper
end

reacts to post-whisper with do
  if eflag:say-whisper then
    reset eflag:speaking
    reset eflag:say-whisper
    
    sound:"<Actor> <whisper> {{ message }}"@whisper
  end
end

reacts to pre-shout with do
  set eflag:speaking
  set eflag:say-shout
end

reacts to post-shout with do
  if eflag:say-shout then
    reset eflag:speaking
    reset eflag:say-shout
    
    sound:"<Actor> <shout> {{ message }}"@shout
  end
end