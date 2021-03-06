# 0.0.56 / 2013-08-12

* Fixed sentry app id

# 0.0.55 / 2013-08-12

* Adds getsentry.com exception tracking
* Adds request id tracker
* Updates client dependencies

# 0.0.54 / 2013-05-23

* Makes it possible to fake HTTP methods through a header
* Makes it possible to pass the OAuth token as a query param

# 0.0.53 / 2013-05-13

* Adds ``crossdomain.xml``

# 0.0.52 / 2013-04-07

* Fixes bug when saving games

# 0.0.51 / 2013-04-07

* Adds game insights endpoint

# 0.0.50 / 2013-04-05

* Adds paid game subscriptions and API endpoints
* Fixes bug when saving games with an unchanged developers list

# 0.0.49 / 2013-04-02

* Adds authorization

# 0.0.48

* Respects height margin in embed code's sizing

# 0.0.47

* Reflects games size setting in their embed code

# 0.0.46

* Adds ``uuid`` gem as a dependency to run on Heroku

# 0.0.45

* Updates dependencies

# 0.0.44

* Adds dimension information to games

# 0.0.43

* Updates grape_newrelic

# 0.0.42

* Updates rack
* Updates json

# 0.0.41

* Adds caching to public games list

# 0.0.40

* Adds credit urls for games

# 0.0.39

* Makes it possible to save a credits line with each game

# 0.0.38

* Fixes bug when batch retrieving non existent games

# 0.0.37

* Fixes bug that allowed games to be created without a category

# 0.0.36

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
