module Compiler.Compiler (compileFile) where

import qualified Data.ByteString as BS
import qualified Data.Text as Text
import qualified Generator.Generator as Generator
import qualified Parser.Parser as Parser
import System.FilePath ((</>))
import qualified System.IO as SysIO

compileFile :: FilePath -> IO ()
compileFile workDir = do
  putStrLn $ "yatlc: working directory '" ++ workDir ++ "'"
  let ast = Parser.parse Text.empty
  let wasm = Generator.emit ast
  SysIO.withBinaryFile (workDir </> "foo.wasm") SysIO.WriteMode (`BS.hPut` wasm)
  let wit = Generator.wit ast
  writeFile (workDir </> "foo.wit") (Text.unpack wit)
