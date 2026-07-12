module Compiler.Error where

import qualified Compiler.Location as Location
import qualified Data.Text as Text

data Error
  = ScanError
      { eMessage :: Text.Text,
        eLocation :: Location.Location
      }
  | ParseError
      { eMessage :: Text.Text
      }
  deriving (Eq, Show)
