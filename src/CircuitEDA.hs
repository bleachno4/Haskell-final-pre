module CircuitEDA
  ( Expr(..)
  , Assignment(..)
  , Design(..)
  , Env
  , parseDesign
  , pretty
  , simplify
  , simplifyDesign
  , vars
  , designInputs
  , designOutputs
  , eval
  , evalAssignment
  , gateCount
  , designGateCount
  , depth
  , designDepth
  , renderTree
  , renderTruthTable
  , renderNetlist
  , renderVerilog
  , equivalenceReport
  , demoMissingSignal
  ) where

import Control.Applicative (Alternative(..))
import Data.Char (isAlpha, isAlphaNum, isSpace, toUpper)
import Data.List ((\\), intercalate, nub, sort)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)

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

newtype Parser a = Parser { runParser :: String -> Maybe (a, String) }

instance Functor Parser where
  fmap f (Parser p) = Parser $ \s -> do
    (a, rest) <- p s
    pure (f a, rest)

instance Applicative Parser where
  pure a = Parser $ \s -> Just (a, s)
  Parser pf <*> Parser pa = Parser $ \s -> do
    (f, rest) <- pf s
    (a, rest') <- pa rest
    pure (f a, rest')

instance Monad Parser where
  Parser pa >>= f = Parser $ \s -> do
    (a, rest) <- pa s
    runParser (f a) rest

instance Alternative Parser where
  empty = Parser $ const Nothing
  Parser a <|> Parser b = Parser $ \s -> a s <|> b s

parseDesign :: String -> Either String Design
parseDesign source =
  case filter (not . null) . map (trim . stripComment) $ lines source of
    [] -> Left "empty design: please provide a line like out = (a AND b) OR NOT c"
    [line] | '=' `notElem` line -> Design . pure . Assignment "out" <$> parseExprText line
    linesIn -> do
      assigns <- mapM parseLine linesIn
      let names = map assignName assigns
      if length names == length (nub names)
        then Right (Design assigns)
        else Left "duplicate assignment name in design"
  where
    parseLine line =
      let (lhs, rest) = break (== '=') line
       in case rest of
            ('=':rhs) ->
              let name = trim lhs
               in if validName name
                    then Assignment name <$> parseExprText rhs
                    else Left ("invalid signal name: " ++ show name)
            _ -> Left ("expected assignment with '=' but got: " ++ line)

parseExprText :: String -> Either String Expr
parseExprText text =
  case runParser (spaces *> exprParser <* spaces) text of
    Just (expr, rest) | all isSpace rest -> Right expr
    _ -> Left ("could not parse expression: " ++ trim text)

exprParser :: Parser Expr
exprParser = parseOr

parseOr :: Parser Expr
parseOr = chainl1 parseXor orOp
  where
    orOp =
      (symbol "||" *> pure Or)
        <|> (keyword "OR" *> pure Or)
        <|> (keyword "NOR" *> pure Nor)

parseXor :: Parser Expr
parseXor = chainl1 parseAnd xorOp
  where
    xorOp =
      (symbol "^" *> pure Xor)
        <|> (keyword "XOR" *> pure Xor)

parseAnd :: Parser Expr
parseAnd = chainl1 parseNot andOp
  where
    andOp =
      (symbol "&&" *> pure And)
        <|> (keyword "AND" *> pure And)
        <|> (keyword "NAND" *> pure Nand)

parseNot :: Parser Expr
parseNot =
  (symbol "!" *> (Not <$> parseNot))
    <|> (keyword "NOT" *> (Not <$> parseNot))
    <|> parseAtom

parseAtom :: Parser Expr
parseAtom =
  (Lit <$> boolLit)
    <|> (Var <$> identifier)
    <|> parens exprParser

boolLit :: Parser Bool
boolLit =
  (keyword "TRUE" *> pure True)
    <|> (keyword "FALSE" *> pure False)
    <|> (symbol "1" *> pure True)
    <|> (symbol "0" *> pure False)

chainl1 :: Parser a -> Parser (a -> a -> a) -> Parser a
chainl1 p op = do
  first <- p
  rest first
  where
    rest left = (do
      f <- op
      right <- p
      rest (f left right)) <|> pure left

parens :: Parser a -> Parser a
parens p = symbol "(" *> p <* symbol ")"

symbol :: String -> Parser String
symbol tok = token $ Parser $ \s ->
  if tok `prefixOf` s
    then Just (tok, drop (length tok) s)
    else Nothing

keyword :: String -> Parser String
keyword kw = token $ Parser $ \s ->
  let n = length kw
      (headPart, tailPart) = splitAt n s
   in if map toUpper headPart == kw && boundary tailPart
        then Just (kw, tailPart)
        else Nothing

identifier :: Parser String
identifier = token $ Parser $ \s ->
  case s of
    (c:cs) | isAlpha c || c == '_' ->
      let (body, rest) = span isIdentChar cs
          name = c:body
       in if map toUpper name `elem` reservedWords
            then Nothing
            else Just (name, rest)
    _ -> Nothing

token :: Parser a -> Parser a
token p = spaces *> p <* spaces

spaces :: Parser ()
spaces = Parser $ \s -> Just ((), dropWhile isSpace s)

prefixOf :: String -> String -> Bool
prefixOf needle haystack = take (length needle) haystack == needle

boundary :: String -> Bool
boundary [] = True
boundary (c:_) = not (isIdentChar c)

isIdentChar :: Char -> Bool
isIdentChar c = isAlphaNum c || c == '_' || c == '\''

reservedWords :: [String]
reservedWords = ["AND", "OR", "XOR", "NAND", "NOR", "NOT", "TRUE", "FALSE"]

validName :: String -> Bool
validName [] = False
validName name@(c:cs) =
  (isAlpha c || c == '_')
    && all isIdentChar cs
    && map toUpper name `notElem` reservedWords

stripComment :: String -> String
stripComment = takeWhile (/= '#')

trim :: String -> String
trim = reverse . dropWhile isSpace . reverse . dropWhile isSpace

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

eval :: Env -> Expr -> Either String Bool
eval env = evalWith Map.empty env

evalAssignment :: Design -> Env -> Assignment -> Either String Bool
evalAssignment design env assignment =
  evalWith (assignmentMap design) env (assignExpr assignment)

evalWith :: Map String Expr -> Env -> Expr -> Either String Bool
evalWith defs env = go []
  where
    go _ (Lit b) = Right b
    go stack (Var x) =
      case Map.lookup x env of
        Just b -> Right b
        Nothing ->
          case Map.lookup x defs of
            Just expr
              | x `elem` stack -> Left ("cyclic signal definition: " ++ intercalate " -> " (reverse (x:stack)))
              | otherwise -> go (x:stack) expr
            Nothing -> Left ("unknown signal: " ++ x)
    go stack (Not e) = not <$> go stack e
    go stack (And a b) = (&&) <$> go stack a <*> go stack b
    go stack (Or a b) = (||) <$> go stack a <*> go stack b
    go stack (Xor a b) = (/=) <$> go stack a <*> go stack b
    go stack (Nand a b) = not <$> ((&&) <$> go stack a <*> go stack b)
    go stack (Nor a b) = not <$> ((||) <$> go stack a <*> go stack b)

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

renderTruthTable :: Design -> String
renderTruthTable design =
  let inputs = designInputs design
      outputs = designOutputs design
      rows = map (rowFor inputs) (assignments inputs)
      header = inputs ++ outputs
      tableRows = header : rows
      widths = columnWidths tableRows
      rendered = map (renderRow widths) tableRows
      line = intercalate "-+-" (map (`replicate` '-') widths)
   in case rendered of
        [] -> ""
        (h:body) -> unlines (h : line : body)
  where
    rowFor inputs env =
      let inputValues = map (boolText . valueOf env) inputs
          outputValues =
            [ either ("ERR: " ++) boolText (evalAssignment design env assignment)
            | assignment <- designAssignments design
            ]
       in inputValues ++ outputValues

    valueOf env name = Map.findWithDefault False name env

assignments :: [String] -> [Env]
assignments [] = [Map.empty]
assignments (name:rest) =
  [ Map.insert name value env
  | value <- [False, True]
  , env <- assignments rest
  ]

columnWidths :: [[String]] -> [Int]
columnWidths rows =
  [ maximum (map (length . (!! i)) rows)
  | i <- [0 .. length (head rows) - 1]
  ]

renderRow :: [Int] -> [String] -> String
renderRow widths values =
  intercalate " | " [padRight w v | (w, v) <- zip widths values]

padRight :: Int -> String -> String
padRight width text = text ++ replicate (width - length text) ' '

boolText :: Bool -> String
boolText False = "0"
boolText True = "1"

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

equivalenceReport :: Design -> Design -> String
equivalenceReport original simplified =
  let inputs = sort (nub (designInputs original ++ designInputs simplified))
      envs = assignments inputs
      firstMismatch = firstJust [checkEnv env | env <- envs]
   in case firstMismatch of
        Nothing -> "equivalent on all " ++ show (length envs) ++ " input combinations"
        Just msg -> "NOT equivalent: " ++ msg
  where
    checkEnv env =
      let left = evalAll original env
          right = evalAll simplified env
       in if left == right
            then Nothing
            else Just ("env " ++ showEnv env ++ " gives " ++ show left ++ " vs " ++ show right)

    evalAll design env =
      [ (assignName assignment, evalAssignment design env assignment)
      | assignment <- designAssignments design
      ]

firstJust :: [Maybe a] -> Maybe a
firstJust [] = Nothing
firstJust (Just x:_) = Just x
firstJust (Nothing:xs) = firstJust xs

showEnv :: Env -> String
showEnv env =
  "{" ++ intercalate ", " [k ++ "=" ++ boolText v | (k, v) <- Map.toList env] ++ "}"

demoMissingSignal :: Design -> String
demoMissingSignal design =
  case (designInputs design, designAssignments design) of
    ([], _) -> "No input signals in this design; missing-signal demo is not applicable."
    (_, []) -> "No assignments in this design."
    (missing:rest, assignment:_) ->
      let env = Map.fromList [(name, True) | name <- rest]
       in "Evaluate with signal '" ++ missing ++ "' missing: "
            ++ either id show (evalAssignment design env assignment)
