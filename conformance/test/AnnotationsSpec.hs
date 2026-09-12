{-# LANGUAGE OverloadedStrings #-}

module AnnotationsSpec (spec) where

import qualified Annotations
import Test.Hspec

spec :: Spec
spec = do
  describe "expected output" $ do
    it "should read a single annotation" $ do
      Annotations.expectedOutput "// [out]: foo\nfn main() -> {}\n"
        `shouldBe` ["foo"]

    it "should read several annotations in source order" $ do
      Annotations.expectedOutput "// [out]: one\n// [out]: two\n// [out]: three\n"
        `shouldBe` ["one", "two", "three"]

    it "should find no annotation in an unannotated case" $ do
      Annotations.expectedOutput "fn main() -> {}\n"
        `shouldBe` []

    it "should find no annotation in an empty case" $ do
      Annotations.expectedOutput "" `shouldBe` []

    it "should ignore ordinary comments and blank lines" $ do
      Annotations.expectedOutput "// a note\n\n// [out]: foo\n\n// another note\n"
        `shouldBe` ["foo"]

    it "should read an annotation that trails the code producing it" $ do
      Annotations.expectedOutput "   stdio::print(42); // [out]: 42\n"
        `shouldBe` ["42"]

    it "should read an indented annotation" $ do
      Annotations.expectedOutput "\t  // [out]: foo\n"
        `shouldBe` ["foo"]

    it "should accept a marker without a space after the comment start" $ do
      Annotations.expectedOutput "//[out]: foo\n"
        `shouldBe` ["foo"]

    it "should accept a marker without a separating space" $ do
      Annotations.expectedOutput "// [out]:foo\n"
        `shouldBe` ["foo"]

  describe "expected output values" $ do
    it "should read an empty annotation as an empty output line" $ do
      Annotations.expectedOutput "// [out]:\n"
        `shouldBe` [""]

    it "should preserve interior whitespace" $ do
      Annotations.expectedOutput "// [out]: foo   bar\tbaz\n"
        `shouldBe` ["foo   bar\tbaz"]

    it "should drop only the single separating space" $ do
      Annotations.expectedOutput "// [out]:   indented\n"
        `shouldBe` ["  indented"]

    it "should not mistake a later marker for part of the value" $ do
      Annotations.expectedOutput "// [out]: foo // [out]: bar\n"
        `shouldBe` ["foo // [out]: bar"]

    it "should skip a comment start that is not an annotation" $ do
      Annotations.expectedOutput "stdio::print(\"//\"); // [out]: //\n"
        `shouldBe` ["//"]
