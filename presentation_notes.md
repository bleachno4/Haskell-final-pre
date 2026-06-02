# Presentation Notes

## 0. 标题

**Functional EDA: Using Haskell to Model and Simulate Boolean Circuits**

中文标题：

**函数式 EDA：用 Haskell 表示与仿真布尔电路**

## 1. 开场：为什么把 Haskell 和 EDA 放在一起？

可以这样说：

> EDA 中有很多任务不是直接画电路，而是处理“结构”：比如解析 HDL、建立语法树、生成 netlist、做逻辑仿真和优化。Haskell 的代数数据类型、模式匹配和函数式组合方式，正好适合表达这种结构和变换。

本次 demo 不做完整 EDA 软件，只做一个极简前端：

```text
布尔表达式/多输出设计 -> AST -> 真值表 -> 化简 -> 等价性检查 -> netlist -> Verilog-style assign
```

补充定位：

```text
生产 RTL：SystemVerilog / Verilog / VHDL 仍是主流
验证：SystemVerilog UVM、Python cocotb 常见
系统级建模：C++ / SystemC 常见
脚本自动化：Python / Tcl / Perl 常见
我们的方向：用 Haskell 展示电路生成器、AST 转换器、检查器、参考模型这类工具思想
```

可以这样说：

> 如果目标是手写生产 RTL，Haskell 不占优势；如果目标是写电路生成器、AST 转换器、等价性检查器或参考模型，Haskell 的类型系统和函数式变换会比较有优势。

## 2. 本项目用到的 Haskell 知识

重点说明这不是单纯做 EDA，也不是只讲语法点，而是用一个 EDA demo 串起多个 Haskell 知识点：

- ADT：用 `Expr` 表示电路 AST。
- 递归和模式匹配：遍历、求值、化简电路树。
- `Either`：把未知信号、解析失败等错误写进类型。
- Functor / Applicative / Monad：组合 parser、组合可能失败的计算、组合带状态的转换。
- Parser combinators：把字符串解析成 AST。
- State Monad 思想：自动生成 netlist 中的中间 wire 名称。
- List processing：穷举输入组合，生成真值表并做等价性检查。
- Pure code generation：输出 Verilog-style `assign`。

押题版说法：

```text
Maybe / Either：表达失败，不靠异常或默认值。
Functor：用 <$> 只变换成功值，例如 Not <$> parseNot。
Applicative：用 <*> 组合多个可能失败的子计算，例如 AND 左右两边求值。
Monad：用 do / >>= 串起依赖前一步结果的计算，例如 parser 和 State netlist。
Alternative：用 <|> 表达 parser 分支选择。
```

如果老师追问，按这个公式回答：

```text
概念是什么 -> 代码里哪里用了 -> 为什么适合 EDA demo
```

## 3. Demo 1：基础表达式

样例文件：

```text
examples/basic.logic
```

输入：

```text
out = (a AND b) OR (NOT c)
```

讲解点：

- 这是一个组合逻辑表达式。
- Haskell parser 把它变成 `Expr` AST。
- `eval` 枚举输入并输出真值表。
- `renderNetlist` 生成类似 EDA netlist 的中间形式。
- `renderVerilog` 输出 Verilog-style `assign`。

## 4. Demo 2：MUX

样例文件：

```text
examples/mux.logic
```

输入：

```text
out = ((NOT sel) AND a) OR (sel AND b)
```

讲解点：

- 这是 2-to-1 multiplexer 的经典布尔表达式。
- 当 `sel = 0` 时输出 `a`，当 `sel = 1` 时输出 `b`。
- 可以用真值表验证行为。

## 5. Demo 3：Full Adder 多输出模块

样例文件：

```text
examples/full_adder.logic
```

输入：

```text
sum = a XOR b XOR cin
carry = (a AND b) OR (cin AND (a XOR b))
```

讲解点：

- 这是一位全加器，不是单输出表达式。
- 程序会同时输出 `sum` 和 `carry` 的真值表。
- 这个样例能说明 demo 已经支持多输出组合逻辑模块。

## 6. Demo 4：逻辑化简与等价性检查

样例文件：

```text
examples/simplify.logic
```

输入：

```text
out = (a AND TRUE) OR (NOT (NOT b))
```

程序会化简为：

```text
out = a OR b
```

讲解点：

- 化简规则通过模式匹配实现。
- `Not (Not x) -> x`
- `And x TRUE -> x`
- 这对应 EDA 中逻辑优化的简化版。
- 程序会输出 `equivalent on all ... input combinations`，说明化简前后语义一致。

## 7. Demo 5：高级门

样例文件：

```text
examples/advanced_gates.logic
```

输入：

```text
out = (a NAND b) NOR (c XOR d)
```

讲解点：

- parser 支持 XOR、NAND、NOR。
- AST、truth table、netlist、Verilog-style output 都能处理这些门。

## 8. Demo 6：错误处理

程序会展示：

```text
Evaluate with signal 'a' missing: unknown signal: a
```

讲解点：

- 如果仿真环境里缺少信号，程序不会随便给默认值。
- `eval` 的类型是：

```haskell
eval :: Env -> Expr -> Either String Bool
```

这说明计算结果可能是：

- `Right Bool`：成功得到输出。
- `Left String`：失败并给出错误原因。

## 9. 核心代码片段 1：AST

```haskell
data Expr
  = Lit Bool
  | Var String
  | Not Expr
  | And Expr Expr
  | Or Expr Expr
  | Xor Expr Expr
  | Nand Expr Expr
  | Nor Expr Expr
```

讲解点：

- 电路表达式是递归结构。
- `Var` 是输入信号。
- `Not`、`And`、`Or`、`Xor`、`Nand`、`Nor` 是逻辑门。
- 整个表达式就是一棵树。

## 10. 核心代码片段 2：求值

```haskell
eval :: Env -> Expr -> Either String Bool
eval _ (Lit b) = Right b
eval env (Var x) =
  case Map.lookup x env of
    Just b -> Right b
    Nothing -> Left ("unknown signal: " ++ x)
eval env (Not e) = not <$> eval env e
eval env (And a b) = (&&) <$> eval env a <*> eval env b
eval env (Or a b) = (||) <$> eval env a <*> eval env b
eval env (Xor a b) = (/=) <$> eval env a <*> eval env b
```

讲解点：

- 模式匹配对应不同电路节点。
- 递归求值对应遍历电路树。
- `Either` 让错误处理显式化。

## 11. 核心代码片段 3：State 风格 netlist

可以这样解释：

> 从表达式生成 netlist 时，需要自动产生中间 wire，比如 `n1`、`n2`。这其实就是一个状态：当前已经用了几个编号。State Monad 可以把这个状态传递隐藏起来，让转换函数更干净。

输出例子：

```text
n1 = AND a b
n2 = NOT c
n3 = OR n1 n2
out = BUF n3
```

## 12. 核心代码片段 4：Verilog-style 输出

输出例子：

```verilog
module functional_eda_demo(
  input a,
  input b,
  input c,
  output out
);
  assign out = ((a & b) | (~c));
endmodule
```

讲解点：

- 这不是完整工业 Verilog netlist，但已经展示了 code generation。
- 可以作为进一步扩展到 Verilog 子集或 BLIF 的基础。

## 13. 结尾总结

可以这样收尾：

> 这个 demo 虽然仍然是教学规模，但已经包含多输出组合逻辑、XOR/NAND/NOR、化简前后等价性检查、State 风格 netlist 和 Verilog-style 输出。它展示了函数式编程在 EDA 前端中的典型价值：用类型表示结构，用纯函数做变换，用 Monad 处理失败和状态。

## 14. 四人讲解分配

原则：四个人都讲代码。A 只用很短时间做开场，然后主要负责 parser；背景和选题动机不作为单独工作量。

| 成员 | 代码模块 | 建议讲解内容 |
|---|---|
| A | `src/CircuitEDA/Parser.hs`：`Parser`、`parseDesign`、`exprParser`、`parseOr/parseXor/parseAnd/parseNot` | 1 分钟开场；讲输入语言、parser combinator、优先级、bad syntax 错误 |
| B | `src/CircuitEDA/AST.hs`：`Expr`、`Design`、`pretty`、`vars`、`gateCount`、`depth`、`renderTree` | 讲 AST、ADT、递归、模式匹配，展示电路树和结构分析 |
| C | `src/CircuitEDA/Eval.hs`：`eval`、`evalAssignment`、`renderTruthTable`、`equivalenceReport`、`demoMissingSignal` | 讲 `Either`、Applicative、多输出 truth table、full adder、等价性检查 |
| D | `src/CircuitEDA/Transform.hs`：`simplify`、`SimpleState`、`renderNetlist`、`renderVerilog`、运行脚本 | 讲模式匹配化简、State 风格 netlist、Verilog-style output，负责现场集成运行 |

## 15. 时间控制

建议 20 分钟：

- 0-1 min：A 开场和题目定位
- 1-5 min：A 讲输入语言和 parser combinator
- 5-9 min：B 讲 AST、ADT、递归和结构分析
- 9-14 min：C 讲求值、`Either`、truth table、full adder 和 equivalence check
- 14-19 min：D 讲 simplify、State netlist、Verilog-style output 和现场运行
- 19-20 min：全组总结：Haskell 适合做结构化生成、转换和检查，不是替代主流 RTL 语言
