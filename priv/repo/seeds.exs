# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Militerm.Repo.insert!(%Militerm.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

Militerm.Accounts.create_user!(%{
  email: "admin@example.com",
  uid: "admin",
  username: "admin"
})

domain =
  Militerm.Game.create_domain!(%{
    name: "Tutorial Domain",
    description: "Tutorial domain to show how things can be built."
  })

area =
  Militerm.Game.create_area!(domain, %{
    name: "Tutorial Area",
    description: "Tutorial area to show how scenes can be created."
  })

# ###
# ### Create default set of relations
# ###
#
# # Things that are worn, held, attached, or contained are considered part of the target's
# # inventory if the target is not a scene, path, or terrain.
#
# relations = [
#   # text, closeness, is_attached, is_contained, is_held, is_intimate, is_worn, priority
#   {"in",           0, false, true, false, false, false, 0},
#   {"within",       0, false, true, false, false, false, 1},
#   {"inside",       0, false, true, false, false, false, 2},
#   {"enclosed",     0, false, true, false, false, false, 3},
#
#   {"attached",     1, true,  false, false, false, false, 0},
#
#   {"worn",         2, false, false, false, false, true,  0},
#   {"worn on",      2, false, false, false, false, true,  1},
#   {"worn under",   2, false, false, false, false, true,  2},
#
#   {"held",         3, false, false, true,  false, false, 0},
#   {"held in",      3, false, false, true,  false, false, 1},
#   {"held on",      3, false, false, true,  false, false, 2},
#
#   {"close to",     4, false, false, false, true,  false, 0},
#   {"close by",     4, false, false, false, true,  false, 1},
#   {"close beside", 4, false, false, false, true,  false, 2},
#
#   {"against",      5, false, false, false, true,  false, 0},
#
#   {"on",           6, false, false, true,  true,  false, 0},
#   {"upon",         6, false, false, true,  true,  false, 1},
#   {"on top of",    6, false, false, true,  true,  false, 2},
#   {"across",       6, false, false, true,  true,  false, 3},
#
#   {"under",        7, false, false, false, true,  false, 0},
#   {"beneath",      7, false, false, false, true,  false, 1},
#   {"below",        7, false, false, false, true,  false, 2},
#
#   {"around",       8, false, false, false, true,  false, 0},
#
#   {"near",         9, false, false, false, true,  false, 0},
#   {"by",           9, false, false, false, true,  false, 1},
#
#   {"over",        10, false, false, false, true,  false, 0},
#
#
# ]
#
# for {text, closeness, is_attached, is_contained, is_held, is_intimate, is_worn, priority} <- relations do
#   Militerm.Game.create_relation!(%{
#     text: text,
#     closeness: closeness,
#     is_attached: is_attached,
#     is_contained: is_contained,
#     is_held: is_held,
#     is_intimate: is_intimate,
#     is_worn: is_worn,
#     priority: priority
#   })
# end
