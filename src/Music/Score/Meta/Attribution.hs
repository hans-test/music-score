
{-# OPTIONS_GHC -fno-warn-incomplete-patterns #-}

{-# LANGUAGE ConstraintKinds            #-}
{-# LANGUAGE DeriveDataTypeable         #-}
{-# LANGUAGE DeriveFoldable             #-}
{-# LANGUAGE DeriveFunctor              #-}
{-# LANGUAGE DeriveTraversable          #-}
{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE ScopedTypeVariables        #-}
{-# LANGUAGE TypeFamilies               #-}

-------------------------------------------------------------------------------------
-- |
-- Copyright   : (c) Hans Hoglund 2012-2014
--
-- License     : BSD-style
--
-- Maintainer  : hans@hanshoglund.se
-- Stability   : experimental
-- Portability : non-portable (TF,GNTD)
--
-- Provides meta-data attribution for composer, lyricist etc.
--
-------------------------------------------------------------------------------------

module Music.Score.Meta.Attribution (

        -- * Attribution type
        Attribution,
        attribution,
        attributions,
        getAttribution,

        -- ** Adding attribution to scores
        attribute,
        attributeDuring,
        composer,
        composerDuring,
        lyricist,
        lyricistDuring,
        arranger,
        arrangerDuring,

        -- ** Extracting attribution
        withAttribution,
        withAttribution',
  ) where

import           Control.Lens              (view)
import           Control.Monad.Plus
import           Data.Foldable             (Foldable)
import qualified Data.Foldable             as F
import qualified Data.List                 as List
import           Data.Map                  (Map)
import qualified Data.Map                  as Map
import           Data.Maybe
import           Data.Semigroup
import           Data.Set                  (Set)
import qualified Data.Set                  as Set
import           Data.String
import           Data.Traversable          (Traversable)
import qualified Data.Traversable          as T
import           Data.Typeable

import           Music.Pitch.Literal
import           Music.Score.Meta
import           Music.Score.Part
import           Music.Score.Pitch
import           Music.Score.Internal.Util
import           Music.Time
import           Music.Time.Reactive


-- |
-- An attributions is a simple map from keys to values used to gather information such as
-- composer, lyricist, orchestrator, performer, etc.
--
-- Attribution is a 'Semigroup', and compose by choosing the leftmost value in each
-- category. For example
--
-- > attribution "composer" "H" <> attribution "composer" "S" <> attribution "lyricist" "S"
-- >     ===> attributions [("composer","H"),("lyricist","S")]
--
-- Any kind of attribution can be added, and backends may recognize or ignore categories as they
-- see fit. The following categories are normally recognized:
--
-- > composer
-- > lyricist
-- > arranger
-- > performer
-- > dedication
-- > year
-- > copyright
-- > information
--
newtype Attribution = Attribution (Map String (Option (Last String)))
    deriving (Typeable, Monoid, Semigroup)

instance Show Attribution where
    show (Attribution a) = "attributions " ++ show (Map.toList (fmap (fromJust . fmap getLast . getOption) $ a))

-- | Make an 'Attribution' from keys and values.
attributions :: [(String, String)] -> Attribution
attributions = Attribution . fmap (Option . Just . Last) . Map.fromList

-- | Make an 'Attribution' a single key and value.
attribution :: String -> String -> Attribution
attribution k v = Attribution . fmap (Option . Just . Last) $ Map.singleton k v

-- | Extract an the given attributions value. Semantic function.
getAttribution :: Attribution -> String -> Maybe String
getAttribution (Attribution a) k = join $ k `Map.lookup` (fmap (fmap getLast . getOption) $ a)


-- | Set the given attribution in the given score.
attribute :: (HasMeta a, HasPosition a) => Attribution -> a -> a
attribute a x = attributeDuring (_era x) a x

-- | Set the given attribution in the given part of a score.
attributeDuring :: (HasMeta a) => Span -> Attribution -> a -> a
attributeDuring s a = addMetaNote (view event (s, a))

-- | Set composer of the given score.
composer :: (HasMeta a, HasPosition a) => String -> a -> a
composer t x = composerDuring (_era x) t x

-- | Set composer of the given part of a score.
composerDuring :: HasMeta a => Span -> String -> a -> a
composerDuring s x = attributeDuring s ("composer" `attribution` x)

-- | Set lyricist of the given score.
lyricist :: (HasMeta a, HasPosition a) => String -> a -> a
lyricist t x = lyricistDuring (_era x) t x

-- | Set lyricist of the given part of a score.
lyricistDuring :: HasMeta a => Span -> String -> a -> a
lyricistDuring s x = attributeDuring s ("lyricist" `attribution` x)

-- | Set arranger of the given score.
arranger :: (HasMeta a, HasPosition a) => String -> a -> a
arranger t x = arrangerDuring (_era x) t x

-- | Set arranger of the given part of a score.
arrangerDuring :: HasMeta a => Span -> String -> a -> a
arrangerDuring s x = attributeDuring s ("arranger" `attribution` x)

-- | Extract attribution values of the given category from a score.
withAttribution :: String -> (String -> Score a -> Score a) -> Score a -> Score a
withAttribution name f = withAttribution' (fromMaybe id . fmap f . flip getAttribution name)

-- | Extract all attribution values from a score.
withAttribution' :: (Attribution -> Score a -> Score a) -> Score a -> Score a
withAttribution' = withMetaAtStart
