{-# LANGUAGE OverloadedStrings #-}

module Parser.Parser where

import qualified AST.AST as AST
import qualified Compiler.Error as Error
import qualified Compiler.Location as Location
import qualified Data.List as List
import qualified Data.Text as Text
import qualified Parser.Token as Token

type Result = Either [Error.Error] AST.Tree

data State = State
  { psTokens :: [Token.LocatedToken],
    psErrors :: [Error.Error]
  }

newtype Parser a = Parser
  {runParser :: State -> (Either Error.Error a, State)}

instance Functor Parser where
  fmap f (Parser p) = Parser $ \s -> case p s of
    (Right a, s') -> (Right (f a), s')
    (Left e, s') -> (Left e, s')

instance Applicative Parser where
  pure a = Parser $ \s -> (Right a, s)
  Parser pf <*> Parser pa = Parser $ \s -> case pf s of
    (Left e, s') -> (Left e, s')
    (Right f, s') -> case pa s' of
      (Left e, s'') -> (Left e, s'')
      (Right a, s'') -> (Right (f a), s'')

instance Monad Parser where
  return = pure
  Parser p >>= f = Parser $ \s -> case p s of
    (Left e, s') -> (Left e, s')
    (Right a, s') -> runParser (f a) s'

parse :: [Token.LocatedToken] -> Result
parse tokens =
  let initialState = fromTokens tokens
      (result, finalState) = runParser moduleDefinition initialState
   in case result of
        Right functions -> Right (AST.Tree functions)
        Left err -> Left (err : psErrors finalState)

moduleDefinition :: Parser [AST.Function]
moduleDefinition = do
  token <- match (anyOf [Token.Function])
  case token of
    Just Token.Function -> do
      func <- function
      rest <- moduleDefinition
      pure (func : rest)
    _ -> do
      end <- atEnd
      if end
        then pure []
        else raise "Unexpected token."

function :: Parser AST.Function
function = do
  _ <- expect identifier "Expect function name."
  expectToken Token.LeftParen "Expect '('."
  expectToken Token.RightParen "Expect ')'."
  expectToken Token.Arrow "Expect '->'."
  expectToken Token.LeftBrace "Expect '{'."
  expectToken Token.RightBrace "Expect '}'."
  pure AST.Function

isToken :: Token.Token -> Token.Token -> Maybe ()
isToken expected token = if token == expected then Just () else Nothing

expectToken :: Token.Token -> Text.Text -> Parser ()
expectToken expected = expect (isToken expected)

raise :: Text.Text -> Parser a
raise message = Parser $ \s -> (Left (Error.ParseError message), s)

advance :: Parser (Maybe Token.LocatedToken)
advance = Parser $ \s -> case List.uncons (psTokens s) of
  Just (token, rest) -> (Right (Just token), s {psTokens = rest})
  Nothing -> (Right Nothing, s)

atEnd :: Parser Bool
atEnd = Parser $ \s -> (Right (null (psTokens s)), s)

expect :: (Token.Token -> Maybe a) -> Text.Text -> Parser a
expect check message = do
  token <- advance
  case token >>= check . Location.item of
    Just a -> pure a
    Nothing -> raise message

match :: (Token.Token -> Maybe a) -> Parser (Maybe a)
match check = Parser $ \state -> case psTokens state of
  [] -> (Right Nothing, state)
  (token : rest) -> case check . Location.item $ token of
    Just a -> (Right (Just a), state {psTokens = rest})
    Nothing -> (Right Nothing, state)

anyOf :: [Token.Token] -> Token.Token -> Maybe Token.Token
anyOf tokens token = if token `elem` tokens then Just token else Nothing

identifier :: Token.Token -> Maybe Text.Text
identifier (Token.Identifier name) = Just name
identifier _ = Nothing

fromTokens :: [Token.LocatedToken] -> State
fromTokens tokens =
  State
    { psTokens = tokens,
      psErrors = []
    }
