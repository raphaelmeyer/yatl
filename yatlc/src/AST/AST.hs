module AST.AST where

newtype Tree = Tree [Function]
  deriving (Eq, Show)

data Function = Function
  deriving (Eq, Show)
