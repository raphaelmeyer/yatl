module Parser.Scanner (scan, Result) where

import qualified Compiler.Error as Error
import qualified Control.Monad.State.Strict as State
import qualified Data.Char as Char
import qualified Data.Text as Text
import qualified Parser.Token as Token

type Result = Either [Error.Error] [Token.Token]

data ScannerState = ScannerState
  { scanSource :: Text.Text,
    scanLocation :: Error.Location,
    scanTokens :: [Token.Token],
    scanErrors :: [Error.Error]
  }

type Scanner a = State.State ScannerState a

scan :: Text.Text -> Result
scan source =
  let s = State.execState scanToEnd (fromSource source)
   in if null (scanErrors s)
        then Right . reverse $ scanTokens s
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
    Just c -> case c of
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

simpleToken :: Token.Token -> Scanner ()
simpleToken = emit

arrow :: Scanner ()
arrow = do
  m <- match '>'
  if m
    then emit Token.Arrow
    else unexpectedCharacter '-'

whitespace :: Scanner ()
whitespace = skip

newLine :: Scanner ()
newLine = do
  State.modify (\s -> s {scanLocation = nextLine . scanLocation $ s})

identifier :: Char.Char -> Scanner ()
identifier first = do
  remaining <- alphaNumeric
  let ident = Text.cons first remaining
  case Text.unpack ident of
    "fn" -> emit Token.Function
    "return" -> emit Token.Return
    "void" -> emit Token.Void
    _ -> emit $ Token.Identifier ident

alphaNumeric :: Scanner Text.Text
alphaNumeric = do
  source <- State.gets scanSource
  let (matched, remaining) = Text.break notAlphaNumeric source
  State.modify (\s -> s {scanSource = remaining})
  pure matched
  where
    notAlphaNumeric c = not ((Char.isAscii c && Char.isAlpha c) || Char.isDigit c)

emit :: Token.Token -> Scanner ()
emit token = State.modify (\s -> s {scanTokens = token : scanTokens s})

skip :: Scanner ()
skip = pure ()

match :: Char.Char -> Scanner Bool
match m = do
  s <- State.get
  case Text.uncons (scanSource s) of
    Just (next, rest) | next == m -> do
      State.put s {scanSource = rest}
      pure True
    _ -> pure False

advance :: Scanner (Maybe Char.Char)
advance = do
  s <- State.get
  case Text.uncons (scanSource s) of
    Nothing -> pure Nothing
    Just (c, rest) -> do
      State.put s {scanSource = rest, scanLocation = nextPosition (scanLocation s)}
      pure $ Just c

atEnd :: ScannerState -> Bool
atEnd scanner = Text.null (scanSource scanner)

data LetterCategory = Alpha | Digit | Other

letter :: Char.Char -> LetterCategory
letter c
  | Char.isAlpha c && Char.isAscii c = Alpha
  | Char.isDigit c = Digit
  | otherwise = Other

nextPosition :: Error.Location -> Error.Location
nextPosition location = location {Error.locPos = Error.locPos location + 1}

nextLine :: Error.Location -> Error.Location
nextLine location = Error.Location {Error.locPos = 0, Error.locLine = Error.locLine location + 1}

fromSource :: Text.Text -> ScannerState
fromSource source =
  ScannerState
    { scanSource = source,
      scanLocation = (Error.Location {Error.locLine = 1, Error.locPos = 0}),
      scanTokens = [],
      scanErrors = []
    }

unexpectedCharacter :: Char.Char -> Scanner ()
unexpectedCharacter c = addError . Text.pack $ "Unexpected character '" ++ [c] ++ "'."

addError :: Text.Text -> Scanner ()
addError message = do
  State.modify (\s -> s {scanErrors = Error.ScanError message (scanLocation s) : scanErrors s})
