module Compiler.Compiler (compileFile) where

import qualified Compiler.Options as Options
import qualified Data.ByteString as BS
import qualified Data.Text as Text
import qualified Generator.Generator as Generator
import qualified Parser.Parser as Parser
import qualified System.FilePath as SysFP
import qualified System.IO as SysIO

compileFile :: Options.Options -> IO ()
compileFile options = do
  putStrLn $
    "yatlc: build directory '"
      ++ Options.buildDirectory options
      ++ "'"

  source <- readFile (Options.sourceFile options)

  let ast = Parser.parse $ Text.pack source
  let wasm = Generator.emit ast
  putStrLn $ "yatlc: " ++ moduleFileName options
  SysIO.withBinaryFile (moduleFileName options) SysIO.WriteMode (`BS.hPut` wasm)

  let wit = Generator.wit ast
  putStrLn $ "yatlc: " ++ witFileName options
  writeFile (witFileName options) (Text.unpack wit)

moduleFileName :: Options.Options -> FilePath
moduleFileName options =
  SysFP.replaceDirectory (Options.sourceFile options) (Options.buildDirectory options)
    `SysFP.replaceExtension` "wasm"

witFileName :: Options.Options -> FilePath
witFileName options =
  SysFP.replaceDirectory (Options.sourceFile options) (Options.buildDirectory options)
    `SysFP.replaceExtension` "wit"
