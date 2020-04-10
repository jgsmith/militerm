---
---
reacts to say:normal as observer with do
  set $id to Id(actor)
  if not trait:conversation:overheard:$id:state then
    set trait:conversation:overheard:$id:state to "overheard"
  end
  
  SimpleResponseTriggerEvent(trait:conversation:$id:state, message)
  True
end

reacts to tell as direct with do
  set $id to Id(actor)
  if not trait:conversation:told:$id:state then
    set trait:conversation:told:$id:state to "told"
  end
  
  SimpleResponseTriggerEvent(trait:conversation:$id:state, message, "convo:told:not-a-clue")
  True
end

reacts to convo:told:not-a-clue as observed with do
  :"<This> shakes their head at <actor>."
  # !"shake head at <actor>"
end