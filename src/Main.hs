module Main where

import CircuitEDA
import Control.Monad (forM_, unless, when)
import System.Directory (doesFileExist)
import System.Environment (getArgs)
import System.FilePath (takeBaseName)

defaultExamples :: [FilePath]
defaultExamples =
  [ "examples/basic.logic"
  , "examples/mux.logic"
  , "examples/full_adder.logic"
  , "examples/simplify.logic"
  , "examples/advanced_gates.logic"
  , "examples/majority.logic"
  ]

main :: IO ()
main = do
  args <- getArgs
  case args of
    [] -> runDefaultDemo
    ["--help"] -> putStrLn helpText
    ["--expr", exprText] -> runSource "inline expression" ("out = " ++ exprText)
    files -> do
      forM_ files $ \file -> do
        exists <- doesFileExist file
        if exists
          then readFile file >>= runSource (takeBaseName file)
          else putStrLn ("File not found: " ++ file)

runDefaultDemo :: IO ()
runDefaultDemo = do
  putStrLn banner
  existing <- filterMExists defaultExamples
  unless (null existing) $ do
    putStrLn "Running bundled examples..."
    putStrLn ""
  forM_ existing $ \file ->
    readFile file >>= runSource (takeBaseName file)
  when (null existing) $
    putStrLn "No example files found. Run from the finalpre directory or pass a file path."

filterMExists :: [FilePath] -> IO [FilePath]
filterMExists [] = pure []
filterMExists (x:xs) = do
  ok <- doesFileExist x
  rest <- filterMExists xs
  pure (if ok then x:rest else rest)

runSource :: String -> String -> IO ()
runSource label source = do
  putStrLn (rule '=')
  putStrLn ("Demo: " ++ label)
  putStrLn (rule '=')
  case parseDesign source of
    Left err -> do
      putStrLn "Parse error:"
      putStrLn ("  " ++ err)
      putStrLn ""
    Right design -> runDesign design

runDesign :: Design -> IO ()
runDesign design = do
  let simplifiedDesign = simplifyDesign design
  putStrLn "Input design:"
  forM_ (designAssignments design) $ \assignment ->
    putStrLn ("  " ++ assignName assignment ++ " = " ++ pretty (assignExpr assignment))
  putStrLn ""

  putStrLn "1) AST as circuit trees"
  forM_ (designAssignments design) $ \assignment -> do
    putStrLn ("[" ++ assignName assignment ++ "]")
    putStrLn (renderTree (assignExpr assignment))

  putStrLn "2) Basic analysis"
  putStrLn ("  primary inputs : " ++ showListText (designInputs design))
  putStrLn ("  assigned signals: " ++ showListText (designOutputs design))
  putStrLn ("  total gates     : " ++ show (designGateCount design))
  putStrLn ("  max depth       : " ++ show (designDepth design))
  putStrLn ""

  putStrLn "3) Truth table, including multiple outputs"
  putStrLn (renderTruthTable design)

  putStrLn "4) Simplification + exhaustive equivalence check"
  if simplifiedDesign == design
    then putStrLn "  no simplification rule changed this design."
    else do
      forM_ (zip (designAssignments design) (designAssignments simplifiedDesign)) $ \(before, after) ->
        when (assignExpr before /= assignExpr after) $ do
          putStrLn ("  " ++ assignName before ++ ":")
          putStrLn ("    before: " ++ pretty (assignExpr before))
          putStrLn ("    after : " ++ pretty (assignExpr after))
      putStrLn ("  gates : " ++ show (designGateCount design) ++ " -> " ++ show (designGateCount simplifiedDesign))
  putStrLn ("  check : " ++ equivalenceReport design simplifiedDesign)
  putStrLn ""

  putStrLn "5) Netlist generated with a small State monad"
  putStrLn (renderNetlist simplifiedDesign)

  putStrLn "6) Verilog-style assign output"
  putStrLn (renderVerilog simplifiedDesign)

  putStrLn "7) Missing-signal error demo"
  putStrLn ("  " ++ demoMissingSignal design)
  putStrLn ""

showListText :: [String] -> String
showListText [] = "(none)"
showListText xs = joinWith ", " xs

joinWith :: String -> [String] -> String
joinWith _ [] = ""
joinWith _ [x] = x
joinWith sep (x:xs) = x ++ sep ++ joinWith sep xs

rule :: Char -> String
rule c = replicate 72 c

banner :: String
banner = unlines
  [ "Functional EDA demo in Haskell"
  , "Topic: Boolean expression -> AST -> truth table -> simplified netlist -> Verilog assign"
  , "Haskell ideas: ADT, recursion, pattern matching, Either, parser combinators, State, pure code generation"
  , ""
  ]

helpText :: String
helpText = unlines
  [ "Usage:"
  , "  runghc -isrc src\\Main.hs"
  , "  runghc -isrc src\\Main.hs examples\\basic.logic"
  , "  runghc -isrc src\\Main.hs --expr \"(a AND b) OR NOT c\""
  , ""
  , "Design syntax:"
  , "  out = (a AND b) OR NOT c"
  , "  sum = a XOR b XOR cin"
  , "  carry = (a AND b) OR (cin AND (a XOR b))"
  , ""
  , "Expression syntax:"
  , "  NOT x        or !x"
  , "  x AND y      or x && y"
  , "  x OR y       or x || y"
  , "  x XOR y      or x ^ y"
  , "  x NAND y"
  , "  x NOR y"
  , "  TRUE/FALSE   or 1/0"
  , "  Parentheses are supported."
  ]
