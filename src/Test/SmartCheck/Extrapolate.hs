{-# LANGUAGE ScopedTypeVariables #-}

module Test.SmartCheck.Extrapolate
  ( extrapolate
  , matchesShapes
  ) where

import Test.SmartCheck.Types
import Test.SmartCheck.DataToTree
import Test.SmartCheck.SmartGen
import Test.SmartCheck.Render

import qualified Test.QuickCheck as Q

import Data.Tree
import Data.List

---------------------------------------------------------------------------------

-- | Test d with arbitrary values replacing its children.  For anything we get
-- 100% failure for, we claim we can generalize it---any term in that hole
-- fails.
--
-- We extrapolate if there exists at least one test that satisfies the
-- precondition, and for all tests that satisfy the precondition, they fail.

-- We extrapolate w.r.t. the original property since extrapolation throws away
-- any values that fail the precondition of the property (i.e., before the
-- Q.==>).
extrapolate :: SubTypes a
            => ScArgs            -- ^ Arguments
            -> a                 -- ^ Current failed value
            -> (a -> Q.Property) -- ^ Original property
            -> [a]               -- ^ Previous failed values
            -> IO ([Idx], PropRedux a)
extrapolate args d origProp ds = do 
  putStrLn ""
  smartPrtLn "Extrapolating values ..."
  idxs <- iter' (mkSubstForest d) (Idx 0 0) []
  return (idxs, prop idxs)

  where
  iter' = iter d test next origProp
      
  -- In this call to iterateArb, we want to claim we can extrapolate iff at
  -- least one test passes a precondition, and for every test in which the
  -- precondition is passed, it fails.  We test values of all possible sizes, up
  -- to Q.maxSize.
  test idx = iterateArb d idx 
               (Q.maxSuccess $ qcArgs args) 
               (Q.maxSize $ qcArgs args) 
               origProp
  next res forest idx idxs =
    case res of
      -- None of the tries satisfy prop.  Prevent recurring down this tree,
      -- since we can generalize (we do this with sub, which replaces the
      -- subForest with []).
      FailedProp -> iter' (forestReplaceChop forest idx Subst)
                      idx { column = column idx + 1 }
                      (idx : idxs)
      _          -> iter' forest
                      idx { column = column idx + 1 }
                      idxs

  prop idxs newProp a = 
    (not $ matchesShapes a (d : ds) idxs) Q.==> newProp a

---------------------------------------------------------------------------------

-- | Finds any two distinct values that match.  INVARIANT: the ds are all
-- unequal, and d /= any ds.
matchesShapes :: SubTypes a => a -> [a] -> [Idx] -> Bool
matchesShapes d ds idxs = foldl' f False ds
  where
  f True _   = True
  f False d' = matchesShape d d' idxs

-- | Are the value's constructors the same (for algebraic constructors only
-- (e.g., omits Int)), and all the direct children constructors the same (for
-- algebraic constructors only, while ignoring differences in all values at
-- holes indexed by the indexes.
matchesShape :: SubTypes a => a -> a -> [Idx] -> Bool
matchesShape a b idxs = test (subT a, subT b) && repIdxs 
  where
  repIdxs = case foldl' f (Just b) idxs of
              Nothing -> False
              Just b' -> and . map test $ zip (nextLevel a) (nextLevel b')

  f mb idx = do
    b' <- mb
    v  <- getAtIdx a idx
    replace b' idx v

  nextLevel x = map rootLabel (subTypes x)

  test (SubT x, SubT y)  = baseType x || toConstr x == toConstr y

---------------------------------------------------------------------------------
