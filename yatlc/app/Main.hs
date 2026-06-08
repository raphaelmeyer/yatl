module Main where

import qualified Compiler.Compiler as Compiler
import Control.Applicative ((<**>))
import qualified Options.Applicative as Options

data Options = Options
  { optWorkingDirectory :: FilePath,
    optFile :: FilePath
  }
  deriving (Show)

options :: Options.Parser Options
options =
  Options
    <$> ( Options.option Options.str $
            Options.long "build-directory"
              <> Options.short 'b'
              <> Options.help "Directory for build artifacts"
              <> Options.metavar "DIR"
        )
    <*> ( Options.argument Options.str $
            Options.help "File to compile"
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

  Compiler.compileFile (optWorkingDirectory opts)
