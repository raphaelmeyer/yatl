{-# LANGUAGE OverloadedStrings #-}

module Parser.ModuleSpec (spec) where

import qualified AST.AST as AST
import qualified Compiler.Error as Error
import qualified Compiler.Location as Location
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

  describe "syntax errors" $ do
    it "should report an invalid token" $ do
      let result =
            Scanner.scan "void"
              >>= Parser.parse
      result
        `shouldBe` Left
          [ Error.ParseError
              "Unexpected token."
              (Location.Location 1 1)
          ]

    it "should report the correct line" $ do
      let result =
            Scanner.scan "\n  \n \n   \nvoid"
              >>= Parser.parse
      result
        `shouldBe` Left
          [ Error.ParseError
              "Unexpected token."
              (Location.Location 5 1)
          ]

    it "should report the correct position" $ do
      let result =
            Scanner.scan "\n \n      void"
              >>= Parser.parse
      result
        `shouldBe` Left
          [ Error.ParseError
              "Unexpected token."
              (Location.Location 3 7)
          ]
