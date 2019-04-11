module Data.SafeJSON
    ( -- * SafeJSON Class
      SafeJSON(version, kind, safeTo, safeFrom, objectProfile, typeName)
    , Contained
    , contain
    , safeToJSON
    , safeFromJSON
    -- * Version
    --
    -- | All 'SafeJSON' instances have a 'version'. This version will be
    --   attached to the JSON format and used to figure out which parser
    --   (and as such, which type in the chain) should be used to parse
    --   the given JSON.
    , Version
    , noVersion
    -- * Kind
    --
    -- | All 'SafeJSON' instance have a declared 'kind', indicating if any
    --   migration needs to happen when parsing using 'safeFromJSON'.
    --
    -- * The Base kind (see 'base') is at the bottom of the chain and will
    --   not be migrated to. They can optionally have no version tag by
    --   defining: @'version' = 'noVersion'@.
    --   /N.B./ 'base' /and/ 'extended_base' /are the only kinds that can/
    --   /be paired with/ 'noVersion'.
    --
    -- * Extensions (see 'extension' and 'extended_extension') tell the
    --   system that there exists at least one previous version of the data
    --   type which should be migrated from if needed.
    --   (This requires the data type to also have a @Migrate a@ instance)
    --
    -- * Forward extensions (see 'extended_base' and 'extended_extension')
    --   tell the system there exists at least one next version from which
    --   the data type can be reverse-migrated.
    --   (This requires the data type to also have a @Migrate (Reverse a)@
    --   instance)
    , Kind
    , base
    , extension
    , extended_base
    , extended_extension
    -- ** Showing the type
    --
    -- These helper functions can easily be used in the
    -- definition of 'typeName'. As long as the type
    -- being defined has a 'Typeable' instance.
    , typeName0
    , typeName1
    , typeName2
    , typeName3
    , typeName4
    , typeName5
    -- * Testing
    , Profile(..)
    , ProfileVersions(..)
    -- * Migration
    , Migrate(..)
    , Reverse(..)
    ) where


import Data.SafeJSON.Internal
import Data.SafeJSON.Instances()
