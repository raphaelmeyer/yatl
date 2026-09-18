{-# LANGUAGE OverloadedStrings #-}

module Conformance (discover, spec, Test (..)) where

import qualified Annotations
import qualified Control.Monad as Monad
import qualified Data.List as List
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import qualified Runner
import qualified System.Directory as Directory
import qualified System.FilePath as SysFP
import Test.Hspec

data Test
  = TestCase {caseName :: FilePath, caseDirectory :: FilePath, caseEntryFile :: FilePath}
  | Group {groupName :: FilePath, groupChildren :: [Test]}
  deriving (Eq, Show)

discover :: FilePath -> IO [Test]
discover root = do
  entries <- List.sort <$> Directory.listDirectory root
  dirs <- Monad.filterM (Directory.doesDirectoryExist . (root SysFP.</>)) entries
  Monad.forM dirs $ \name -> do
    let path = root SysFP.</> name
    children <- List.sort <$> Directory.listDirectory path
    subdirs <- Monad.filterM (Directory.doesDirectoryExist . (path SysFP.</>)) children
    if null subdirs
      then TestCase name path <$> findEntryFile path children
      else Group name <$> discover path

findEntryFile :: FilePath -> [FilePath] -> IO FilePath
findEntryFile directory entries =
  case filter ((== ".yatl") . SysFP.takeExtension) entries of
    [file] -> pure (directory SysFP.</> file)
    [] -> fail ("no .yatl file in " ++ directory)
    files -> fail ("expected exactly one .yatl file in " ++ directory ++ ", found " ++ show files)

spec :: Test -> Spec
spec (Group name children) = describe name (mapM_ spec children)
spec (TestCase name dir entryFile) = it name $ do
  result <- Runner.run dir entryFile
  case result of
    Right outcome ->
      case outcome of
        Runner.Success stdout -> do
          expected <- Annotations.expectedOutput <$> TextIO.readFile entryFile
          Text.lines stdout `shouldBe` expected
        other -> expectationFailure (show other)
    Left err -> expectationFailure (show err)
