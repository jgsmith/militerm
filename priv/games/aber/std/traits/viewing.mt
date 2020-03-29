#
# viewing
#
# Allows a sentient to view their surroundings
#

can scan:env:brief as actor
can scan:env as actor
can scan:item as actor

##
# pre-scan:item
#
reacts to pre-scan:item as actor with do
  set eflag:scan-item
  set eflag:scanning
end

reacts to post-scan:item as actor with
  if eflag:scan-item then
    :"<Actor:name> <examine> <direct>."
    reset eflag:scan-item
    reset eflag:scanning

    Emit("{item sense='sight'}{{ DescribeLong('sight', direct) }}{/item}") #"
  end

##
# pre-scan:item:brief
#
reacts to pre-scan:item:brief as actor with do
  set eflag:brief-scan-item
  set eflag:scanning
end

reacts to post-scan:item:brief as actor with
  if eflag:brief-scan-item then
    :"<Actor:name> <glance> at <direct>."
    reset eflag:brief-scan-item
    reset eflag:scanning

    Emit("{item sense='sight'}{{ Describe('sight', direct) }}{/item}") #"
  end

##
# pre-scan:brief
#
# We set the flag that we'll be looking around.
# This lets other things react to this.
reacts to pre-scan:env:brief as actor with do
  set eflag:brief-scan
  set eflag:scanning
end

reacts to post-scan:env:brief as actor with
  if eflag:brief-scan then
    :"<Actor:name> <glance> around."
    Emit( "{title}{{ location:environment }}{/title}" )
    Emit( "{env sense='sight'}{{ Describe() }}{/env}" ) #"
    Emit( "Obvious exits: {{ ItemList( Exits() ) }}." ) #"
    reset eflag:brief-scan
    reset eflag:scanning
  end

reacts to pre-scan:env as actor with do
  set eflag:scan
  set eflag:scanning
end
  
reacts to post-scan:env as actor with
  if eflag:scan then
    :"<Actor:name> <look> around."
    Emit( "{title}{{ location:environment }}{/title}" )
    Emit( "{env sense='sight'}{{ DescribeLong() }}{/env}" ) #"
    Emit( "Obvious exits: {{ ItemList( Exits() ) }}." ) #"
    reset eflag:scan
    reset eflag:scanning
  end