# Functional EDA Demo in Haskell

本文件夹是 Haskell 课程小组 presentation 的程序与 demo 交付包。

主题：

> 函数式 EDA：用 Haskell 表示、仿真与转换布尔电路

核心展示链路：

```text
布尔表达式文本
  -> Parser Combinators
  -> Expr AST
  -> eval / truth table
  -> simplify
  -> exhaustive equivalence check
  -> State monad style netlist generation
  -> Verilog-style assign output
```

## 1. 如何运行

在 `D:\Haskell\finalpre` 目录下运行：

```powershell
.\run_demo.ps1
```

或者双击 / 命令行运行：

```bat
run_demo.bat
```

如果只想用 `runghc` 直接跑：

```powershell
runghc -isrc src\Main.hs
```

指定某个样例：

```powershell
runghc -isrc src\Main.hs examples\basic.logic
```

直接输入表达式：

```powershell
runghc -isrc src\Main.hs --expr "(a AND b) OR NOT c"
```

## 2. 文件结构

```text
finalpre/
  README.md
  presentation_notes.md
  演讲稿_详细版.md
  tips.md
  Haskell_EDA_Haskell技术主线说明.pdf
  run_demo.bat
  run_demo.ps1
  src/
    CircuitEDA.hs
    CircuitEDA/
      AST.hs
      Parser.hs
      Eval.hs
      Transform.hs
    Main.hs
  examples/
    basic.logic
    mux.logic
    full_adder.logic
    simplify.logic
    advanced_gates.logic
    majority.logic
    bad_syntax.logic
  outputs/
    demo_output.txt
    functional_eda_demo.exe
  archive/
    Haskell_EDA_选题与一周执行方案_旧版.pdf
```

其中：

- `src/CircuitEDA.hs`：对外统一导出模块，`Main.hs` 只需要 `import CircuitEDA`。
- `src/CircuitEDA/Parser.hs`：A 负责，输入语言、parser combinator、表达式优先级和解析失败。
- `src/CircuitEDA/AST.hs`：B 负责，`Expr`、`Design`、pretty print、变量分析、门数量、深度和 AST 树。
- `src/CircuitEDA/Eval.hs`：C 负责，`eval`、`Either` 错误处理、truth table、等价性检查和缺失信号 demo。
- `src/CircuitEDA/Transform.hs`：D 负责，逻辑化简、State 风格 netlist 和 Verilog-style 输出。
- `src/Main.hs`：命令行 demo 入口。
- `examples/*.logic`：课堂展示用样例电路。
- `outputs/demo_output.txt`：已保存的一份运行结果，现场环境出问题时可以作为备用展示。
- `演讲稿_详细版.md`：四人小组展示用详细台词，包含技术细节、demo 指令、取舍说明。
- `tips.md`：答辩问答库，用于应对老师追问“为什么这样做、缺少什么、舍弃了什么”。
- `Haskell_EDA_Haskell技术主线说明.pdf`：新版技术主线 PDF，重点说明用了哪些 Haskell 知识、这些知识是什么、为什么适合 EDA demo。
- `archive/`：旧版选题材料归档。正式展示优先使用新版技术主线 PDF、演讲稿和 tips。

## 3. 表达式语法

支持：

```text
NOT x        或 !x
x AND y      或 x && y
x OR y       或 x || y
x XOR y      或 x ^ y
x NAND y
x NOR y
TRUE/FALSE   或 1/0
括号：        (a AND b) OR NOT c
```

样例：

```text
out = (a AND b) OR (NOT c)
```

也支持多输出组合逻辑模块：

```text
sum = a XOR b XOR cin
carry = (a AND b) OR (cin AND (a XOR b))
```

## 4. 本项目用到的 Haskell 知识

| 程序部分 | Haskell 知识 | EDA 含义 |
|---|---|---|
| `data Expr = ...` | Algebraic Data Types | 用 AST 表示电路结构 |
| `eval` / `simplify` | Recursion + Pattern Matching | 遍历、求值、改写电路树 |
| parser combinators | Monadic parser combinators | 把文本表达式解析成电路 AST |
| `eval :: Env -> Expr -> Either String Bool` | Maybe / Either / Applicative | 仿真时处理未知信号 |
| `simplify` | Pattern matching | 逻辑化简规则 |
| `equivalenceReport` | Exhaustive checking / list processing | 穷举输入，验证化简前后等价 |
| `renderNetlist` | State monad 思想 | 自动生成中间 wire 名称 |
| `renderVerilog` | DSL / code generation | 输出 Verilog-style `assign` |
| `truth table` | List processing | 枚举输入组合并仿真 |

## 5. 推荐现场演示顺序

1. 先运行 `examples/basic.logic`，说明从表达式到 AST、真值表、netlist。
2. 再运行 `examples/full_adder.logic`，展示多输出组合逻辑模块。
3. 再运行 `examples/simplify.logic`，展示模式匹配化简和穷举等价性检查。
4. 再运行 `examples/advanced_gates.logic`，展示 XOR/NAND/NOR 等更像电路的门。
5. 最后展示 `examples/bad_syntax.logic`，说明 parser 能发现非法输入。

命令：

```powershell
runghc -isrc src\Main.hs examples\basic.logic examples\full_adder.logic examples\simplify.logic examples\advanced_gates.logic examples\bad_syntax.logic
```

## 6. 一周内的建议分工

原则：四个人都要能打开自己负责的 `.hs` 文件讲代码，A 只用 1 分钟做题目定位和背景引入，不能只负责“选题”。建议按 EDA 前端流水线拆分，每个人负责一个真实代码模块。

| 成员 | 代码责任 | 展示责任 | 工作量 |
|---|---|---|
| A | `src/CircuitEDA/Parser.hs`：`Parser`、`parseDesign`、`exprParser`、`parseOr/parseXor/parseAnd/parseNot`、`examples/bad_syntax.logic` | 开场 1 分钟；讲为什么要先把文本解析成 AST；讲 parser combinator、优先级、解析失败 | 约 25% |
| B | `src/CircuitEDA/AST.hs`：`Expr`、`Assignment`、`Design`、`pretty`、`vars`、`gateCount`、`depth`、`renderTree` | 讲 ADT、递归、模式匹配如何表示电路树；展示 AST 树、门数量、深度 | 约 24% |
| C | `src/CircuitEDA/Eval.hs`：`eval`、`evalWith`、`evalAssignment`、`renderTruthTable`、`equivalenceReport`、`demoMissingSignal` | 讲 `Either`、Applicative、未知信号错误、多输出真值表、穷举等价性检查 | 约 27% |
| D | `src/CircuitEDA/Transform.hs`：`simplify`、`simplifyDesign`、`SimpleState`、`renderNetlist`、`renderVerilog`、`run_demo.ps1/.bat` | 讲模式匹配化简、State 风格编号、netlist、Verilog-style 输出和现场集成运行 | 约 24% |

详细分工见 `分工与工作量.md`。

## 7. 现场备用方案

如果现场 Haskell 环境出问题：

1. 打开 `outputs/demo_output.txt` 展示完整运行结果。
2. 用 `examples/*.logic` 展示输入。
3. 用 `src/CircuitEDA/Parser.hs`、`AST.hs`、`Eval.hs`、`Transform.hs` 展示关键代码片段。

这样即使不现场编译，也能完整讲完。
