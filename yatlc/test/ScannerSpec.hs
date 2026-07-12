{-# LANGUAGE OverloadedStrings #-}

module ScannerSpec (spec) where

import qualified Compiler.Error as Error
import qualified Compiler.Location as Location
import qualified Parser.Scanner as Scanner
import qualified Parser.Token as Token
import Test.Hspec

spec :: Spec
spec = do
  describe "empty string" $ do
    it "should return an empty token list" $ do
      let result = Scanner.scan ""
      result `shouldBe` Right []

  describe "symbols" $ do
    it "should return the parsed single character symbol" $ do
      let result = map Location.item <$> Scanner.scan "({});"
      result `shouldBe` Right [Token.LeftParen, Token.LeftBrace, Token.RightBrace, Token.RightParen, Token.Semicolon]

    it "should parse composed symbols" $ do
      let result = map Location.item <$> Scanner.scan "->"
      result `shouldBe` Right [Token.Arrow]

  describe "keywords" $ do
    it "should parse keywords" $ do
      let result = map Location.item <$> Scanner.scan "fn return"
      result `shouldBe` Right [Token.Function, Token.Return]

  describe "identifiers" $ do
    it "should parse identifiers" $ do
      let result = map Location.item <$> Scanner.scan "fn return void"
      result `shouldBe` Right [Token.Function, Token.Return, Token.Void]

    it "should parse identifiers that include keywords as substrings" $ do
      let result = map Location.item <$> Scanner.scan "noreturn func fnfn"
      result `shouldBe` Right [Token.Identifier "noreturn", Token.Identifier "func", Token.Identifier "fnfn"]

  describe "white space" $ do
    it "should skip whitespace" $ do
      let result = map Location.item <$> Scanner.scan "\t\r\n { (\n \n } \r ) \n"
      result `shouldBe` Right [Token.LeftBrace, Token.LeftParen, Token.RightBrace, Token.RightParen]

  describe "location information" $ do
    it "should assign position 1 to the first token on a line" $ do
      let result = map Location.location <$> Scanner.scan "{"
      result `shouldBe` Right [Location.Location 1 1]

    it "should increment position for consecutive tokens" $ do
      let result = map Location.location <$> Scanner.scan "{}"
      result `shouldBe` Right [Location.Location 1 1, Location.Location 1 2]

    it "should count whitespace characters in position" $ do
      let result = map Location.location <$> Scanner.scan "  {"
      result `shouldBe` Right [Location.Location 1 3]

    it "should increment line on newline and reset position" $ do
      let result = map Location.location <$> Scanner.scan "\n{"
      result `shouldBe` Right [Location.Location 2 1]

    it "should record the position of the first character of multi-character tokens" $ do
      let result = map Location.location <$> Scanner.scan "->"
      result `shouldBe` Right [Location.Location 1 1]

    it "should record correct line and position" $ do
      let result = map Location.location <$> Scanner.scan "\n {"
      result `shouldBe` Right [Location.Location 2 2]

  describe "errors" $ do
    it "should catch unexpected characters" $ do
      let result = map Location.item <$> Scanner.scan "@"
      result
        `shouldBe` Left
          [ Error.ScanError "Unexpected character '@'." (Location.Location 1 1)
          ]

    it "should report correct position" $ do
      let result = map Location.item <$> Scanner.scan " ( ) @ { } "
      result
        `shouldBe` Left
          [ Error.ScanError "Unexpected character '@'." (Location.Location 1 6)
          ]

    it "should report correct line" $ do
      let result = map Location.item <$> Scanner.scan "\n{\n}\n@\n\n"
      result
        `shouldBe` Left
          [ Error.ScanError "Unexpected character '@'." (Location.Location 4 1)
          ]

    it "should report correct location" $ do
      let result = map Location.item <$> Scanner.scan "\r\t { \n } \n \r\t ( @ )\n\n"
      result
        `shouldBe` Left
          [ Error.ScanError "Unexpected character '@'." (Location.Location 3 7)
          ]
