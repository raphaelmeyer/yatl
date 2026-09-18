{-# LANGUAGE OverloadedStrings #-}

module Annotations (expectedOutput) where

import qualified Data.Maybe as Maybe
import qualified Data.Text as Text

expectedOutput :: Text.Text -> [Text.Text]
expectedOutput = Maybe.mapMaybe (annotation outMarker) . Text.lines

outMarker :: Text.Text
outMarker = "[out]:"

commentStart :: Text.Text
commentStart = "//"

annotation :: Text.Text -> Text.Text -> Maybe Text.Text
annotation marker line = case Text.breakOn commentStart line of
  (_, "") -> Nothing
  (_, found) ->
    let comment = Text.drop (Text.length commentStart) found
     in case Text.stripPrefix marker (Text.stripStart comment) of
          Nothing -> annotation marker comment
          Just value -> Just (dropSeparator value)

dropSeparator :: Text.Text -> Text.Text
dropSeparator value = Maybe.fromMaybe value (Text.stripPrefix " " value)
