module Parser.Token where

import qualified Data.Text as Text

data Token
  = -- Symbols
    LeftParen
  | RightParen
  | LeftBrace
  | RightBrace
  | Arrow
  | Semicolon
  | -- Keywords
    Function
  | Nil
  | -- Identifier/Literals
    Identifier Text.Text
  | --
    EOF
  deriving (Eq, Show)
