module Compiler.Compiler (compile) where

import qualified AST.AST as AST
import qualified Compiler.Error as Error
import qualified Compiler.Options as Options
import qualified Data.ByteString as BS
import qualified Data.Text as Text
import qualified Generator.Generator as Generator
import qualified Parser.Parser as Parser
import qualified Parser.Scanner as Scanner
import qualified System.FilePath as SysFP
import qualified System.IO as SysIO

type Result a = Either [Error.Error] a

compile :: Options.Options -> IO ()
compile options = do
  putStrLn $
    "yatlc: build directory '"
      ++ Options.buildDirectory options
      ++ "'"

  source <- readFile (Options.sourceFile options)
  case compileFile $ Text.pack source of
    Left errors -> do
      mapM_ print errors
    Right ast -> do
      let outPath = SysFP.replaceDirectory (Options.sourceFile options) (Options.buildDirectory options)
      generateModule ast outPath

compileFile :: Text.Text -> Result AST.Tree
compileFile source = do
  tokens <- Scanner.scan source
  Parser.parse tokens

generateModule :: AST.Tree -> FilePath -> IO ()
generateModule ast outPath = do
  let wasm = Generator.emit ast
  let wasmPath = outPath `SysFP.replaceExtension` "wasm"
  putStrLn $ "yatlc: " ++ wasmPath
  SysIO.withBinaryFile wasmPath SysIO.WriteMode (`BS.hPut` wasm)

  let wit = Generator.wit ast
  let witPath = outPath `SysFP.replaceExtension` "wit"
  putStrLn $ "yatlc: " ++ witPath
  writeFile witPath (Text.unpack wit)
