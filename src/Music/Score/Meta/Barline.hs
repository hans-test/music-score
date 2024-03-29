
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
-- Provides special barlines as meta-data.
--
-- (Ordinary barlines are generated automatically, see also "Music.Score.Meta.Time").
--
-------------------------------------------------------------------------------------

module Music.Score.Meta.Barline (
        -- * Barline type
        BarlineType(..),
        Barline,

        -- ** Adding barlines to scores
        barline,
        doubleBarline,
        finalBarline,
        barlineDuring,

        -- ** Extracting barlines
        withBarline,
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

-- | Represents a barline.
--
-- TODO repeats
data Barline = Barline BarlineType
    deriving (Eq, Ord, Show, Typeable)

data BarlineType = StandardBarline | DoubleBarline | FinalBarline
    deriving (Eq, Ord, Show, Typeable)

-- | Add a barline over the whole score.
barline :: (HasMeta a, HasPosition a) => Barline -> a -> a
barline c x = barlineDuring (_era x) c x

-- | Add a barline over the whole score.
doubleBarline :: (HasMeta a, HasPosition a) => Barline -> a -> a
doubleBarline = undefined

-- | Add a barline over the whole score.
finalBarline :: (HasMeta a, HasPosition a) => Barline -> a -> a
finalBarline = undefined

-- | Add a barline to the given score.
barlineDuring :: HasMeta a => Span -> Barline -> a -> a
barlineDuring s c = addMetaNote $ view event (s, (Option $ Just $ Last c))

-- | Extract barlines in from the given score, using the given default barline.
withBarline :: (Barline -> Score a -> Score a) -> Score a -> Score a
withBarline f = withMeta (maybe id f . fmap getLast . getOption)
