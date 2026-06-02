module CircuitEDA.Transform
  ( simplify
  , simplifyOnce
  , simplifyDesign
  , renderNetlist
  , SimpleState(..)
  , fresh
  , emit
  , renderVerilog
  ) where

import CircuitEDA.AST

simplifyDesign :: Design -> Design
simplifyDesign (Design assigns) =
  Design [assignment { assignExpr = simplify (assignExpr assignment) } | assignment <- assigns]

simplify :: Expr -> Expr
simplify expr =
  let expr' = simplifyOnce expr
   in if expr' == expr then expr else simplify expr'

simplifyOnce :: Expr -> Expr
simplifyOnce (Not e) =
  case simplifyOnce e of
    Lit b -> Lit (not b)
    Not inner -> inner
    inner -> Not inner
simplifyOnce (And a b) =
  case (simplifyOnce a, simplifyOnce b) of
    (Lit False, _) -> Lit False
    (_, Lit False) -> Lit False
    (Lit True, x) -> x
    (x, Lit True) -> x
    (x, y) | x == y -> x
    (x, y) -> And x y
simplifyOnce (Nand a b) =
  case (simplifyOnce a, simplifyOnce b) of
    (Lit False, _) -> Lit True
    (_, Lit False) -> Lit True
    (Lit True, x) -> Not x
    (x, Lit True) -> Not x
    (x, y) | x == y -> Not x
    (x, y) -> Nand x y
simplifyOnce (Or a b) =
  case (simplifyOnce a, simplifyOnce b) of
    (Lit True, _) -> Lit True
    (_, Lit True) -> Lit True
    (Lit False, x) -> x
    (x, Lit False) -> x
    (x, y) | x == y -> x
    (x, y) -> Or x y
simplifyOnce (Nor a b) =
  case (simplifyOnce a, simplifyOnce b) of
    (Lit True, _) -> Lit False
    (_, Lit True) -> Lit False
    (Lit False, x) -> Not x
    (x, Lit False) -> Not x
    (x, y) | x == y -> Not x
    (x, y) -> Nor x y
simplifyOnce (Xor a b) =
  case (simplifyOnce a, simplifyOnce b) of
    (Lit False, x) -> x
    (x, Lit False) -> x
    (Lit True, x) -> Not x
    (x, Lit True) -> Not x
    (x, y) | x == y -> Lit False
    (x, y) -> Xor x y
simplifyOnce other = other

renderNetlist :: Design -> String
renderNetlist design =
  let (_, (_, linesOut)) = runSimpleState (mapM_ netAssignment (designAssignments design)) (1, [])
   in unlines linesOut

type NetState = (Int, [String])

newtype SimpleState s a = SimpleState { runSimpleState :: s -> (a, s) }

instance Functor (SimpleState s) where
  fmap f (SimpleState st) = SimpleState $ \s ->
    let (a, s') = st s in (f a, s')

instance Applicative (SimpleState s) where
  pure a = SimpleState $ \s -> (a, s)
  SimpleState sf <*> SimpleState sa = SimpleState $ \s ->
    let (f, s') = sf s
        (a, s'') = sa s'
     in (f a, s'')

instance Monad (SimpleState s) where
  SimpleState sa >>= f = SimpleState $ \s ->
    let (a, s') = sa s
     in runSimpleState (f a) s'

fresh :: SimpleState NetState String
fresh = SimpleState $ \(n, linesOut) -> ("n" ++ show n, (n + 1, linesOut))

emit :: String -> SimpleState NetState ()
emit line = SimpleState $ \(n, linesOut) -> ((), (n, linesOut ++ [line]))

netAssignment :: Assignment -> SimpleState NetState ()
netAssignment assignment = do
  wire <- netExpr (assignExpr assignment)
  emitFinal (assignName assignment) wire

emitFinal :: String -> String -> SimpleState NetState ()
emitFinal name wire =
  case wire of
    "0" -> emit (name ++ " = CONST 0")
    "1" -> emit (name ++ " = CONST 1")
    _ -> emit (name ++ " = BUF " ++ wire)

netExpr :: Expr -> SimpleState NetState String
netExpr (Lit False) = pure "0"
netExpr (Lit True) = pure "1"
netExpr (Var x) = pure x
netExpr (Not e) = unary "NOT" e
netExpr (And a b) = binaryNet "AND" a b
netExpr (Or a b) = binaryNet "OR" a b
netExpr (Xor a b) = binaryNet "XOR" a b
netExpr (Nand a b) = binaryNet "NAND" a b
netExpr (Nor a b) = binaryNet "NOR" a b

unary :: String -> Expr -> SimpleState NetState String
unary op e = do
  a <- netExpr e
  out <- fresh
  emit (out ++ " = " ++ op ++ " " ++ a)
  pure out

binaryNet :: String -> Expr -> Expr -> SimpleState NetState String
binaryNet op a b = do
  left <- netExpr a
  right <- netExpr b
  out <- fresh
  emit (out ++ " = " ++ op ++ " " ++ left ++ " " ++ right)
  pure out

renderVerilog :: Design -> String
renderVerilog design =
  unlines $
    ["module functional_eda_demo("]
      ++ portLines
      ++ [");"]
      ++ map renderAssign (designAssignments design)
      ++ ["endmodule"]
  where
    ports = designInputs design ++ designOutputs design
    portLines =
      [ "  " ++ direction p ++ " " ++ p ++ comma i
      | (i, p) <- zip [0 :: Int ..] ports
      ]
    comma i = if i == length ports - 1 then "" else ","
    direction p = if p `elem` designOutputs design then "output" else "input"
    renderAssign assignment =
      "  assign " ++ assignName assignment ++ " = " ++ verilogExpr (assignExpr assignment) ++ ";"

verilogExpr :: Expr -> String
verilogExpr (Lit False) = "1'b0"
verilogExpr (Lit True) = "1'b1"
verilogExpr (Var x) = x
verilogExpr (Not e) = "(~" ++ verilogExpr e ++ ")"
verilogExpr (And a b) = "(" ++ verilogExpr a ++ " & " ++ verilogExpr b ++ ")"
verilogExpr (Or a b) = "(" ++ verilogExpr a ++ " | " ++ verilogExpr b ++ ")"
verilogExpr (Xor a b) = "(" ++ verilogExpr a ++ " ^ " ++ verilogExpr b ++ ")"
verilogExpr (Nand a b) = "(~(" ++ verilogExpr a ++ " & " ++ verilogExpr b ++ "))"
verilogExpr (Nor a b) = "(~(" ++ verilogExpr a ++ " | " ++ verilogExpr b ++ "))"
