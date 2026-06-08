module Compiler.Options where

data Options = Options
  { buildDirectory :: FilePath,
    sourceFile :: FilePath
  }
  deriving (Show)
