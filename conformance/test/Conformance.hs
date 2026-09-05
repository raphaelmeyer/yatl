{-# LANGUAGE OverloadedStrings #-}

module Conformance (discover, spec, Tests (..)) where

import qualified Control.Monad as Monad
import qualified Data.List as List
import qualified Data.Text as Text
import qualified Runner
import qualified System.Directory as Directory
import qualified System.FilePath as SysFP
import Test.Hspec

data Tests
  = TestCase {caseName :: FilePath, caseDirectory :: FilePath}
  | Group {groupName :: FilePath, groupChildren :: [Tests]}
  deriving (Eq, Show)

discover :: FilePath -> IO [Tests]
discover root = do
  entries <- List.sort <$> Directory.listDirectory root
  dirs <- Monad.filterM (Directory.doesDirectoryExist . (root SysFP.</>)) entries
  Monad.forM dirs $ \name -> do
    let path = root SysFP.</> name
    subdirs <- Monad.filterM (Directory.doesDirectoryExist . (path SysFP.</>)) =<< Directory.listDirectory path
    if null subdirs
      then pure (TestCase name path)
      else Group name <$> discover path

spec :: Tests -> Spec
spec (Group name children) = describe name (mapM_ spec children)
spec (TestCase name dir) = it name $ do
  result <- Runner.run dir
  case result of
    Right outcome ->
      case outcome of
        Runner.Success stdout -> Text.lines stdout `shouldBe` expectedOutput name
        other -> expectationFailure (show other)
    Left err -> expectationFailure (show err)

expectedOutput :: FilePath -> [Text.Text]
expectedOutput "hello" = ["foo"]
expectedOutput name = error ("no expected output registered for case " ++ name)
