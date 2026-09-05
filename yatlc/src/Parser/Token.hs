module Parser.Token where

import qualified Compiler.Location as Location
import qualified Data.Text as Text

data Token
  = -- Symbols
    Arrow
  | LeftBrace
  | LeftParen
  | RightBrace
  | RightParen
  | Semicolon
  | -- Keywords
    Function
  | Return
  | Void
  | -- Identifier/Literals
    Identifier Text.Text
  | -- End of input
    Eof
  deriving (Eq, Show)

type LocatedToken = Location.Located Token
