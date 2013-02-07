# 0.0.36 WIP

* Performance improvements for the public games list

# 0.0.35

* Fixes rolling migration of game categories

# 0.0.34

* Adds categories to games

# 0.0.33

* Migrates game retrieval of developers to new batch API

# 0.0.32

* Adds embed code to public game information

# 0.0.31

* Fixes CORS headers

# 0.0.30

* Adds embed codes to the embedded venue's computed config

# 0.0.29

* Adds embedded venue

# 0.0.28

* Improve Newrelic instrumenting

# 0.0.27

* Adds Newrelic monitoring and ping middleware

# 0.0.26

* Adds venue information to public game info

# 0.0.25

* Fixes bug so that rolling migrated game secrets are persisted

# 0.0.24

* Adds game secrets

# 0.0.23

* Makes it possible to retrieve public game data only for the games specified

# 0.0.22

* Forces new graph-client version

# 0.0.21

* Bumps auth-backend and graph-backend for tests

# 0.0.20

* Bumps datastore dependencies to adopt to the new datastore API

# 0.0.19

* Adds screenshots to the publicly available game information
* Refactors galaxy-spiral to spiral-galaxy in the README

# 0.0.18

* Renames galaxy-spiral to spiral-galaxy
* Gives more intel on error messages for invalid games

# 0.0.17

* Adds an endpoint to retrieve public information about all games

# 0.0.16

* Eases the internal dependencies

# 0.0.15

* Relaxes dependency on auth-client

# 0.0.14

* OPTIONS requests don't need to be authenticated anymore

# 0.0.13

* Makes it possible to initialize games without touching the graph

# 0.0.12

* Adds thin to the main bundle to run on Heroku

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
