# 0.0.11

* Adds special error when a retireved data set is not a game
* Hardens game creation (passing developers has been picky)

# 0.0.10

* Refactors errors to an explicit module
* Moves finder method from API to the game model

# 0.0.9

* Bumps the ``datastore-client``

# 0.0.8

* Bumps the ``graph-client``

# 0.0.7

* Adds the ``initial`` game type
* Adds venues

# 0.0.6

* Removes service-client as an explicit dependency as it is now
  automatically resolved through the datastore-client and graph-client
dependencies.

# 0.0.5

* Moves private gem server credentials to the Gemfile to make it
  possible to deploy on heroku

# 0.0.4

* Moves gem dependencies to the private gem server

# 0.0.3

* Bumps the datastore version

# 0.0.2

* Adds special endpoints to add/remove developers from games

# 0.0.1

The start.
