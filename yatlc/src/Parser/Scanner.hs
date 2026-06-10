module Parser.Scanner (scan, Result) where

import qualified Compiler.Error as Error
import qualified Control.Monad.State.Strict as State
import qualified Data.Char as Char
import qualified Data.Text as Text
import qualified Parser.Token as Token

type Result = Either [Error.Error] [Token.Token]

type ScanResult a = Either Error.Error a

data Scanner = Scanner
  { scanSource :: Text.Text,
    scanLocation :: Error.Location
  }

scan :: Text.Text -> Result
scan source = scanToEnd (fromSource source)

scanToken :: State.State Scanner (ScanResult (Maybe Token.Token))
scanToken = do
  maybeC <- advance
  case maybeC of
    Nothing -> eof
    Just c -> case c of
      '{' -> simpleToken Token.LeftBrace
      '}' -> simpleToken Token.RightBrace
      '(' -> simpleToken Token.LeftParen
      ')' -> simpleToken Token.RightParen
      '-' -> arrow
      ' ' -> whitespace
      '\n' -> newLine
      '\r' -> whitespace
      '\t' -> whitespace
      _ -> unexpectedCharacter c

simpleToken :: Token.Token -> State.State Scanner (ScanResult (Maybe Token.Token))
simpleToken = pure . Right . Just

arrow :: State.State Scanner (ScanResult (Maybe Token.Token))
arrow = do
  m <- match '>'
  if m
    then pure . Right . Just $ Token.Arrow
    else unexpectedCharacter '-'

whitespace :: State.State Scanner (ScanResult (Maybe Token.Token))
whitespace = pure . Right $ Nothing

newLine :: State.State Scanner (ScanResult (Maybe Token.Token))
newLine = do
  State.modify (\s -> s {scanLocation = nextLine . scanLocation $ s})
  pure . Right $ Nothing

match :: Char.Char -> State.State Scanner Bool
match m = do
  s <- State.get
  case Text.uncons (scanSource s) of
    Just (next, rest) | next == m -> do
      State.put s {scanSource = rest}
      pure True
    _ -> pure False

advance :: State.State Scanner (Maybe Char.Char)
advance = do
  s <- State.get
  case Text.uncons (scanSource s) of
    Nothing -> pure Nothing
    Just (c, rest) -> do
      State.put s {scanSource = rest, scanLocation = nextPosition (scanLocation s)}
      pure $ Just c

eof :: State.State Scanner (ScanResult (Maybe Token.Token))
eof = pure . Right $ Just Token.EOF

atEnd :: Scanner -> Bool
atEnd scanner = Text.length (scanSource scanner) == 0

nextPosition :: Error.Location -> Error.Location
nextPosition location = location {Error.locPos = Error.locPos location + 1}

nextLine :: Error.Location -> Error.Location
nextLine location = Error.Location {Error.locPos = 0, Error.locLine = Error.locLine location + 1}

scanToEnd :: Scanner -> Result
scanToEnd scanner
  | atEnd scanner = Right [Token.EOF]
  | otherwise = case State.runState scanToken scanner of
      (Left err, scanner') -> handleError err (scanToEnd scanner')
      (Right token, scanner') -> handleToken token (scanToEnd scanner')
  where
    handleError err result = case result of
      Left errors -> Left (err : errors)
      Right _ -> Left [err]
    handleToken token result = case result of
      Left errors -> Left errors
      Right tokens -> case token of
        Just t -> Right (t : tokens)
        Nothing -> Right tokens

fromSource :: Text.Text -> Scanner
fromSource source = Scanner source (Error.Location {Error.locLine = 1, Error.locPos = 0})

makeError :: Text.Text -> State.State Scanner (ScanResult a)
makeError message = do
  s <- State.get
  pure . Left $ Error.ScanError message (scanLocation s)

unexpectedCharacter :: Char.Char -> State.State Scanner (ScanResult a)
unexpectedCharacter c = makeError . Text.pack $ "Unexpected character '" ++ [c] ++ "'."
