---
flag:
  - not-living
---
based on std:item

can move:receive
can move:release

can scan:item as direct

reacts to pre-move:receive with
  True

reacts to pre-move:release with
  True
