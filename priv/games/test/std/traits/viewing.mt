#
# viewing
#
# Allows a character to view their surroundings
#

can scan:env:brief as actor
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

    Emit("{item sense='sight'}" _ Describe("sight", direct) _ "{/item}")
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
    :"<Actor:name> <look> around."
    Emit( "{env sense='sight'}{{ Describe() }}{/env}")
    Emit( "Obvious exits: {{ Exits() }}." )
    reset eflag:brief-scan
    reset eflag:scanning
  end
