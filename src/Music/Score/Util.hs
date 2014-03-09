

{-# LANGUAGE ViewPatterns #-}

module Music.Score.Util where

----------------------------------------------------------------------
--
-- File generated by hackette. Do not edit!
--
-- Fetched by hans on Sön  9 Mar 2014 14:52:14 CET
--
----------------------------------------------------------------------



{-# LANGUAGE ViewPatterns #-}

{-
    Rules:
    
        * Functions may depend on any module in the lastest Haskell Platform release
        * All functions but those in Prelude must be referred to with their full,
          qualified names (i.e. Data.List.unfoldr).
        * Each function must have a unique name (so the whole file is a loadable module).
        * Each function should have a synopisis, like:

            -- | Ordinary Haddock commentary ...
            -- > category: Categories (please use the common Hackage names)
            -- > depends : base (all packages in HP that the function depends on)
            
-}

import qualified Data.Char
import qualified Data.Monoid
import qualified Data.List
import qualified Data.Ratio

-- | Synonym for 'Data.Char.toUpper'
-- > category : String
-- > depends : base
toUpperChar :: Char -> Char
toUpperChar = Data.Char.toUpper

-- | Synonym for 'Data.Char.toLower'
-- > category : String
-- > depends : base
toLowerChar :: Char -> Char
toLowerChar = Data.Char.toLower

-- | Synonym for 'fmap Data.Char.toUpper'
-- > category : String
-- > depends : base
toUpperString :: String -> String
toUpperString = fmap Data.Char.toUpper

-- | Synonym for 'fmap Data.Char.toLower'
-- > category : String
-- > depends : base
toLowerString :: String -> String
toLowerString = fmap Data.Char.toLower

-- | Convert a string to use upper case for the leading letter and lower case for remaining letters.
-- > category : String
-- > depends : base
toCapitalString :: String -> String
toCapitalString [] = []
toCapitalString (x:xs) = toUpperChar x : toLowerString xs

-- | Synonym for '(++)'
-- > category : List
-- > depends : base
withPrefix :: [a] -> [a] -> [a]
withPrefix x = (x ++)

-- | Synonym for 'flip (++)'
-- > category : List
-- > depends : base
withSuffix :: [a] -> [a] -> [a]
withSuffix x = (++ x)

-- | Separate a list by the given element. Equivalent to 'Data.List.intersperse'.
-- > category : List
-- > depends : base
sep :: a -> [a] -> [a]
sep = Data.List.intersperse

-- | Initiate and separate a list by the given element.
-- > category : List
-- > depends : base
pre :: a -> [a] -> [a]
pre x = (x :) . sep x

-- | Separate and terminate a list by the given element.
-- > category : List
-- > depends : base
post :: a -> [a] -> [a]
post x = withSuffix [x] . sep x

-- | Separate and terminate a list by the given element.
-- > category : List
-- > depends : base
wrap :: a -> a -> [a] -> [a]
wrap x y = (x :) . withSuffix [y] . sep x

-- | Combination of 'concat' and 'sep'.  Equivalent to 'Data.List.intercalate'.
-- > category : List
-- > depends : base
concatSep :: [a] -> [[a]] -> [a]
concatSep x = concat . sep x

-- | Combination of 'concat' and 'pre'.
-- > category : List
-- > depends : base
concatPre :: [a] -> [[a]] -> [a]
concatPre x = concat . pre x

-- | Combination of 'concat' and 'post'.
-- > category : List
-- > depends : base
concatPost :: [a] -> [[a]] -> [a]
concatPost x = concat . post x

-- | Combination of 'concat' and 'wrap'.
-- > category : List
-- > depends : base
concatWrap :: [a] -> [a] -> [[a]] -> [a]
concatWrap x y = concat . wrap x y

-- | Divide a list into parts of maximum length n.
-- > category : List
-- > depends : base
divideList :: Int -> [a] -> [[a]]
divideList n xs
    | length xs <= n = [xs]
    | otherwise = [take n xs] ++ (divideList n $ drop n xs)

-- | Group a list into sublists whereever a predicate holds. The matched element
--   is the first in the sublist.
--
--   > splitWhile isSpace "foo bar baz"
--   >    ===> ["foo"," bar"," baz"]
--   >
--   > splitWhile (> 3) [1,5,4,7,0,1,2]
--   >    ===> [[1],[5],[4],[7,0,1,2]]
--
-- > category : List
-- > depends : base
splitWhile :: (a -> Bool) -> [a] -> [[a]]
splitWhile p xs = case splitWhile' p xs of
    []:xss -> xss
    xss    -> xss
    where
        splitWhile' p []     = [[]]
        splitWhile' p (x:xs) = case splitWhile' p xs of
            (xs:xss) -> if p x then []:(x:xs):xss else (x:xs):xss


-- | Break up a list into parts of maximum length n, inserting the given list as separator.
--   Useful for breaking up strings, as in @breakList 80 "\n" str@.
--
-- > category : List
-- > depends : base
breakList :: Int -> [a] -> [a] -> [a]
breakList n z = Data.Monoid.mconcat . Data.List.intersperse z . divideList n

-- | Map over the indices and elements of list.
-- > category : List
-- > depends : base
mapIndexed :: (Int -> a -> b) -> [a] -> [b]
mapIndexed f as = map (uncurry f) (zip is as)
    where
        n  = length as - 1
        is = [0..n]
        
-- test

-- | Duplicate an element.
-- > category: Combinator, Tuple
-- > depends: base
dup :: a -> (a,a)
dup x = (x,x)

-- | Unfold a partial function. This is a simpler version of 'Data.List.unfoldr'. 
-- > category: Function, List
-- > depends: base
unf :: (a -> Maybe a) -> a -> [a]
unf f = Data.List.unfoldr (fmap dup . f)

-- |
-- Map over first elements of a list.
-- Biased on first element for shorter lists.
-- > category: List
-- > depends: base
mapF f = mapFTL f id id

-- |
-- Map over all but the first and last elements of a list.
-- Biased on middle elements for shorter lists.
-- > category: List
-- > depends: base
mapT f = mapFTL id f id

-- |
-- Map over last elements of a list.
-- Biased on last element for shorter lists.
-- > category: List
-- > depends: base
mapL f = mapFTL id id f

-- |
-- Map over first, middle and last elements of list.
-- Biased on first, then on first and last for short lists.
--
-- > category: List
-- > depends: base
mapFTL :: (a -> b) -> (a -> b) -> (a -> b) -> [a] -> [b]
mapFTL f g h = go
    where
        go []    = []
        go [a]   = [f a]
        go [a,b] = [f a, h b]
        go xs    = [f $ head xs]          ++ 
                   map g (tail $ init xs) ++ 
                   [h $ last xs]

-- |
-- Extract the first consecutive sublist for which the predicate returns true, or
-- the empty list if no such sublist exists.
-- > category: List
-- > depends: base
filterOnce :: (a -> Bool) -> [a] -> [a]
filterOnce p = Data.List.takeWhile p . Data.List.dropWhile (not . p)


-- | Returns all rotations of the given list. Given an infinite list, returns an infinite
-- list of rotated infinite lists.
-- > category: List
-- > depends: base
rots :: [a] -> [[a]]
rots xs = init (zipWith (++) (Data.List.tails xs) (Data.List.inits xs))

-- |
-- > category: List
-- > depends: base
rotl :: [a] -> [a]
rotl []     = []
rotl (x:xs) = xs ++ [x]

-- |
-- > category: List
-- > depends: base
rotr :: [a] -> [a]
rotr [] = []
rotr xs = last xs : init xs

-- |
-- > category: List
-- > depends: base
rotated :: Int -> [a] -> [a]
rotated = go
    where
        go n as 
            | n >= 0 = iterate rotr as !! n
            | n <  0 = iterate rotl as !! abs n


curry3 :: ((a, b, c) -> d) -> a -> b -> c -> d
curry3 = curry . curry . (. tripl)

uncurry3 :: (a -> b -> c -> d) -> (a, b, c) -> d
uncurry3 = (. untripl) . uncurry . uncurry

untripl :: (a,b,c) -> ((a,b),c)
untripl (a,b,c) = ((a,b),c)

tripl :: ((a,b),c) -> (a,b,c)
tripl ((a,b),c) = (a,b,c)

tripr :: (a,(b,c)) -> (a,b,c)
tripr (a,(b,c)) = (a,b,c)

-- | Case matching on lists.
-- > category: List
-- > depends: base
list :: r -> ([a] -> r) -> [a] -> r
list z f [] = z
list z f xs = f xs

-- | Merge lists.
-- > category: List
-- > depends: base
merge :: Ord a => [a] -> [a] -> [a]
merge = mergeBy compare

-- | Merge lists.
-- > category: List
-- > depends: base
mergeBy :: (a -> a -> Ordering) -> [a] -> [a] -> [a]
mergeBy f = mergeBy' $ (fmap.fmap) orderingToBool f
    where
        orderingToBool LT = True
        orderingToBool EQ = True
        orderingToBool GT = False

mergeBy' :: (a -> a -> Bool) -> [a] -> [a] -> [a]
mergeBy' pred xs []         = xs
mergeBy' pred [] ys         = ys
mergeBy' pred (x:xs) (y:ys) =
    case pred x y of
        True  -> x: mergeBy' pred xs (y:ys)
        False -> y: mergeBy' pred (x:xs) ys

-- | Compose all functions.
-- > category: Function
-- > depends: base
composed :: [b -> b] -> b -> b
composed = Prelude.foldr (.) id

-- | Separate a ratio.
-- > category: Math
-- > depends: base
unRatio :: Integral a => Data.Ratio.Ratio a -> (a, a)
unRatio x = (Data.Ratio.numerator x, Data.Ratio.denominator x)

-- | Nicer printing of ratio as ordinary fractions.
-- > category: Math
-- > depends: base
showRatio :: (Integral a, Show a) => Data.Ratio.Ratio a -> String
showRatio (realToFrac -> (unRatio -> (x, 1))) = show x
showRatio (realToFrac -> (unRatio -> (x, y))) = "(" ++ show x ++ "/" ++ show y ++ ")"


-- Replace all contigous ranges of equal values with [Just x, Nothing, Nothing ...]
-- > category: List
-- > depends: base
retainUpdates :: Eq a => [a] -> [Maybe a]
retainUpdates = snd . Data.List.mapAccumL g Nothing where
    g Nothing  x = (Just x, Just x)
    g (Just p) x = (Just x, if p == x then Nothing else Just x)


-- Generic version of 'replicate'.
-- > category: List
-- > depends: base
replic :: Integral a => a -> b -> [b]
replic n = replicate (fromIntegral n)

-- Swap components.
-- > category: Tuple
-- > depends: base
swap :: (a, b) -> (b, a)
swap (x, y) = (y, x)

-- Interleave a list with the next consecutive element.
--
-- For any xs
--
-- > lenght xs == length (withNext xs)
--
-- If @xs@ is a finite list
--
-- > isNothing  $ snd $ last $ withNext xs == True
-- > all isJust $ snd $ init $ withNext xs == True
--
-- If @xs@ is an infinite list
--
-- > all isJust $ snd $ withNext xs == True
--
-- > category: List
-- > depends: base
withNext :: [a] -> [(a, Maybe a)]
withNext = go
    where
        go []       = []
        go [x]      = [(x, Nothing)]
        go (x:y:rs) = (x, Just y) : withNext (y : rs)

-- Map over a list with the next consecutive element.
--
-- > category: List
-- > depends: base
mapWithNext :: (a -> Maybe a -> b) -> [a] -> [b]
mapWithNext f = fmap (uncurry f) . withNext
