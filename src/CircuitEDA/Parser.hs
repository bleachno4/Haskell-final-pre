module CircuitEDA.Parser
  ( Parser(..)
  , parseDesign
  , parseExprText
  , exprParser
  , parseOr
  , parseXor
  , parseAnd
  , parseNot
  , parseAtom
  ) where

import CircuitEDA.AST
import Control.Applicative (Alternative(..))
import Data.Char (isAlpha, isAlphaNum, isSpace, toUpper)
import Data.List (nub)

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
