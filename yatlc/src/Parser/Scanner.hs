module Parser.Scanner (scan, Result) where

import qualified Compiler.Error as Error
import qualified Compiler.Location as Location
import qualified Control.Monad.State.Strict as State
import qualified Data.Char as Char
import qualified Data.Text as Text
import qualified Parser.Token as Token

type Result = Either [Error.Error] [Token.LocatedToken]

data ScannerState = ScannerState
  { scanSource :: Text.Text,
    scanPosition :: Location.Location,
    scanTokens :: [Token.LocatedToken],
    scanErrors :: [Error.Error]
  }

type Scanner a = State.State ScannerState a

scan :: Text.Text -> Result
scan source =
  let s = State.execState scanToEnd (fromSource source)
      eof = Location.Located Token.Eof (nextPosition (scanPosition s))
   in if null (scanErrors s)
        then Right . reverse $ eof : scanTokens s
        else Left . reverse $ scanErrors s

scanToEnd :: Scanner ()
scanToEnd = do
  s <- State.get
  if atEnd s
    then pure ()
    else scanToken >> scanToEnd

scanToken :: Scanner ()
scanToken = do
  maybeC <- advance
  case maybeC of
    Nothing -> pure ()
    Just c -> do
      location <- State.gets scanPosition
      maybeToken <- case c of
        '{' -> simpleToken Token.LeftBrace
        '}' -> simpleToken Token.RightBrace
        '(' -> simpleToken Token.LeftParen
        ')' -> simpleToken Token.RightParen
        ';' -> simpleToken Token.Semicolon
        '-' -> arrow
        ' ' -> whitespace
        '\n' -> newLine
        '\r' -> whitespace
        '\t' -> whitespace
        _ -> case letter c of
          Alpha -> identifier c
          _ -> unexpectedCharacter c
      case maybeToken of
        Just token -> emit token location
        Nothing -> pure ()

simpleToken :: Token.Token -> Scanner (Maybe Token.Token)
simpleToken = pure . Just

arrow :: Scanner (Maybe Token.Token)
arrow = do
  m <- match '>'
  if m
    then pure (Just Token.Arrow)
    else unexpectedCharacter '-'

whitespace :: Scanner (Maybe Token.Token)
whitespace = skip

newLine :: Scanner (Maybe Token.Token)
newLine = do
  State.modify (\s -> s {scanPosition = nextLine . scanPosition $ s})
  pure Nothing

identifier :: Char.Char -> Scanner (Maybe Token.Token)
identifier first = do
  remaining <- advanceWhile alphaNumeric
  let ident = Text.cons first remaining
  pure . Just $ case Text.unpack ident of
    "fn" -> Token.Function
    "return" -> Token.Return
    "void" -> Token.Void
    _ -> Token.Identifier ident

alphaNumeric :: Char.Char -> Bool
alphaNumeric c =
  (Char.isAscii c && Char.isAlpha c)
    || Char.isDigit c
    || c == '_'

emit :: Token.Token -> Location.Location -> Scanner ()
emit token location = do
  let locatedToken = Location.Located token location
  State.modify (\s -> s {scanTokens = locatedToken : scanTokens s})

skip :: Scanner (Maybe Token.Token)
skip = pure Nothing

match :: Char.Char -> Scanner Bool
match m = do
  s <- State.get
  case Text.uncons (scanSource s) of
    Just (next, rest) | next == m -> do
      State.put s {scanSource = rest, scanPosition = nextPosition (scanPosition s)}
      pure True
    _ -> pure False

advance :: Scanner (Maybe Char.Char)
advance = do
  s <- State.get
  case Text.uncons (scanSource s) of
    Nothing -> pure Nothing
    Just (c, rest) -> do
      State.put s {scanSource = rest, scanPosition = nextPosition (scanPosition s)}
      pure $ Just c

advanceWhile :: (Char.Char -> Bool) -> Scanner Text.Text
advanceWhile condition = do
  s <- State.get
  let (matched, remaining) = Text.break (not . condition) (scanSource s)
      newPosition = advancePosition (Text.length matched) (scanPosition s)
  State.put s {scanSource = remaining, scanPosition = newPosition}
  pure matched

atEnd :: ScannerState -> Bool
atEnd scanner = Text.null (scanSource scanner)

data LetterCategory = Alpha | Digit | Other

letter :: Char.Char -> LetterCategory
letter c
  | Char.isAlpha c && Char.isAscii c = Alpha
  | Char.isDigit c = Digit
  | otherwise = Other

nextPosition :: Location.Location -> Location.Location
nextPosition position = position {Location.locPos = Location.locPos position + 1}

nextLine :: Location.Location -> Location.Location
nextLine location = Location.Location {Location.locPos = 0, Location.locLine = Location.locLine location + 1}

advancePosition :: Int -> Location.Location -> Location.Location
advancePosition steps position = position {Location.locPos = Location.locPos position + steps}

fromSource :: Text.Text -> ScannerState
fromSource source =
  ScannerState
    { scanSource = source,
      scanPosition = Location.Location {Location.locLine = 1, Location.locPos = 0},
      scanTokens = [],
      scanErrors = []
    }

unexpectedCharacter :: Char.Char -> Scanner (Maybe Token.Token)
unexpectedCharacter c = do
  addError . Text.pack $ "Unexpected character '" ++ [c] ++ "'."
  pure Nothing

addError :: Text.Text -> Scanner ()
addError message = do
  location <- State.gets scanPosition
  State.modify (\s -> s {scanErrors = Error.ScanError message location : scanErrors s})
