module CircuitEDA.Eval
  ( eval
  , evalWith
  , evalAssignment
  , renderTruthTable
  , assignments
  , equivalenceReport
  , demoMissingSignal
  ) where

import CircuitEDA.AST
import Data.List (intercalate, nub, sort)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)

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
