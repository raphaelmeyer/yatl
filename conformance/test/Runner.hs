{-# LANGUAGE OverloadedStrings #-}

module Runner (run, Outcome (..)) where

import qualified Control.Monad as Monad
import qualified Control.Monad.Trans.Class as Trans
import qualified Control.Monad.Trans.Except as Except
import qualified Data.Text as Text
import qualified System.Directory as Directory
import qualified System.Environment as Environment
import qualified System.Exit as Exit
import qualified System.FilePath as SysFP
import qualified System.Process as Process

data Outcome
  = Success Text.Text
  | CompileError Text.Text
  deriving (Eq, Show)

data Binaries = Binaries
  { exeYatlc :: FilePath,
    exeWasmTools :: FilePath,
    exeWasmtime :: FilePath
  }
  deriving (Eq, Show)

data Artifacts = Artifacts
  { artifactBuildDirectory :: FilePath,
    artifactWasmPath :: FilePath,
    artifactEmbedPath :: FilePath,
    artifactComponentPath :: FilePath
  }
  deriving (Eq, Show)

type CompileResult = Either Text.Text ()

run :: FilePath -> IO (Either Text.Text Outcome)
run caseDir = Except.runExceptT $ do
  binaries <- locateBinaries
  compileAndRun binaries caseDir

locateBinaries :: Except.ExceptT Text.Text IO Binaries
locateBinaries = do
  yatlc <- locateBinary "YATLC" "yatlc"
  wasmTools <- locateBinary "WASM_TOOLS" "wasm-tools"
  wasmtime <- locateBinary "WASMTIME" "wasmtime"
  pure
    Binaries
      { exeYatlc = yatlc,
        exeWasmTools = wasmTools,
        exeWasmtime = wasmtime
      }

compileAndRun :: Binaries -> FilePath -> Except.ExceptT Text.Text IO Outcome
compileAndRun binaries testCaseDirectory = do
  entryFile <- findEntryFile testCaseDirectory
  let basename = SysFP.takeFileName testCaseDirectory
      artifacts = createArtificatPaths basename
  Trans.lift $ freshBuildDir (artifactBuildDirectory artifacts)
  compiled <- Trans.lift $ compile binaries artifacts entryFile
  case compiled of
    Left err -> pure $ CompileError err
    Right () -> do
      link binaries artifacts
      runWasm binaries artifacts

createArtificatPaths :: FilePath -> Artifacts
createArtificatPaths basename =
  let name = SysFP.takeFileName basename
      buildDir = "_build" SysFP.</> basename
   in Artifacts
        { artifactBuildDirectory = buildDir,
          artifactWasmPath = buildDir SysFP.</> name SysFP.<.> "wasm",
          artifactEmbedPath = buildDir SysFP.</> name SysFP.<.> "embed" SysFP.<.> "wasm",
          artifactComponentPath = buildDir SysFP.</> name SysFP.<.> "component" SysFP.<.> "wasm"
        }

findEntryFile :: FilePath -> Except.ExceptT Text.Text IO FilePath
findEntryFile testCaseDirectory = do
  entries <- Trans.lift (Directory.listDirectory testCaseDirectory)
  case filter ((== ".yatl") . SysFP.takeExtension) entries of
    [file] -> pure (testCaseDirectory SysFP.</> file)
    [] -> Except.throwE (Text.pack ("no .yatl file in " ++ testCaseDirectory))
    files -> Except.throwE (Text.pack ("expected exactly one .yatl file in " ++ testCaseDirectory ++ ", found " ++ show files))

freshBuildDir :: FilePath -> IO ()
freshBuildDir buildDir = do
  exists <- Directory.doesDirectoryExist buildDir
  Monad.when exists (Directory.removeDirectoryRecursive buildDir)
  Directory.createDirectoryIfMissing True buildDir
  depsDir <- Directory.makeAbsolute ("_build" SysFP.</> "deps")
  Directory.createDirectoryLink depsDir (buildDir SysFP.</> "deps")

compile :: Binaries -> Artifacts -> FilePath -> IO CompileResult
compile binaries artifacts entryFile = do
  runCompiler (exeYatlc binaries) ["-b", artifactBuildDirectory artifacts, entryFile]

link :: Binaries -> Artifacts -> Except.ExceptT Text.Text IO ()
link binaries artifacts = do
  Monad.void $
    runToolchain
      "wasm-tools component embed"
      (exeWasmTools binaries)
      ["component", "embed", "--world", "example:foo/foo", artifactBuildDirectory artifacts, artifactWasmPath artifacts, "-o", artifactEmbedPath artifacts]
  Monad.void $
    runToolchain
      "wasm-tools component new"
      (exeWasmTools binaries)
      ["component", "new", artifactEmbedPath artifacts, "-o", artifactComponentPath artifacts]

runWasm :: Binaries -> Artifacts -> Except.ExceptT Text.Text IO Outcome
runWasm binaries artifacts = do
  out <- runToolchain "wasmtime run" (exeWasmtime binaries) ["run", artifactComponentPath artifacts]
  pure $ Success out

runCompiler :: FilePath -> [String] -> IO CompileResult
runCompiler exe args = do
  (code, out, err) <- Process.readProcessWithExitCode exe args ""
  pure $ case code of
    Exit.ExitSuccess -> Right ()
    Exit.ExitFailure _ -> Left (Text.pack (out ++ err))

runToolchain :: Text.Text -> FilePath -> [String] -> Except.ExceptT Text.Text IO Text.Text
runToolchain step exe args = do
  (code, out, err) <- Trans.lift (Process.readProcessWithExitCode exe args "")
  case code of
    Exit.ExitSuccess -> pure $ Text.pack out
    Exit.ExitFailure _ -> Except.throwE (Text.concat [step, " failed:\n", Text.pack err])

locateBinary :: String -> String -> Except.ExceptT Text.Text IO FilePath
locateBinary envVar defaultName = do
  fromEnv <- Trans.lift (Environment.lookupEnv envVar)
  case fromEnv of
    Just path -> pure path
    Nothing -> do
      found <- Trans.lift (Directory.findExecutable defaultName)
      case found of
        Just path -> pure path
        Nothing ->
          Except.throwE . Text.pack $
            "could not find "
              ++ defaultName
              ++ " (set $"
              ++ envVar
              ++ " or add it to $PATH)"
