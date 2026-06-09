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

scanToken :: State.State Scanner (ScanResult Token.Token)
scanToken = do
  maybeC <- advance
  case maybeC of
    Nothing -> eof
    Just c -> case c of
      '(' -> simpleToken Token.LeftParen
      ')' -> simpleToken Token.RightParen
      _ -> unexpectedCharacter c

simpleToken :: Token.Token -> State.State Scanner (ScanResult Token.Token)
simpleToken = pure . Right

advance :: State.State Scanner (Maybe Char.Char)
advance = do
  s <- State.get
  case Text.uncons (scanSource s) of
    Nothing -> pure Nothing
    Just (c, rest) -> do
      State.put s {scanSource = rest}
      pure $ Just c

eof :: State.State Scanner (ScanResult Token.Token)
eof = pure . Right $ Token.EOF

atEnd :: Scanner -> Bool
atEnd scanner = Text.length (scanSource scanner) == 0

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
      Right tokens -> Right (token : tokens)

fromSource :: Text.Text -> Scanner
fromSource source = Scanner source (Error.Location 1 1)

makeError :: Text.Text -> State.State Scanner (ScanResult a)
makeError message = do
  s <- State.get
  pure . Left $ Error.ScanError message (scanLocation s)

unexpectedCharacter :: Char.Char -> State.State Scanner (ScanResult a)
unexpectedCharacter c = makeError . Text.pack $ "Unexpected character '" ++ [c] ++ "'."
