module Main where

import qualified Data.ByteString as BS
import qualified Data.Text as Text
import qualified Generator.Generator as Generator
import qualified Parser.Parser as Parser
import qualified System.IO as SysIO

main :: IO ()
main = do
  putStrLn "yatlc"
  let ast = Parser.parse Text.empty
  let wasm = Generator.emit ast
  SysIO.withBinaryFile "/tmp/foo/foo.wasm" SysIO.WriteMode (`BS.hPut` wasm)
  let wit = Generator.wit ast
  writeFile "/tmp/foo/foo.wit" (Text.unpack wit)
