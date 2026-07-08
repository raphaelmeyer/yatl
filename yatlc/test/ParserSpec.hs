{-# LANGUAGE OverloadedStrings #-}

module ParserSpec (spec) where

import qualified AST.AST as AST
import qualified Parser.Parser as Parser
import qualified Parser.Scanner as Scanner
import Test.Hspec

spec :: Spec
spec = do
  describe "empty file" $ do
    it "should return an empty AST" $ do
      let result =
            Scanner.scan "" >>= Parser.parse
      result `shouldBe` Right (AST.Tree [])

  describe "functions" $ do
    it "should parse an empty function" $ do
      let result =
            Scanner.scan "fn main() -> {}"
              >>= Parser.parse
      result `shouldBe` Right (AST.Tree [AST.Function])
