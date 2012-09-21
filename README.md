# devcenter-backend

A backend to handle everything game/developer related.

## API

The service must be accessed by HTTPS.

### Promoting an entity to become a developer

#### Request

**POST** ``/developers/:UUID:``

##### Parameters

- **UUID** [REQUIRED]: The UUID of the entity that should become a developer

##### Body

Empty.

#### Response

##### Body

Empty.

### Demoting an entity from being a developer

Doing so will also remove the entity as a developer from from all games he currently develops.

#### Request

**DELETE** ``/developers/:UUID:``

##### Parameters

- **UUID** [REQUIRED]: The UUID of the entity that should be demoted from being a developer

##### Body

Empty.

#### Response

##### Body

Empty.

### List games of a developer

**GET** ``/developers/:UUID:/games``

##### Parameters

- **UUID** [REQUIRED]: The UUID of the developer you want to list the games from

##### Body

Empty.

#### Response

##### Body

JSON encoded array of UUIDs of his games.

### Adding a game

#### Request

**POST** ``/games``

##### Body

JSON encoded options hash.

- **name** [REQUIRED]: Name of the game
- **description** [REQUIRED]: Text describing the game
- **configuration** [REQUIRED]: Hash that describes the game. Must include the key ``type`` which can be either ``html5`` or ``flash``.
- **developers** [REQUIRED]: Array of UUIDs of the developers of this game
- **screenshots** [OPTIONAL]: Array of image URLs of screenshots of the game
- **developer_configuration** [OPTIONAL]: Hash of arbitrary data you want to store along with the game
- **venues** [OPTIONAL]: Hash of venues (see [venues](#venues)). The
  key is a venue's name the value may be true or false. A not present
key is treated as a disabled venue.


#### Response

##### Body

JSON encoded hash containing the UUID of the newly created game. Example: ``{"uuid": "eb798e00-cb53-012f-4392-58b035f5cdfb"}``

### Adding a developer to a game

#### Request

**POST** ``/games/:GAME-UUID:/developers/:DEVELOPER-UUID:``

##### Parameters

- **GAME-UUID** [REQUIRED]: The UUID of the game you want to add the developer to
- **DEVELOPER-UUID** [REQUIRED]: The UUID of the developer you want to add to
  the game

##### Body

Empty.

#### Response

##### Body

JSON encoded hash of the game's configuration. See ``Changing a game``
for an example.

### Removing a developer from a game

#### Request

**DELETE** ``/games/:GAME-UUID:/developers/:DEVELOPER-UUID:``

##### Parameters

- **GAME-UUID** [REQUIRED]: The UUID of the game you want to add the developer to
- **DEVELOPER-UUID** [REQUIRED]: The UUID of the developer you want to add to
  the game

##### Body

Empty.

#### Response

##### Body

JSON encoded hash of the game's configuration. See ``Changing a game``
for an example.


### Deleting a game

Deleting a game will also remove all developers from this game (relations from developers to the game will be removed, not the developers themselves).

#### Request

**DELETE** ``/games/:UUID:``

##### Parameters

- **UUID** [REQUIRED]: The UUID of the game to be deleted

##### Body

Empty.

#### Response

##### Body

Empty.

### Change a game's configuration

#### Request

**PUT** ``/games/:UUID:``

##### Parameters

- **UUID** [REQUIRED]: The UUID of the game you want to change

##### Body

JSON encoded options hash.

- **name** [OPTIONAL]: Name of the game
- **description** [OPTIONAL]: Text describing the game
- **configuration** [REQUIRED]: Hash that describes the game. See [Game
  Types](#game-types) for more information.
- **developers** [OPTIONAL]: Array of UUIDs of the developers of this game
- **screenshots** [OPTIONAL]: Array of image URLs of screenshots of the game
- **developer_configuration** [OPTIONAL]: Hash of arbitrary data you want to store along with the game
- **venues** [OPTIONAL]: Hash of venues (see [venues](#venues)). The
  key is a venue's name the value may be true or false. A not present
key is treated as a disabled venue.

Every option that is not present at all in the request will remain unchanged.

#### Response

##### Body

JSON encoded hash of the game's configuration. Example:

```javascript
{
  "name": "Nonsense's Tale",
  "description": "Rumble your way to the treasures of Cpt. McDoodle and his crew. Fight parrots, barrels and pirates!",
  "configuration": {"type": "html5", "url": "http://example.com/game"},
  "developers": ["eb6d96b0-cb55-012f-4393-58b035f5cdfb", "ebc08260-cb55-012f-4394-58b035f5cdfb"],
  "screenshots": ["http://example.com/nonsense/1.jpg", "http://example.com/nonsense/2.jpg"],
  "developer_configuration": {"background": "red", "musicTheme": "caribbean"},
  "venues": {"facebook": true, "galaxy-spiral": false}
}
```
Note that no matter which options you passed in through the request, the response will always contain the whole configuration.

### Retrieve a game's configuration

#### Request

**GET** ``/games/:UUID:``

##### Parameters

- **UUID** [REQUIRED]: The UUID of the game you want to retrieve the configuration for

##### Body

Empty.

#### Response

##### Body

JSON encoded hash of the game's configuration. See ``Change a game's configuration`` response section for an example payload.

## Additional Info

### Game Types

Currently supported game types are

#### Initial

This type can only be used for newly created games. It's is **not**
allowed to switch a game from any other game type to ``initial``.

Configuration example:

```javascript
{"type": "initial"}
```

The ``type`` key is mandatory.

#### HTML5

Configuration example:

```javascript
{"type": "html5", "url": "http://example.com/game"}
```

The ``type`` and ``url`` keys are mandatory.

#### Flash

Configuration example:

```javascript
{"type": "flash", "url": "http://example.com/game.swf"}
```

The ``type`` and ``url`` keys are mandatory. ``url`` is pointing to a
SWF flash file.

### Venues

Currently available venues.

#### Facebook

**Key**: ``facebook``

#### Galaxy Spiral

**Key**: ``galaxy-spiral``

A white-label venue to embed your game on any website.
