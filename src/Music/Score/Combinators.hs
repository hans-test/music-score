                              
{-# LANGUAGE
    TypeFamilies,
    DeriveFunctor,
    DeriveFoldable,
    FlexibleInstances,
    OverloadedStrings,
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


module Music.Score.Combinators (
        -- ** Constructing scores
        rest,
        note,
        chord,
        melody,

        -- ** Composing scores
        (|>),
        (<|),
        scat,
        pcat,
        
        -- *** Special composition
        sustain,
        overlap,
        anticipate,
        
        -- ** Transforming scores
        -- *** Moving in time
        move,
        moveBack,
        startAt,
        stopAt,

        -- *** Stretching in time
        stretch,
        compress,
        stretchTo,
        
        -- ** Zipper
        apply,
        sample,
        trig,
        applySingle,
        sampleSingle, 
        
        -- *** Structure
        
        repTimes,
        repWith,
        repWithIndex,
        repWithTime,
        group,
        groupWith,
        scatMap,
        rev,     
        before,
        first,
        butFirst,

        
        -- ** Conversion
        scoreToTrack,
        scoreToVoice,
        scoreToVoices,
        voiceToScore,
        trackToScore,
  ) where

import Prelude hiding (foldr, concat, foldl, mapM, concatMap, maximum, sum, minimum)

import Control.Monad (ap, mfilter, join, liftM, MonadPlus(..))
import Data.Semigroup
import Data.String
import Data.Foldable
import Data.Traversable
import qualified Data.List as List
import Data.VectorSpace
import Data.AffineSpace
import Data.Ratio  
import Data.Ord

import Music.Score.Track
import Music.Score.Part
import Music.Score.Score
import Music.Score.Duration
import Music.Score.Time
import Music.Score.Ties
import Music.Score.Voice


-------------------------------------------------------------------------------------
-- Constructors
-------------------------------------------------------------------------------------

-- | Creates a score containing the given elements, composed in sequence.
melody :: [a] -> Score a
melody = scat . map note

-- | Creates a score containing the given elements, composed in parallel.
chord :: [a] -> Score a
chord = pcat . map note

-- | Creates a score from a the given melodies, composed in parallel.
melodies :: [[a]] -> Score a
melodies = pcat . map melody

-- | Creates a score from a the given chords, composed in sequence.
chords :: [[a]] -> Score a
chords = scat . map chord

-- | Like 'melody', but stretching each note by the given factors.
melodyStretch :: [(Duration, a)] -> Score a
melodyStretch = scat . map ( \(d, x) -> stretch d $ note x )

-- | Like 'chord', but delays each note the given amounts.
chordDelay :: [(Duration, a)] -> Score a
chordDelay = pcat . map ( \(t, x) -> delay t $ note x )

-- | Like 'chord', but delays and stretches each note the given amounts.
chordDelayStretch :: [(Duration, Duration, a)] -> Score a
chordDelayStretch = pcat . map ( \(t, d, x) -> delay t . stretch d $ note x )

-- -- | Like chord, but delaying each note the given amount.
-- arpeggio :: t -> [a] -> Score a
-- arpeggio t xs = chordDelay (zip [0, t ..] xs)


-------------------------------------------------------------------------------------
-- Transformations
-------------------------------------------------------------------------------------

-- |
-- Move a score move in time. Equivalent to 'delay'.
-- 
-- > Duration -> Score a -> Score a
-- 
move :: Delayable a => Duration -> a -> a
move = delay

-- |
-- Move a score moveBack in time. Negated verison of 'delay'
-- 
-- > Duration -> Score a -> Score a
-- 
moveBack :: Delayable a => Duration -> a -> a
moveBack t = delay (negate t)

-- |
-- Stretch a score. Equivalent to '*^'.
-- 
-- > Duration -> Score a -> Score a
-- 
stretch :: VectorSpace v => Scalar v -> v -> v
stretch = (*^)

-- |
-- Move a score to start at a specific time.
-- 
-- > Duration -> Score a -> Score a
-- 
startAt :: (Delayable a, HasOnset a) => Time -> a -> a
t `startAt` x = delay d x where d = t .-. onset x

-- |
-- Move a score to stop at a specific time.
-- 
-- > Duration -> Score a -> Score a
-- 
stopAt :: (Delayable a, HasOnset a) => Time -> a -> a
t `stopAt`  x = delay d x where d = t .-. offset x

-- |
-- Compress a score. Flipped version of '^/'.
-- 
-- > Duration -> Score a -> Score a
-- 
compress :: (VectorSpace v, s ~ Scalar v, Fractional s) => s -> v -> v
compress = flip (^/)

-- | 
-- Stretch to the given duration. 
-- 
-- > Duration -> Score a -> Score a
-- 
stretchTo :: (VectorSpace a, HasDuration a, Scalar a ~ Duration) => Duration -> a -> a
t `stretchTo` x = (t / duration x) `stretch` x 

 
-------------------------------------------------------------------------------------
-- Composition
-------------------------------------------------------------------------------------

infixr 6 |>
infixr 6 <|

-- |
-- Compose in sequence.
--
-- To compose in parallel, use '<>'.
--
-- > Score a -> Score a -> Score a
(|>) :: (Semigroup a, Delayable a, HasOnset a) => a -> a -> a
a |> b =  a <> startAt (offset a) b
-- a |< b =  a <> stopAt (onset a) b


-- |
-- Compose in reverse sequence. 
--
-- To compose in parallel, use '<>'.
--
-- > Score a -> Score a -> Score a
(<|) :: (Semigroup a, Delayable a, HasOnset a) => a -> a -> a
a <| b =  b |> a

-- |
-- Sequential concatentation.
--
-- > [Score t] -> Score t
scat :: (Monoid a, Delayable a, HasOnset a) => [a] -> a
scat = unwrapMonoid . foldr (|>) mempty . fmap WrapMonoid

-- |
-- Parallel concatentation. A synonym for 'mconcat'.
--
-- > [Score t] -> Score t
pcat :: Monoid a => [a] -> a
pcat = mconcat

-- infixr 7 <<|
-- infixr 7 |>>
-- infixr 7 <||
-- infixr 7 ||>

-- (<||) = sustain
-- (||>) = flip sustain
-- (|>>) = overlap
-- (<<|) = flip overlap    

-- | 
-- Like '<>', but scaling the second agument to the duration of the first.
-- 
-- > Score a -> Score a -> Score a
--
sustain :: (Semigroup a, VectorSpace a, HasDuration a, Scalar a ~ Duration) => a -> a -> a
x `sustain` y = x <> (duration x) `stretchTo` y

-- Like '<>', but truncating the second agument to the duration of the first.
-- prolong x y = x <> before (duration x) y

-- |
-- Like '|>', but moving second argument halfway to the offset of the first.
--
-- > Score a -> Score a -> Score a
--
overlap :: (Semigroup a, Delayable a, HasDuration a) => a -> a -> a
x `overlap` y  =  x <> delay t y where t = duration x / 2    

-- |
-- Like '|>' but with a negative delay on the second element.
-- 
-- > Duration -> Score a -> Score a -> Score a
-- 
anticipate :: (Semigroup a, Delayable a, HasDuration a, HasOnset a) => Duration -> a -> a -> a
anticipate t x y = x |> delay t' y where t' = (duration x - t) `max` 0


-------------------------------------------------------------------------------------
-- Analysis

apply :: (Ord v, v ~ Part a, HasPart a) => Voice (Score a -> Score b) -> Score a -> Score b
apply x = mapParts (fmap $ applySingle x)

sample :: (Ord v, v ~ Part a, HasPart a) => Score b -> Score a -> Score (b, Score a)
sample x = mapParts (fmap $ sampleSingle x)

trig :: Score a -> Score b -> Score b
trig p as = mconcat $ toList $ fmap snd $ sampleSingle p as

applySingle :: Voice (Score a -> Score b) -> Score a -> Score b
applySingle fs as = notJoin $ fmap (\(f,s) -> f s) $ sampled
    where            
        -- This is not join; we simply concatenate all inner scores in parallel
        notJoin = mconcat . toList
        sampled = sampleSingle (voiceToScore fs) as

-- |
-- Get all notes that start during a given note.
--
sampleSingle :: Score a -> Score b -> Score (a, Score b)
sampleSingle as bs = Score . fmap (\(t,d,a) -> (t,d,g a (onsetIn t d bs))) . getScore $ as
    where
        g Nothing  z = Nothing
        g (Just a) z = Just (a,z)


-- | Filter out events that has its onset in the given time interval (inclusive start).
--   For example, onset in 1 2 filters events such that (1 <= onset x < 3)
onsetIn :: Time -> Duration -> Score a -> Score a
onsetIn a b = Score . filt (\(t,d,x) -> a <= t && t < a .+^ b) . getScore 
    where
        -- filt = mfilter
        filt = takeUntil
        -- more lazy than mfilter
                                                                              
-- Take until predicate goes from True to False.
takeUntil :: (a -> Bool) -> [a] -> [a]
takeUntil p as = List.takeWhile p (List.dropWhile (not . p) as)


-------------------------------------------------------------------------------------
-- Conversion

-- |
-- Convert a score to a track by throwing away durations.
--
scoreToTrack :: Score a -> Track a
scoreToTrack = Track . fmap g . perform
    where
        g (t,d,x) = (t,x)

-- |
-- Convert a single-voice score to a voice.
--
scoreToVoice :: Score a -> Voice (Maybe a)
scoreToVoice = Voice . fmap g . addRests' . perform
    where
        g (t,d,x) = (d,x)

-- |
-- Convert a score to a list of voices.
--
scoreToVoices :: (HasPart a, Part a ~ v, Ord v) => Score a -> [Voice (Maybe a)]
scoreToVoices = fmap scoreToVoice . voices

-- |
-- Convert a voice to a score.
--
voiceToScore :: Voice a -> Score a
voiceToScore = scat . fmap g . getVoice
    where
        g (d,x) = stretch d (note x)

-- |
-- Convert a track to a score. Each note gets an arbitrary duration of one.
--
trackToScore :: Track a -> Score a
trackToScore = pcat . fmap g . getTrack
    where
        g (t,x) = delay (t .-. 0) (note x)


--------------------------------------------------------------------------------
-- Structure
--------------------------------------------------------------------------------

-- |
-- Repeat exact amount of times.
--
-- > Duration -> Score Note -> Score Note
--
repTimes :: (Enum a, Monoid c, HasOnset c, Delayable c) => a -> c -> c
repTimes n a = replicate (0 `max` fromEnum n) () `repWith` (const a)

-- |
-- Repeat once for each element in the list.
--
-- > [a] -> (a -> Score Note) -> Score Note
--
-- Example:
--
-- > repWith [1,2,1] (c^*)
--
repWith :: (Monoid c, HasOnset c, Delayable c) => [a] -> (a -> c) -> c
repWith = flip (\f -> scat . fmap f)

-- |
-- Combination of 'scat' and 'fmap'. Note that
--
-- > scatMap = flip repWith
--
scatMap f = scat . fmap f

-- |
-- Repeat exact amount of times with an index.
--
-- > Duration -> (Duration -> Score Note) -> Score Note
--
repWithIndex :: (Enum a, Num a, Monoid c, HasOnset c, Delayable c) => a -> (a -> c) -> c
repWithIndex n = repWith [0..n-1]

-- |
-- Repeat exact amount of times with relative time.
--
-- > Duration -> (Time -> Score Note) -> Score Note
--
repWithTime :: (Enum a, Fractional a, Monoid c, HasOnset c, Delayable c) => a -> (a -> c) -> c
repWithTime n = repWith $ fmap (/ n') [0..(n' - 1)]
    where
        n' = n

-- |
-- Repeat a number of times and scale down by the same amount.
--
-- > Duration -> Score a -> Score a
--
group :: (Enum a, Fractional a, a ~ Scalar c, Monoid c, Semigroup c, VectorSpace c, HasOnset c, Delayable c) => a -> c -> c
group n a = repTimes n (a^/n)

-- |
-- Repeat a number of times and scale down by the same amount.
--
-- > [Duration] -> Score a -> Score a
--
groupWith :: (Enum a, Fractional a, a ~ Scalar c, Monoid c, Semigroup c, VectorSpace c, HasOnset c, Delayable c) => [a] -> c -> c
groupWith = flip $ \p -> scat . fmap (flip group $ p)

-- |
-- Reverse a score around its middle point.
--
-- > onset a    = onset (rev a)
-- > duration a = duration (rev a)
-- > offset a   = offset (rev a)
--
rev :: Score a -> Score a
rev = startAt 0 . rev'
    where
        rev' = Score . List.sortBy (comparing getT) . fmap g . getScore
        g (t,d,x) = (-(t.+^d),d,x)
        getT (t,d,x) = t

-- |
-- Repeat indefinately, like repeat for lists.
--
-- > Score Note -> Score Note
--
rep :: Score a -> Score a
rep a = a `plus` delay (duration a) (rep a)
    where
        Score as `plus` Score bs = Score (as <> bs)


infixl 6 ||>
a ||> b = padToBar a |> b
bar = rest^*4

padToBar a = a |> (rest ^* (d' * 4))
    where
        d  = snd $ properFraction $ duration a / 4
        d' = if (d == 0) then 0 else (1-d)


rotl []     = []
rotl (x:xs) = xs ++ [x]

rotr [] = []
rotr xs = (last xs:init xs)

rotated n as | n >= 0 = iterate rotr as !! n
             | n <  0 = iterate rotl as !! (abs n)



before :: Duration -> Score a -> Score a
before d = trig (on^*d)

first :: Score a -> a
first = get3 . head . perform
    where get3 (a,b,c) = c

butFirst :: Score a -> Score a
butFirst = Score . tail . getScore

on :: Score ()
on = note ()

off :: Score ()
off = rest


tau = pi*2

splitWhile :: (a -> Bool) -> [a] -> [[a]]
splitWhile p xs = case splitWhile' p xs of
    []:xss -> xss
    xss    -> xss
    where
        splitWhile' p []     = [[]]
        splitWhile' p (x:xs) = case splitWhile' p xs of
            (xs:xss) -> if p x then []:(x:xs):xss else (x:xs):xss  









-- FIXME consolidate
addRests' :: [(Time, Duration, a)] -> [(Time, Duration, Maybe a)]
addRests' = concat . snd . mapAccumL g 0
    where
        g prevTime (t, d, x) 
            | prevTime == t   =  (t .+^ d, [(t, d, Just x)])
            | prevTime <  t   =  (t .+^ d, [(prevTime, t .-. prevTime, Nothing), (t, d, Just x)])
            | otherwise       =  error "addRests: Strange prevTime"
