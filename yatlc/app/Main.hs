module Main where

import qualified Compiler.Compiler as Compiler
import qualified Compiler.Options as CompOpts
import Control.Applicative ((<**>))
import qualified Options.Applicative as Options

options :: Options.Parser CompOpts.Options
options =
  CompOpts.Options
    <$> Options.option
      Options.str
      ( Options.long "build-directory"
          <> Options.short 'b'
          <> Options.help "Directory for build artifacts"
          <> Options.metavar "DIR"
      )
    <*> Options.argument
      Options.str
      ( Options.help "File to compile"
          <> Options.metavar "FILE"
      )

main :: IO ()
main = do
  opts <-
    Options.execParser
      ( Options.info
          (options <**> Options.helper)
          ( Options.fullDesc
              <> Options.progDesc "yatl compiler"
              <> Options.header "yatlc"
          )
      )

  Compiler.compile opts
