{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# OPTIONS_GHC -Wno-unused-top-binds #-}
module Build.Trace (
    -- * Verifying traces
    VT, recordVT, recordVT', verifyVT,

    -- * Constructive traces
    CT, recordCT, recordCT', verifyCT, constructCT,

    -- * Constructive traces optimised for deterministic tasks
    CTD, recordCTD, verifyCTD, constructCTD
    ) where

import Build.Store

import Control.Monad.Extra
import Data.Map (Map)
import Data.Semigroup

import qualified Data.Map as Map

data Trace k v = Trace
    { key     :: k
    , depends :: [(k, Hash v)]
    , result  :: Hash v }

-- | An abstract data type for a set of verifying traces equipped with 'record',
-- 'verify' and a 'Monoid' instance.
newtype VT k v = VT [Trace k v] deriving (Monoid, Semigroup)

-- | Record a new trace for building a @key@ with dependencies @deps@, obtaining
-- the hashes of up-to-date values from the given @store@.
recordVT :: Hashable v => Store i k v -> k -> [k] -> VT k v
recordVT store key deps = VT [Trace key [ (k, getHash k store) | k <- deps ] (getHash key store)]

recordVT' :: Monad m => (k -> m (Hash v)) -> k -> [k] -> m (VT k v)
recordVT' fetchHash key deps = do
    hs <- mapM fetchHash deps
    h  <- fetchHash key
    return $ VT [Trace key (zip deps hs) h]

-- | Given a function to compute the hash of a key's current value,
-- a @key@, and a set of verifying traces, return 'True' if the @key@ is
-- up-to-date.
verifyVT :: (Monad m, Eq k, Eq v) => (k -> m (Hash v)) -> k -> VT k v -> m Bool
verifyVT fetchHash key (VT ts) = anyM match ts
  where
    match (Trace k deps result)
        | k /= key  = return False
        | otherwise = andM [ (h==) <$> fetchHash k | (k, h) <- (key, result) : deps ]

data CT k v = CT
    { traces    :: VT k v
    , contents  :: Map (Hash v) v }

instance Ord v => Semigroup (CT k v) where
    CT t1 c1 <> CT t2 c2 = CT (t1 <> t2) (Map.union c1 c2)

instance Ord v => Monoid (CT k v) where
    mempty  = CT mempty Map.empty
    mappend = (<>)

recordCT :: Hashable v => Store i k v -> k -> [k] -> CT k v
recordCT store key deps = CT (recordVT store key deps) (Map.singleton (getHash key store) (getValue key store))

recordCT' :: (Hashable v, Monad m) => (k -> m v) -> k -> [k] -> m (CT k v)
recordCT' fetch key deps = do
    hs <- mapM (fmap hash . fetch) deps
    h  <- hash <$> fetch key
    v  <- fetch key
    return $ CT (VT [Trace key (zip deps hs) h]) (Map.singleton h v)

verifyCT :: (Monad m, Eq k, Eq v) => (k -> m (Hash v)) -> k -> CT k v -> m Bool
verifyCT fetchHash key (CT ts _) = verifyVT fetchHash key ts

constructCT :: (Monad m, Eq k, Ord v) => (k -> m (Hash v)) -> k -> CT k v -> m (Maybe v)
constructCT fetchHash key (CT (VT ts) cache) = firstJustM match ts
  where
    match (Trace k deps result) = do
        sameInputs <- andM [ (h==) <$> fetchHash k | (k, h) <- deps ]
        if k /= key || not sameInputs
            then return Nothing
            else return (Map.lookup result cache)

newtype CTD k v = CTD (Map (Hash (k, [Hash v])) v)

instance (Ord k, Ord v) => Semigroup (CTD k v) where
    CTD c1 <> CTD c2 = CTD (Map.union c1 c2)

instance (Ord k, Ord v) => Monoid (CTD k v) where
    mempty  = CTD Map.empty
    mappend = (<>)

recordCTD :: (Hashable k, Hashable v) => Store i k v -> k -> [k] -> CTD k v
recordCTD store key deps = CTD (Map.singleton h (getValue key store))
  where
    h = hash (key, (map (flip getHash store) deps))

verifyCTD :: (Hashable k, Hashable v, Monad m)
          => (k -> m (Hash v)) -> k -> [k] -> CTD k v -> m Bool
verifyCTD fetchHash key deps ctd = do
    maybeValue <- constructCTD fetchHash key deps ctd
    case maybeValue of
        Nothing    -> return False
        Just value -> (hash value ==) <$> fetchHash key

constructCTD :: (Hashable k, Hashable v, Monad m)
             => (k -> m (Hash v)) -> k -> [k] -> CTD k v -> m (Maybe v)
constructCTD fetchHash key deps (CTD cache) = do
    hs <- mapM fetchHash deps
    return (Map.lookup (hash (key, hs)) cache)
