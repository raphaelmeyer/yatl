module Parser.Token where

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
  deriving (Eq, Show)
