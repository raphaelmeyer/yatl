{-# LANGUAGE OverloadedStrings #-}

module Parser.FunctionSpec (spec) where

import qualified AST.AST as AST
import qualified Compiler.Error as Error
import qualified Compiler.Location as Location
import qualified Parser.Parser as Parser
import qualified Parser.Scanner as Scanner
import Test.Hspec

spec :: Spec
spec = do
  describe "AST" $ do
    it "should parse an empty function" $ do
      let result =
            Scanner.scan "fn main() -> {}"
              >>= Parser.parse
      result `shouldBe` Right (AST.Tree [AST.Function])

  describe "definition" $ do
    it "should report missing function name" $ do
      let result =
            Scanner.scan "fn () -> {}"
              >>= Parser.parse
      result
        `shouldBe` Left
          [ Error.ParseError
              "Expect function name."
              (Location.Location 1 4)
          ]

    it "should report missing arguments opening parenthesis" $ do
      let result =
            Scanner.scan "fn main -> {}"
              >>= Parser.parse
      result
        `shouldBe` Left
          [ Error.ParseError
              "Expect '('."
              (Location.Location 1 9)
          ]

    it "should report missing arguments closing parenthesis" $ do
      let result =
            Scanner.scan "fn main( -> {}"
              >>= Parser.parse
      result
        `shouldBe` Left
          [ Error.ParseError
              "Expect ')'."
              (Location.Location 1 10)
          ]

    it "should report missing arrow" $ do
      let result =
            Scanner.scan "fn main() {}"
              >>= Parser.parse
      result
        `shouldBe` Left
          [ Error.ParseError
              "Expect '->'."
              (Location.Location 1 11)
          ]

    it "should report missing opening braces" $ do
      let result =
            Scanner.scan "fn main() -> }"
              >>= Parser.parse
      result
        `shouldBe` Left
          [ Error.ParseError
              "Expect '{'."
              (Location.Location 1 14)
          ]

    it "should report missing closing braces" $ do
      let result =
            Scanner.scan "fn main() -> {"
              >>= Parser.parse
      result
        `shouldBe` Left
          [ Error.ParseError
              "Expect '}'."
              (Location.Location 1 15)
          ]
