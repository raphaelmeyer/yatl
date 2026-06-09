module Parser.Parser where

import qualified AST.AST as AST
import qualified Compiler.Error as Error
import qualified Control.Monad.State.Strict as State
import qualified Parser.Token as Token

type Result = Either [Error.Error] AST.Tree

newtype ParserState = ParserState
  { pTokens :: [Token.Token]
  }

parse :: [Token.Token] -> Result
parse tokens =
  Right . AST.Tree $
    State.evalState moduleDefinition (ParserState tokens)

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
