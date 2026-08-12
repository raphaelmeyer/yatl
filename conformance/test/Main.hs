module Main where

import qualified Conformance
import Test.Hspec

main :: IO ()
main = hspec $ do
  tests <- runIO (Conformance.discover "cases")
  mapM_ Conformance.spec tests
