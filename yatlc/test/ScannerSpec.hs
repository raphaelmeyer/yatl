{-# LANGUAGE OverloadedStrings #-}

module ScannerSpec (spec) where

import qualified Compiler.Error as Error
import qualified Parser.Scanner as Scanner
import qualified Parser.Token as Token
import Test.Hspec

spec :: Spec
spec = do
  describe "empty string" $ do
    it "should return eof token" $ do
      let result = Scanner.scan ""
      result `shouldBe` Right [Token.EOF]

  describe "symbols" $ do
    it "should return the parsed single character symbol" $ do
      let result = Scanner.scan "({});"
      result `shouldBe` Right [Token.LeftParen, Token.LeftBrace, Token.RightBrace, Token.RightParen, Token.Semicolon, Token.EOF]

    it "should parse composed symbols" $ do
      let result = Scanner.scan "->"
      result `shouldBe` Right [Token.Arrow, Token.EOF]

  describe "keywords" $ do
    it "should parse keywords" $ do
      let result = Scanner.scan "fn return"
      result `shouldBe` Right [Token.Function, Token.Return, Token.EOF]

  describe "identifiers" $ do
    it "should parse identifiers" $ do
      let result = Scanner.scan "fn return void"
      result `shouldBe` Right [Token.Function, Token.Return, Token.Void, Token.EOF]

    it "should parse identifiers that include keywords as substrings" $ do
      let result = Scanner.scan "noreturn func fnfn"
      result `shouldBe` Right [Token.Identifier "noreturn", Token.Identifier "func", Token.Identifier "fnfn", Token.EOF]

  describe "white space" $ do
    it "should skip whitespace" $ do
      let result = Scanner.scan "\t\r\n { (\n \n } \r ) \n"
      result `shouldBe` Right [Token.LeftBrace, Token.LeftParen, Token.RightBrace, Token.RightParen, Token.EOF]

  describe "errors" $ do
    it "should catch unexpected characters" $ do
      let result = Scanner.scan "@"
      result
        `shouldBe` Left
          [ Error.ScanError "Unexpected character '@'." (Error.Location 1 1)
          ]

    it "should report correct position" $ do
      let result = Scanner.scan " ( ) @ { } "
      result
        `shouldBe` Left
          [ Error.ScanError "Unexpected character '@'." (Error.Location 1 6)
          ]

    it "should report correct line" $ do
      let result = Scanner.scan "\n{\n}\n@\n\n"
      result
        `shouldBe` Left
          [ Error.ScanError "Unexpected character '@'." (Error.Location 4 1)
          ]

    it "should report correct location" $ do
      let result = Scanner.scan "\r\t { \n } \n \r\t ( @ )\n\n"
      result
        `shouldBe` Left
          [ Error.ScanError "Unexpected character '@'." (Error.Location 3 7)
          ]
