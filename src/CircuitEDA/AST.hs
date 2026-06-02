module CircuitEDA.AST
  ( Expr(..)
  , Assignment(..)
  , Design(..)
  , Env
  , pretty
  , vars
  , designInputs
  , designOutputs
  , assignmentMap
  , gateCount
  , designGateCount
  , depth
  , designDepth
  , renderTree
  ) where

import Data.List ((\\), nub, sort)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map

data Expr
  = Lit Bool
  | Var String
  | Not Expr
  | And Expr Expr
  | Or Expr Expr
  | Xor Expr Expr
  | Nand Expr Expr
  | Nor Expr Expr
  deriving (Eq)

data Assignment = Assignment
  { assignName :: String
  , assignExpr :: Expr
  } deriving (Eq, Show)

newtype Design = Design
  { designAssignments :: [Assignment]
  } deriving (Eq, Show)

type Env = Map String Bool

instance Show Expr where
  show = pretty

pretty :: Expr -> String
pretty = go 0
  where
    go _ (Lit True) = "TRUE"
    go _ (Lit False) = "FALSE"
    go _ (Var x) = x
    go p (Not e) = wrap (p > 4) ("NOT " ++ go 4 e)
    go p (And a b) = wrap (p > 3) (go 3 a ++ " AND " ++ go 4 b)
    go p (Nand a b) = wrap (p > 3) (go 3 a ++ " NAND " ++ go 4 b)
    go p (Xor a b) = wrap (p > 2) (go 2 a ++ " XOR " ++ go 3 b)
    go p (Or a b) = wrap (p > 1) (go 1 a ++ " OR " ++ go 2 b)
    go p (Nor a b) = wrap (p > 1) (go 1 a ++ " NOR " ++ go 2 b)

    wrap True s = "(" ++ s ++ ")"
    wrap False s = s

vars :: Expr -> [String]
vars = sort . nub . go
  where
    go (Lit _) = []
    go (Var x) = [x]
    go (Not e) = go e
    go (And a b) = go a ++ go b
    go (Or a b) = go a ++ go b
    go (Xor a b) = go a ++ go b
    go (Nand a b) = go a ++ go b
    go (Nor a b) = go a ++ go b

designOutputs :: Design -> [String]
designOutputs = map assignName . designAssignments

designInputs :: Design -> [String]
designInputs design =
  sort (nub (concatMap (vars . assignExpr) (designAssignments design)) \\ designOutputs design)

assignmentMap :: Design -> Map String Expr
assignmentMap design = Map.fromList [(assignName a, assignExpr a) | a <- designAssignments design]

gateCount :: Expr -> Int
gateCount (Lit _) = 0
gateCount (Var _) = 0
gateCount (Not e) = 1 + gateCount e
gateCount (And a b) = 1 + gateCount a + gateCount b
gateCount (Or a b) = 1 + gateCount a + gateCount b
gateCount (Xor a b) = 1 + gateCount a + gateCount b
gateCount (Nand a b) = 1 + gateCount a + gateCount b
gateCount (Nor a b) = 1 + gateCount a + gateCount b

designGateCount :: Design -> Int
designGateCount = sum . map (gateCount . assignExpr) . designAssignments

depth :: Expr -> Int
depth (Lit _) = 1
depth (Var _) = 1
depth (Not e) = 1 + depth e
depth (And a b) = 1 + max (depth a) (depth b)
depth (Or a b) = 1 + max (depth a) (depth b)
depth (Xor a b) = 1 + max (depth a) (depth b)
depth (Nand a b) = 1 + max (depth a) (depth b)
depth (Nor a b) = 1 + max (depth a) (depth b)

designDepth :: Design -> Int
designDepth (Design []) = 0
designDepth design = maximum (map (depth . assignExpr) (designAssignments design))

renderTree :: Expr -> String
renderTree expr = unlines (label expr : childLines "" expr)
  where
    go prefix isLast node =
      let marker = if null prefix then "" else if isLast then "`- " else "+- "
          nextPrefix = prefix ++ if null prefix then "" else if isLast then "   " else "|  "
       in (prefix ++ marker ++ label node) : childLines nextPrefix node

    childLines prefix (Not e) = go (childPrefix prefix) True e
    childLines prefix (And a b) = binary prefix a b
    childLines prefix (Or a b) = binary prefix a b
    childLines prefix (Xor a b) = binary prefix a b
    childLines prefix (Nand a b) = binary prefix a b
    childLines prefix (Nor a b) = binary prefix a b
    childLines _ _ = []

    binary prefix a b = go (childPrefix prefix) False a ++ go (childPrefix prefix) True b
    childPrefix "" = "  "
    childPrefix prefix = prefix

    label (Lit True) = "CONST TRUE"
    label (Lit False) = "CONST FALSE"
    label (Var x) = "VAR " ++ x
    label (Not _) = "NOT"
    label (And _ _) = "AND"
    label (Or _ _) = "OR"
    label (Xor _ _) = "XOR"
    label (Nand _ _) = "NAND"
    label (Nor _ _) = "NOR"
