module Main where

import qualified Data.ByteString as BS
import qualified Data.Text as Text
import qualified Generator.Generator as Generator
import qualified Parser.Parser as Parser
import qualified System.Environment as Environment
import qualified System.Exit as Exit
import System.FilePath ((</>))
import qualified System.IO as SysIO

main :: IO ()
main = do
  args <- Environment.getArgs
  case args of
    [dir] -> compileFile dir
    _ -> Exit.exitFailure

compileFile :: FilePath -> IO ()
compileFile workDir = do
  putStrLn $ "yatlc: working directory '" ++ workDir ++ "'"
  let ast = Parser.parse Text.empty
  let wasm = Generator.emit ast
  SysIO.withBinaryFile (workDir </> "foo.wasm") SysIO.WriteMode (`BS.hPut` wasm)
  let wit = Generator.wit ast
  writeFile (workDir </> "foo.wit") (Text.unpack wit)
