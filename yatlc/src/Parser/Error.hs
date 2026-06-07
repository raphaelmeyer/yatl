module Parser.Error where

import qualified Data.Text as Text

data Location = Location
  { locLine :: Int,
    locPos :: Int
  }
  deriving (Eq, Show)

data Error
  = ScanError
      { eMessage :: Text.Text,
        eLocation :: Location
      }
  | ParseError
  deriving (Eq, Show)
