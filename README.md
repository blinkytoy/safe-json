# safe-json

#### Automatic JSON format versioning

This library aims to make the updating of JSON formats or contents,
while keeping backward compatibility, as painless as possible. The
way this is achieved is through versioning and defined migration
functions to migrate older (or newer) versions to the one used.

*[skip to [How does it work](#how-does-it-work) for the actual implementation]*

---

* [Why?](#why)
  * [Some effects of changing a message format](#some-effects-of-changing-a-message-format)
* [How does it work](#how-does-it-work)
  * [SafeJSON](#safejson)
    * [Version](#version)
    * [Kind](#kind)
    * [Type name](#type-name)
    * [`safeFrom` and `safeTo`](#safefrom-and-safeto)
  * [Migrate](#migrate)
* [Keep in mind](#keep-in-mind)
  * [Using `noVersion`](#using-noversion)
  * [Non-object versioning](#non-object-versioning)
* [Example](#example)
* [Acknowledgments](#acknowledgments)

---

## Why?

An obvious example would probably be JSON messages used in a
production environment for communication between (micro-)services.

In a long running setting, there will most likely come a moment
that the JSON message in question will need to be restructured,
updated, or otherwise changed. This can result in some mild or more
serious headaches, depending on the architecture of the communicating
services.

### Some effects of changing a message format

* If the messages are being logged (e.g. to a database) and are used
in any way in the normal operation of the services, this results in
"old format" messages either needing to be excluded from queries after
the change to the new format, or all messages needing to be migrated
over to the new format manually.

* If downtime is undesirable (which is often the case), then an
in-place update of services will cause "new format" messages to be
received by the "old format" expecting services, and vice-versa.
This might be countered with creating new endpoints for the new
format and making sure the messages are routed correctly, etc. etc.
But this still includes overhead when the semantics of the endpoints
didn't actually change.

Why can't you just update the message format and leave everything as
is? That is the goal of this library.

## How does it work

The library mainly consists of two classes:

* `SafeJSON a`: Defines the version of `a` and if (and how) it is
migratable.
* `Migrate a`: Defines the data type (`MigrateFrom a`) that can be
migrated to `a` and how to migrate from that type.

### SafeJSON

The `SafeJSON` class defines the following:

* [`version`](#version): a unique identifier
* [`kind`](#kind): if and how to migrate to this type
* [`typeName`](#type-name): string to identify the type
* [`safeFrom`](safefrom-and-safeto): how to parse _from_ a JSON value
* [`safeTo`](safefrom-and-safeto): how to parse _to_ a JSON value

The default implementations of those last two use `parseJSON` and
`toJSON`, so you probably don't have to define them.
(There are some exceptions: read [Version](#version) / [safeFrom/-To](#safefrom-and-safeto))

__`safeFrom` and `safeTo` can not be used directly! The functions
that implement the versioning and migrating are `safeFromJSON` and
`safeToJSON`, which use `safeFrom` and `safeTo` internally.__

So given that your type already has `FromJSON` and `ToJSON` instances
(and is `Typeable`), the most basic definition of a `SafeJSON` instance
would be the following:

```haskell
instance SafeJSON MyType where
  version = 0
  kind = base
```

This will add the `version` tag as `0` and indicates this is the
first/bottom type in the migration chain.

---

#### Version

The version can be set using integer literals. The only requirement
is that no two types in a chain share the same version number.
(It is only used as a unique identifier.)

The implication is that, when using `safeToJSON`, the resulting JSON
will have an additional version field. How it's added depends on
the format.

If the resulting JSON is an object (which is the most likely), an extra
field will be added called `"!v"` with the number as the value.

```json
{
  "type": "my custom type",
  "someValues": [{},{"testing":true}],
  "!v": 1
}
```

If the resulting JSON is not an object, it will be wrapped in one
with the following fields:

```json
{
  "~v": 2,
  "~d": "my non-object type"
}
```

The fields (`"!v", "~v" and "~d"`) are chosen to be the least likely
used in any conventional setting, and as such are least likely to
clash with any existing JSON formats. `safeFromJSON` depends on
these fields to recover the version number, so any potential clashes
should be avoided.
([This can be accomplished by adjusting the `safeFrom` and `safeTo` methods](#safefrom-and-safeto))

_It is possible to omit a version tag, this is not advised, but
might be needed for integrating types that have been used before
using `SafeJSON`._
<!-- FIXME: add link to the explanation of `noVersion` -->

#### Kind

There are four different `kind`s a type can be:

* `base`: This type will not be migrated to when parsing.
  This can be seen as the bottom of the migration chain.
* `extension`: This type has at least one older version it can
  migrate from: the type defined as the `MigrateFrom` in the
  [`Migrate`](#migrate) instance.
* `extended_base`: This type has at least one newer version it
  can reverse migrate from, and none it can regularly migrate from:
  this newer type is defined as `MigrateFrom (Reverse a)`.
  (cf. [Reverse Migration](#reverse-migration))
* `extended_extension`: This type has at least one newer and
  one older version it can migrate from. (cf. [Migrate](#migrate)
  and [Reverse Migration](#reverse-migration))

A chain of `extension`s makes the backward compatibility work. If
a type is trying to be parsed using `safeFromJSON`, all older version
numbers will be able to be parsed, and subsequently migrated to the
current version.

If a type is also `extended_*`, that means the next/future version
will be tried before going down the chain. This is convenient when
old programs might receive the new type before being phased out,
while still being able to handle the data coming in.

#### Type name

The name of the type is used in the reporting of errors and when
making the `objectProfile`. A set of pre-made functions can be
used to easily define this method. (`typeName0-5`)

#### `safeFrom` and `safeTo`

In general, these methods should not have to be defined, since
`FromJSON` and `ToJSON` are constraints on the `SafeJSON` class.
There might be times when it is preferable to have the `SafeJSON`
parsing be different from the `From-/ToJSON` parsing, though.

While using `safeFromJSON` in a `parseJSON` definition is completely
valid, it can be desirable to only have versioned sub-parsing
(parsing of versioned values inside other values) happen when
using the `SafeJSON` interface. In those cases, you would have
to define the `safeFrom` and `safeTo` methods. (and using
`safeFromJSON` and `safeToJSON` in those definitions where
appropriate)

_When defining `safeFrom` and `safeTo`, you need to use the
`contain` function._

---

### Migrate

The `Migrate` class is where the magic happens; here you define
which type can be converted into which other type.

When defining a migration from an older type to a newer type,
it's as easy as defining:

```haskell
data OldType = OldType Text
data NewType = NewType [Text]

instance Migrate NewType where
  type MigrateFrom NewType = OldType
  migrate (OldType txt) = NewType [txt]
```

Now, whenever JSON is encountered that should be parsed as an
`OldType`, we can parse it as such, and then immediately migrate
it to `NewType`, which is the one the program actually uses.

_Do not forget to set the `kind` of `NewType` to either
`extension` or `extended_extension` to make use of this migration._

#### Reverse Migration

There is also the option to support a migration from one version
higher up in the chain to the current version. This is done
by defining the `kind` of the type in the `SafeJSON` instance
as one of the `extended_*` kinds and defining a `Migrate
(Reverse a)` instance for the current type. In that case, a
definition might look something like this:

```haskell
-- (using the above data definitions of OldType and NewType)
instance Migrate (Reverse OldType) where
   type MigrateFrom (Reverse OldType) = NewType
   migrate (NewType [])    = Reverse $ OldType ""
   migrate (NewType (t:_)) = Reverse $ OldType t
```

_N.B. At the moment there is no support for extended migrating
from newer versions further than the one directly defined in
the type's reverse migrate instance, i.e. if the parsing of
the type defined in type `a`'s `MigrateFrom (Reverse a)` fails,
the other attempts will go down the chain, not further up._

## Keep in mind

Here are some points to take note of when using this library.

### Using `noVersion`

<!--
------------------------
  N.B. about noVersion
------------------------

If you include a 'noVersion' in your chain (vNil), it is advised to remove
the need to include it as soon as possible, or, at least, to make sure no
program tries to parse the JSON as vNil; since, unlike versioned
types, anything trying to still parse the vNil type of your chain, will
ignore the version field and might succeed to parse newer versions if
the 'parseJSON/safeFrom' implementation of vNil would allow it.
-->

### Non-object versioning

<!--
### Safe non-object values
Making SafeJSON instances for non-Object 'Value's
creates additional overhead (since they get turned into objects)
so it is advised to try to make SafeJSON instances only for
top-level types that contain other types.
-->

## Example

This will be a simple walkthrough through an example use-case.

<!--

-------------------
  start of MyType
-------------------

data MyType

--------------------
  update to MyType
--------------------

data MyType_new

instance SafeJSON MyType
  version = noVersion
  kind = extended_base

instance SafeJSON MyType_new
  kind = extension

instance Migrate MyType_new
  type MigrateFrom MyType_new = MyType

instance Migrate (Reverse MyType)
  type MigrateFrom (Reverse MyType) = MyType_new

----------------------
  switching in-place
----------------------

In production, good idea to keep branch with only
the instance updates, while working to make the
new formats work.
Then when the new formats are tested -> update only the
instances on the services in production.
When those are all updated and running, update again
with the new format and functionality.

--------------------------
  update usages of types
--------------------------

MyType     -> MyType_old
MyType_new -> MyType


---------------------------
  When to actually change
  'safeFrom' and 'safeTo'
---------------------------

These use 'parseJSON' and 'toJSON' by default, but can be changed
in case the parsing with versioning should be different than without.
This might be the case if not just the entire Value, but also individual
fields in the object should use 'safeFromJSON' or 'safeToJSON', and
you want/need to keep the `FromJSON`/`ToJSON` instances completely
seperate from the `SafeJSON` instance.
-->


```haskell
data MyType = MyType {myA :: Text, myB :: [Int]}

instance FromJSON MyType where
  parseJSON = withObject "MyType" $ \o -> do
      myA <- o .: "text"
      myB <- o .:? "ints" .!= []
      return MyTypes{..}

instance ToJSON MyType where
  toJSON (MyType a b) = object
      [ "text" .= a
      , "ints" .= b
      ]
```

# Acknowledgments

The core of this library is inspired by the `safecopy` library
by David Himmelstrup and Felipe Lessa, found on
[GitHub](https://github.com/acid-state/safecopy),
[Hackage](https://hackage.haskell.org/package/safecopy) and
[Stackage](https://www.stackage.org/package/safecopy)