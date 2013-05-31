                              
{-# LANGUAGE
    TypeFamilies,
    DeriveFunctor,
    DeriveFoldable,
    FlexibleInstances,
    GeneralizedNewtypeDeriving #-} 

-------------------------------------------------------------------------------------
-- |
-- Copyright   : (c) Hans Hoglund 2012
--
-- License     : BSD-style
--
-- Maintainer  : hans@hanshoglund.se
-- Stability   : experimental
-- Portability : non-portable (TF,GNTD)
--
-- Provides a musical score represenation.
--
-------------------------------------------------------------------------------------


module Music.Score.Dynamics (
        HasDynamic(..),
        DynamicT(..),

        -- ** Dynamics over time
        Levels(..),
        cresc,
        dim,

        -- ** Application
        dynamicSingle,
        dynamics,

        -- ** Miscellaneous
        resetDynamics,
  ) where

import Control.Monad
import Data.Semigroup
import Data.Ratio
import Data.Foldable
import qualified Data.List as List
import Data.VectorSpace
import Data.AffineSpace

import Music.Score.Voice
import Music.Score.Score
import Music.Score.Duration
import Music.Score.Time
import Music.Score.Part
import Music.Score.Combinators

import Music.Dynamics.Literal

class HasDynamic a where
    setBeginCresc   :: Bool -> a -> a
    setEndCresc     :: Bool -> a -> a
    setBeginDim     :: Bool -> a -> a
    setEndDim       :: Bool -> a -> a
    setLevel        :: Double -> a -> a

-- end cresc/dim, level, begin cresc/dim
newtype DynamicT a = DynamicT { getDynamicT :: (Bool, Bool, Maybe Double, a, Bool, Bool) }
    deriving (Eq, Show, Ord, Functor, Foldable)



--------------------------------------------------------------------------------
-- Dynamics
--------------------------------------------------------------------------------

-- Apply a constant level over the whole score.
-- dynamic :: (HasDynamic a, HasPart a, Ord v, v ~ Part a) => Double -> Score a -> Score a
-- dynamic n = mapSep (setLevel n) id id 


-- | Apply a dynamic level over the score.
--   The dynamic score is assumed to have duration one.
--
dynamics :: (HasDynamic a, HasPart a, Ord v, v ~ Part a) => Score (Levels Double) -> Score a -> Score a
dynamics d a = (duration a `stretchTo` d) `dyns` a

-- | Apply a dynamic level over a single-part score.
--   Equivalent to `dynamics` for single part scores but more efficient.
--
dynamicSingle :: HasDynamic a => Score (Levels Double) -> Score a -> Score a
dynamicSingle d a  = (duration a `stretchTo` d) `dyn` a



-- | Apply a variable level over the score.
dyns :: (HasDynamic a, HasPart a, Ord v, v ~ Part a) => Score (Levels Double) -> Score a -> Score a
dyns ds = mapParts (fmap $ applyDynSingle (fmap fromJust $ scoreToVoice ds))

-- | Apply a variable level over a single-part score.
dyn :: HasDynamic a => Score (Levels Double) -> Score a -> Score a
dyn ds = applyDynSingle (fmap fromJust . scoreToVoice $ ds)

resetDynamics :: HasDynamic c => c -> c
resetDynamics = setBeginCresc False . setEndCresc False . setBeginDim False . setEndDim False


-- |
-- Represents dynamics over a duration.
--
data Levels a
    = Level  a
    | Change a a
    deriving (Eq, Show)

instance Fractional a => IsDynamics (Levels a) where
    fromDynamics (DynamicsL (Just a, Nothing)) = Level (toFrac a)
    fromDynamics (DynamicsL (Just a, Just b))  = Change (toFrac a) (toFrac b)
    fromDynamics x = error $ "fromDynamics: Invalid dynamics literal " {- ++ show x-}

cresc :: IsDynamics a => Double -> Double -> a
cresc a b = fromDynamics $ DynamicsL ((Just a), (Just b))

dim :: IsDynamics a => Double -> Double -> a
dim a b = fromDynamics $ DynamicsL ((Just a), (Just b))


-- end cresc, end dim, level, begin cresc, begin dim
type Levels2 a = (Bool, Bool, Maybe a, Bool, Bool)

dyn2 :: Ord a => [Levels a] -> [Levels2 a]
dyn2 = snd . List.mapAccumL g (Nothing, False, False) -- level, cresc, dim
    where
        g (Nothing, False, False) (Level b)     = ((Just b,  False, False), (False, False, Just b,  False, False))
        g (Nothing, False, False) (Change b c)  = ((Just b,  b < c, b > c), (False, False, Just b,  b < c, b > c))

        g (Just a , cr, dm) (Level b) 
            | a == b                            = ((Just b,  False, False), (cr,    dm,    Nothing, False, False))
            | a /= b                            = ((Just b,  False, False), (cr,    dm,    Just b,  False, False))
        g (Just a , cr, dm) (Change b c) 
            | a == b                            = ((Just b,  b < c, b > c), (cr,    dm,    Nothing, b < c, b > c))
            | a /= b                            = ((Just b,  b < c, b > c), (cr,    dm,    Just b,  b < c, b > c))



transf :: ([a] -> [b]) -> Voice a -> Voice b
transf f = Voice . uncurry zip . second f . unzip . getVoice

applyDynSingle :: HasDynamic a => Voice (Levels Double) -> Score a -> Score a
applyDynSingle ds as = applySingle ds3 as
    where
        -- ds2 :: Voice (Dyn2 Double)
        ds2 = transf dyn2 ds
        -- ds3 :: Voice (Score a -> Score a)
        ds3 = (flip fmap) ds2 g
        
        g (ec,ed,l,bc,bd) = id
                . (if ec then map1 (setEndCresc     True) else id)
                . (if ed then map1 (setEndDim       True) else id)
                . (if bc then map1 (setBeginCresc   True) else id)
                . (if bd then map1 (setBeginDim     True) else id)
                . (maybe id (\x -> map1 (setLevel x)) $ l)
        map1 f = mapSepVoice f id id






-- FIXME consolidate

-- | 
-- Map over first, middle and last elements of list.
-- Biased on first, then on first and last for short lists.
-- 
mapSepL :: (a -> b) -> (a -> b) -> (a -> b) -> [a] -> [b]
mapSepL f g h []      = []
mapSepL f g h [a]     = [f a]
mapSepL f g h [a,b]   = [f a, h b]
mapSepL f g h xs      = [f $ head xs] ++ (map g $ tail $ init xs) ++ [h $ last xs]

mapSep :: (HasPart a, Ord v, v ~ Part a) => (a -> b) -> (a -> b) -> (a -> b) -> Score a -> Score b
mapSep f g h sc = fixDur . mapParts (fmap $ mapSepVoice f g h) $ sc
    where
        fixDur a = padAfter (duration sc - duration a) a

mapSepVoice :: (a -> b) -> (a -> b) -> (a -> b) -> Score a -> Score b
mapSepVoice f g h sc = mconcat . mapSepL (fmap f) (fmap g) (fmap h) . fmap toSc . perform $ sc
    where             
        fixDur a = padAfter (duration sc - duration a) a
        toSc (t,d,x) = delay (t .-. 0) . stretch d $ note x
        third f (a,b,c) = (a,b,f c)

padAfter :: Duration -> Score a -> Score a
padAfter d a = a |> (rest^*d)       




second :: (a -> b) -> (c,a) -> (c,b)
second f (a,b) = (a,f b)

toFrac :: (Real a, Fractional b) => a -> b
toFrac = fromRational . toRational

fromJust (Just x) = x
