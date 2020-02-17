# TODOs

- Make gender ephemeral for character schema
- Update user schema to support Grapevine.haus auth
- Make general configuration like components for systems (or use a 'master' module)
- Provide compile-time resolution of component modules to property prefixes
- Remove `character_finder` from Militerm.Config since that's provided by core militerm
- Clean up ECS modules and bake in support for archetypes as the primary means of coordinating systems
- Support data inheritence for archetypes/entities
- English plurals of multi-word nouns should pluralize the first word (e.g., "attorney general" -> "attorneys general")
- Rename area/domain/scene schemas to remove "core_" prefix. Militerm will be opinionated.
- Clean up commands and mml tag management so we focus on supporting the macro approach.
- Hibernation/unhibernation should be across all components (in Systems.Entity)
- Differentiate between observers and environment when triggering an event (Systems.Events.trigger/3)
- Send debug info to user interactive session as well as log (if @debug on)
- Extract common functions from archetypes/mixins
