module Compiler.Location where

data Location = Location
  { locLine :: Int,
    locPos :: Int
  }
  deriving (Eq, Show)

data Located a = Located {item :: a, location :: Location}
  deriving (Eq, Show)
