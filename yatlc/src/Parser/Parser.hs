module Parser.Parser where

import qualified AST.AST as AST
import qualified Control.Monad.State.Strict as State
import qualified Data.Text as Text

data ParserState = ParserState

parse :: Text.Text -> AST.Tree
parse _ = AST.Tree

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
