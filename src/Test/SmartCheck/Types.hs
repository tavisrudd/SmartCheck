{-# LANGUAGE ExistentialQuantification #-} 

module Test.SmartCheck.Types
  ( SubT(..)
  , subT
  , SubTypes(..)
  , Idx(..)
  , Subst(..)
  ) where

import Data.Tree
import Data.Data
import qualified Test.QuickCheck as Q

---------------------------------------------------------------------------------
-- User-defined subtypes of data
---------------------------------------------------------------------------------

data SubT = forall a. (Data a, Q.Arbitrary a, Show a) 
          => SubT { unSubT :: a }

instance Show SubT where
  show (SubT t) = show t

subT :: (Data a, Q.Arbitrary a, Show a) => a -> SubT
subT = SubT

class (Eq a, Data a) => SubTypes a where
  subTypes :: a -> Forest SubT

---------------------------------------------------------------------------------
-- Indexing
---------------------------------------------------------------------------------

-- | Index into a Tree/Forest, where level is the depth from the root and column
-- is the distance d is the dth value on the same level.  Thus, all left-most
-- nodes are in column 0.  This is a "matrix view" of tree-structured data.
data Idx = Idx { level :: Int, column :: Int }
  deriving (Show, Eq, Read)

-- | Keep or substitue a value in the tree.
data Subst = Keep | Subst
  deriving (Show, Eq, Read)

---------------------------------------------------------------------------------
