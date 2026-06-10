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

  describe "tokens" $ do
    it "should return the parsed single character tokens" $ do
      let result = Scanner.scan "({})"
      result `shouldBe` Right [Token.LeftParen, Token.LeftBrace, Token.RightBrace, Token.RightParen, Token.EOF]

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
