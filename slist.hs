
{-# LANGUAGE     
    DeriveFunctor,
    DeriveFoldable,
    DeriveTraversable,
    NoMonomorphismRestriction,
    GeneralizedNewtypeDeriving,
    StandaloneDeriving,
    TypeFamilies,
    ViewPatterns,
    RankNTypes,

    MultiParamTypeClasses,
    
    OverloadedStrings,
    TypeOperators,
    FlexibleContexts,
    
    TemplateHaskell
    #-}


module Data.SpanList (
        -- Write,
        -- writeFst,
        -- writeSnd,
        -- written,
        -- mcompose,
        Spanned',
        Spanned,
        SList,
        -- withSpans,
        addSpan,
        slist,
        reverseS,
        takeS,
        dropS,
        duplicateS,
        -- withValuesS,
) where

import Prelude hiding (span) -- TODO

import Control.Arrow
import Control.Applicative
import Control.Monad
import Control.Monad.Plus

import Control.Lens
import Data.Key
import Data.Maybe
import Data.Tree
import Data.Map (Map)
import qualified Data.Map as Map
import Data.Semigroup
import Data.Foldable
import Data.Traversable
import qualified Data.Foldable as F
import qualified Data.Traversable as T


newtype Write m a = Write (a, m)
    deriving (Show, Functor, Foldable, Traversable, Eq)
instance Monoid m => Monad (Write m) where
    return x = Write (x, mempty)
    Write (x1,m1) >>= f = let
        Write (x2,m2) = f x1
        in Write (x2,m1 `mappend` m2)

    Write (x1,m1) >> y = let
        Write (x2,m2) = y
        in Write (x2,m1 `mappend` m2)

writeFst (Write x) = fst x
writeSnd (Write x) = snd x
written f (Write (a, m)) = Write (a, f m)


{-
    The Key type family associates "indexed" types with their index.
    Instances include container-like types, functions and their composition.

    A /focused/ value a value of such a type paired up with its index. This
    is similar to a zipper, or a data structure paired with a lens into the
    structure.
-}

-- TODO move
mcompose :: (Monad m, Monad n, Functor m, Traversable n) => (a -> m (n b)) -> m (n a) -> m (n b)
mcompose = (join .) . fmap . (fmap join .) . T.mapM

-- | Value with a associated spans.
--   
--   Spans allow potentially overlapping subranges to be annotated with arbitrary
--   monoidal values.
--   
newtype Spanned' k m f a = Spanned' { unSpanned' :: Write (Map (k,k) m) (f a) }
    deriving (Functor, Foldable, Traversable, Eq, Show)
inSpanned' = unSpanned' ~> Spanned'

instance (Ord k, k ~ Key f, Monad f, Traversable f) => Monad (Spanned' k m f) where
    return = Spanned' . return . return
    Spanned' xs >>= f = Spanned' $ mcompose (unSpanned' . f) $ xs

type Spanned m f a = Spanned' (Key f) m f a

withSpans f (Spanned' (Write (a, m))) = (Spanned' (Write (a, f m)))

-- addSpan :: (Ord k, Semigroup m) => k -> k -> m -> Spanned' k m f a -> Spanned' k m f a
addSpan :: Semigroup m => Int -> Int -> m -> SList m a -> SList m a
addSpan a b x = withSpans $ Map.insertWith (<>) (a,b) x

slist :: [a] -> SList m a
slist xs = (Spanned' (Write (xs, mempty)))

reverseS = withValuesS reverse
takeS n = withValuesS (take n)
dropS n = withValuesS (drop n)
duplicateS = withValuesS (\xs -> xs <> xs)
-- cons x = withValuesS ((:) x)

{-
FIXME
consS x = unsafeWithValuesS (mapFirst (const x)) . withValuesS (undefined :)
    where mapFirst f (x:xs) = (f x):xs

unsafeWithValuesS :: ([a] -> [a]) -> SList m a -> SList m a
unsafeWithValuesS f (Spanned' (Write (a, m))) = (Spanned' (Write (f a, m)))
-}

-- FIXME rename
-- Transform the structure of a list (but not its values)
-- Retains all current spans under filtering or permutation (as long as the values are still there)
-- Note that the type guarantees that new values can not be added
-- TODO duplication etc is still problematic

withValuesS :: (forall a . [a] -> [a]) -> SList m a -> SList m a
withValuesS f sl = res
    where
        spans = writeSnd . unSpanned' $ sl
        xs = writeFst . unSpanned' $ sl
        ks = fmap fst . keyed $ xs -- unique keys
        
        ks2 = f ks `Prelude.zip` {-ks-}[0..] -- map old keys to new keys
        
        kf = flip Prelude.lookup ks2 -- function that maps old keys to new ones
        spans2 = removeNilKeys . Map.mapKeys (mapBothM kf) $ spans
        res = Spanned' (Write (f xs,spans2))
        
ex1, ex2, ex3, ex4 :: SList String Int
ex1 = reverseS $ addSpan 0 1 "h" $ slist [1..10]
ex2 = takeS 5 $ addSpan 0 1 "h" $ slist [1..10]
ex3 = dropS 5 $ addSpan 0 1 "h" $ slist [1..10]
ex4 = undefined
-- ex4 = consS 33 $ addSpan 0 1 "h" $ slist [1..10]

{-
    Test:
    
        
-}

    
-- (f, sl) = undefined
-- f :: ([a] -> [a])
-- sl :: SList m a
-- 
-- -- [a]
-- spans = writeSnd . unSpanned' $ sl
-- 
-- xs = writeFst . unSpanned' $ sl
-- ks = fmap fst . keyed $ xs -- unique keys
-- ks2 = ks `Prelude.zip` f ks -- map old keys to new keys
-- kf = flip Prelude.lookup ks2 -- function that maps old keys to new ones
-- spans2 = removeNilKeys . Map.mapKeys (mapBothM kf) $ spans
-- res = Spanned' (Write (xs,spans2))

-- List with spans
type SList m a = Spanned m [] a

removeNilKeys :: Ord a => Map (Maybe a) b -> Map a b
removeNilKeys = Map.mapKeys fromJust . Map.filterWithKey (\k v -> isJust k)

mapBothM :: Monad m => (a -> m b) -> (a, a) -> m (b, b)
mapBothM f (a,b) = do
    a2 <- f a
    b2 <- f b
    return (a2, b2)



(~>) :: (a' -> a) -> (b -> b') -> ((a -> b) -> (a' -> b'))
(i ~> o) f = o . f . i