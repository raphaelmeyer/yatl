module Main where

import Control.Applicative ((<**>))
import qualified Data.ByteString as BS
import qualified Data.Text as Text
import qualified Generator.Generator as Generator
import qualified Options.Applicative as Options
import qualified Parser.Parser as Parser
import System.FilePath ((</>))
import qualified System.IO as SysIO

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

  compileFile (optWorkingDirectory opts)

compileFile :: FilePath -> IO ()
compileFile workDir = do
  putStrLn $ "yatlc: working directory '" ++ workDir ++ "'"
  let ast = Parser.parse Text.empty
  let wasm = Generator.emit ast
  SysIO.withBinaryFile (workDir </> "foo.wasm") SysIO.WriteMode (`BS.hPut` wasm)
  let wit = Generator.wit ast
  writeFile (workDir </> "foo.wit") (Text.unpack wit)
