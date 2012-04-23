{-# LANGUAGE ScopedTypeVariables #-} 

-- | Interface module.

module Test.SmartCheck 
  ( smartCheck
  , SubT(..)
  , subT
  , SubTypes(..)
  , Tree(..)
  , Forest
  ) where

import Test.SmartCheck.Reduce
import Test.SmartCheck.Extrapolate
import Test.SmartCheck.Types
import Test.SmartCheck.Common

import qualified Test.QuickCheck as Q
import Data.Tree
import Data.Maybe

---------------------------------------------------------------------------------

-- | Main interface function.
smartCheck :: (Read a, Show a, Q.Arbitrary a, SubTypes a)
           => Q.Args -> (a -> Q.Property) -> IO ()
smartCheck args prop = smartCheck' prop []

  where
  smartCheck' prop' ds = do
    res <- runQC args prop'

    d <- smartRun args res prop
    if isNothing d then return ()
              -- Extrapolate with the original property to see if we get a
              -- previously-visited value back.
      else do mprop <- extrapolate args (fromJust d) prop prop' ds
              if isNothing mprop then return ()
                else do c <- continue
                        if c 
                          then smartCheck' (fromJust mprop) (fromJust d : ds)
                          else smartPrtLn "Done."

  continue = do putStrLn $ "Attempt to find a new counterexample?" 
                            ++ " ('Enter' to continue;"
                            ++ " any character then 'Enter' to quit.)"
                s <- getLine
                return (s == "")

---------------------------------------------------------------------------------

runQC :: forall a. (Show a, Read a, Q.Arbitrary a)
      => Q.Args -> (a -> Q.Property) -> IO (Maybe a)
runQC args prop = do
  let genProp = Q.forAllShrink Q.arbitrary Q.shrink prop
  res <- Q.quickCheckWithResult args genProp
  case res of
    -- XXX C'mon, QuickCheck, let me grab the result in a sane way rather than
    -- parsing a string!
    Q.Failure _ _ _ _ _ _ out -> do let ms = (lines out) !! 1 
                                    let m = (read ms) :: a
                                    return $ Just m
    _ -> return Nothing

---------------------------------------------------------------------------------
