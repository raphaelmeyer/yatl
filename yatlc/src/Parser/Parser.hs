module Parser.Parser where

import qualified AST.AST as AST
import qualified Control.Monad.State.Strict as State
import qualified Data.Text as Text
import qualified Parser.Scanner as Scanner
import qualified Parser.Token as Token

newtype ParserState = ParserState
  { pTokens :: [Token.Token]
  }

parse :: Text.Text -> AST.Tree
parse source = case Scanner.scan source of
  Left _ -> AST.Tree []
  Right tokens -> parseTokens tokens

parseTokens :: [Token.Token] -> AST.Tree
parseTokens tokens = AST.Tree $ State.evalState moduleDefinition (ParserState tokens)

moduleDefinition :: State.State ParserState [AST.Function]
moduleDefinition = do
  maybeFunction <- function
  case maybeFunction of
    Just func -> do
      functions <- moduleDefinition
      pure $ func : functions
    Nothing -> moduleDefinition

function :: State.State ParserState (Maybe AST.Function)
function = do
  pure $ Just AST.Function
