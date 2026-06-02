# 老师提问与答辩 Tips

这个文件用于准备老师或同学提问。  
建议每个成员都至少看一遍，尤其是“为什么这样实现”和“缺少什么”两部分。

---

## 1. 关于技术主线

### Q1：你们这个项目主要用了哪些 Haskell 知识？

答：

我们主要用了七类 Haskell 知识。

第一，代数数据类型 ADT。  
我们用 `Expr` 表示布尔电路 AST，把变量、常量、NOT、AND、OR、XOR、NAND、NOR 都变成类型构造器。

第二，递归和模式匹配。  
电路表达式是树结构，所以求值、化简、生成 netlist 都可以递归遍历 AST。模式匹配让每种门的处理逻辑很清楚。

第三，`Either` 错误处理。  
如果信号缺失或解析失败，程序返回 `Left String`，而不是默默给默认值。

第四，Functor / Applicative / Monad 的组合思想。  
parser 需要组合小解析器，eval 需要组合可能失败的子计算，netlist 生成需要组合带状态的转换。

第五，Parser Combinators。  
我们用它把表达式文本解析成 AST。

第六，State Monad 思想。  
生成 netlist 时需要自动编号中间 wire，例如 `n1`、`n2`，这正是状态传递问题。

第七，列表处理和纯函数转换。  
真值表和等价性检查需要枚举所有输入组合；Verilog-style 输出则是从 AST 到字符串代码的纯转换。

### Q2：为什么这些 Haskell 知识适合 EDA 前端？

答：

因为 EDA 前端本身包含很多结构化处理问题，比如 HDL 解析、AST、netlist、逻辑优化和仿真。这些问题和 Haskell 的优势非常匹配。

Haskell 擅长：

- 用类型表达结构；
- 用递归处理树；
- 用纯函数做结构变换；
- 用 Monad 处理失败和状态。

而 EDA 前端也正好需要这些能力。

### Q3：你们这个 demo 和真实 EDA 工具有什么关系？

答：

我们的 demo 不是完整 EDA 工具，而是一个极简前端模型。它对应真实 EDA 前端中的几个基本环节：

```text
文本输入 -> 解析 -> AST -> 语义求值 -> 简单优化 -> netlist
```

真实工具会复杂得多，比如支持完整 HDL、时序逻辑、综合优化、约束、布局布线等。我们这里只保留最小核心，用于展示 Haskell 的类型建模、递归变换、错误处理、状态传递和代码生成如何应用到 EDA。

### Q4：工业界现在一般用什么语言做这些事情？

答：

要分场景看。

| 场景 | 工业界常用语言 |
|---|---|
| RTL 设计 | Verilog / SystemVerilog / VHDL |
| 验证 testbench | SystemVerilog + UVM，Python cocotb |
| 系统级建模 / HLS | C / C++ / SystemC，MATLAB/Simulink |
| 脚本自动化 | Tcl、Python、Perl、Shell |
| EDA 工具内部 | 大量 C / C++，再加脚本语言 |
| 硬件生成器 / 新型 HDL | Scala Chisel、SpinalHDL、Python Amaranth、Haskell Clash 等 |

所以我们不能说 Haskell 是工业界 RTL 设计的主流。  
工业界手写 RTL 仍然主要是 SystemVerilog、Verilog 和 VHDL。

### Q5：那和工业界现有做法比，你们这个 Haskell demo 好在哪里？

答：

如果目标是手写一个固定 RTL 模块，Haskell 不一定更好。SystemVerilog 或 Verilog 更直接，工具链也更成熟。

Haskell 的优势在另一类任务：

- 电路生成器；
- 小型硬件 DSL；
- AST / IR 转换器；
- 逻辑化简工具；
- 等价性检查辅助工具；
- golden model / reference model；
- Verilog 代码生成器。

这些任务的共同特点是：它们需要处理、生成、转换或检查电路结构。  
Haskell 的 ADT、模式匹配、递归、纯函数、Monad 很适合这种结构化变换。

可以这样回答：

> 和工业界现有流程相比，我们这个 demo 的优势不是替代 SystemVerilog 写 RTL，而是展示如何用 Haskell 写更结构化的生成器、转换器和检查器。工业里很多脚本会直接拼字符串生成 Verilog，而我们先建立 AST，再从 AST 做求值、化简、等价性检查和代码生成，结构更清楚，也更容易加验证。

### Q6：这能不能进入生产？

答：

这个 demo 本身不能直接进入生产。  
它缺少完整 Verilog 语法、位宽、时序逻辑、模块层级、综合约束、工业级测试和工具链集成。

但它背后的方式有生产意义：

```text
先建立结构化 IR / AST
再做变换、检查和代码生成
```

这正是很多编译器、EDA 前端、RTL generator 和验证辅助工具会采用的思路。

所以准确说法是：

> 这个项目不是生产工具，而是生产相关工具思想的最小原型。

---

## 2. 关于技术实现

### Q4：为什么用 ADT 表示电路？

答：

布尔表达式天然是树形结构。

例如：

```text
(a AND b) OR (NOT c)
```

可以看成：

```text
        OR
       /  \
     AND  NOT
    /  \    \
   a    b    c
```

Haskell 的 ADT 正好可以直接表示这种结构：

```haskell
data Expr
  = Lit Bool
  | Var String
  | Not Expr
  | And Expr Expr
  | Or Expr Expr
```

这样后续求值、化简、打印和生成 netlist 都可以通过模式匹配递归完成。

### Q5：为什么不用字符串直接处理？

答：

字符串没有结构。如果直接处理字符串，求值、化简、转换时都要反复解析，容易出错。

把字符串先解析成 AST 后：

- 结构更清晰；
- 类型能约束合法形式；
- 递归处理更自然；
- 后续扩展更方便。

这是编译器和 EDA 前端常用的思路。

### Q6：你们的 parser 是怎么实现的？

答：

我们实现了一个很小的 parser combinator：

```haskell
newtype Parser a = Parser { runParser :: String -> Maybe (a, String) }
```

含义是：输入一个字符串，如果解析成功，返回结果和剩余字符串；如果失败，返回 `Nothing`。

然后给 `Parser` 实现了：

- `Functor`
- `Applicative`
- `Monad`
- `Alternative`

这样就可以把小 parser 组合成大 parser。

比如：

```haskell
parseOr = chainl1 parseAnd orOp
parseAnd = chainl1 parseNot andOp
parseNot = NOT parser <|> atom parser
```

这体现了 Haskell 中 parser combinator 的核心思想：小解析器可以像函数一样组合成大解析器。

### Q7：你们支持运算符优先级吗？

答：

支持基本优先级。

当前优先级是：

```text
NOT 最高
AND 中间
OR 最低
```

例如：

```text
a AND b OR NOT c
```

会解析为：

```text
(a AND b) OR (NOT c)
```

此外也支持括号。

### Q8：为什么 eval 返回 `Either String Bool`，而不是直接返回 `Bool`？

答：

因为求值可能失败。最典型的是表达式中引用了某个信号，但输入环境里没有这个信号。

如果直接返回 `Bool`，程序可能会错误地给一个默认值。  
用 `Either String Bool` 可以明确表示：

- `Right Bool`：求值成功；
- `Left String`：求值失败，并给出错误原因。

这更符合可靠仿真的要求。

### Q9：`(<$>)` 和 `(<*>)` 是什么意思？

答：

可以简单解释为 Applicative 风格的组合。

例如：

```haskell
eval env (And a b) = (&&) <$> eval env a <*> eval env b
```

意思是：

先求左边和右边。  
如果两个都成功，就把结果用 `&&` 合并。  
如果其中一个失败，错误会自动传播。

这避免了很多嵌套 `case`。

如果老师继续追问，可以说它利用了 `Either` 的 Applicative instance。

### Q10：为什么自己写 `SimpleState`，不用现成的 `State`？

答：

主要是展示和稳定性考虑。

我们自己写的版本是：

```haskell
newtype SimpleState s a = SimpleState { runSimpleState :: s -> (a, s) }
```

这能直接说明 State 的核心思想：

```text
旧状态 -> 结果 + 新状态
```

在我们的 netlist 生成中，状态就是：

```text
当前 wire 编号 + 已经生成的 netlist 行
```

真实项目中，我们会使用成熟库，比如 `Control.Monad.State`。  
但课堂 demo 中自己写最小版本，更容易解释，也减少环境依赖。

### Q11：netlist 生成为什么需要状态？

答：

因为转换表达式时需要自动生成中间 wire。

例如：

```text
out = (a AND b) OR (NOT c)
```

生成：

```text
n1 = AND a b
n2 = NOT c
n3 = OR n1 n2
out = BUF n3
```

`n1`、`n2`、`n3` 这些名字需要按顺序生成。  
这个“当前编号是多少”就是状态。

### Q12：你们的逻辑化简实现了什么？

答：

我们只实现了少量基础布尔代数规则，例如：

```text
NOT (NOT x) -> x
x AND TRUE -> x
x AND FALSE -> FALSE
x OR FALSE -> x
x OR TRUE -> TRUE
x AND x -> x
x OR x -> x
```

这些规则足以展示 Haskell 模式匹配如何进行 AST 重写。

---

## 3. 关于舍弃内容和不足

### Q13：你们为什么没有解析 Verilog？

答：

因为完整 Verilog 语法非常复杂，包括模块、端口、assign、always、时序逻辑、位宽、操作符优先级、generate 等。

我们只有一周时间，如果尝试解析完整 Verilog，会把重点变成语言工程和调试 parser，而不是展示 Haskell 的类型、递归、parser、错误处理和状态传递这些核心知识。

所以我们选择一个极简布尔表达式语言，保留 EDA 前端的核心思想：

```text
文本 -> AST -> 仿真 -> 化简 -> 等价性检查 -> netlist -> Verilog-style assign
```

### Q14：现在支持哪些逻辑门？为什么还不做完整门库？

答：

当前已经支持：

```text
NOT
AND
OR
XOR
NAND
NOR
TRUE / FALSE
```

其中 `NOT`、`AND`、`OR` 已经功能完备，`XOR`、`NAND`、`NOR` 是为了让 demo 更像真实数字电路，而不是只像普通布尔表达式计算器。

如果时间更多，可以加入：

- MUX
- implication
- half-adder/full-adder 作为可复用组件
- parameterized bus-width operations

我们没有继续扩展完整门库，是为了控制范围。因为本次核心不是“门越多越好”，而是展示从 parser、AST、truth table、simplify、equivalence check 到 netlist/code generation 的完整前端流程。

### Q15：为什么只支持组合逻辑，不支持时序逻辑？

答：

时序逻辑需要处理状态、时钟、寄存器和时间步进，复杂度会明显增加。

例如触发器需要考虑：

- 当前状态；
- 下一状态；
- 时钟边沿；
- reset；
- 多周期仿真。

我们本次重点是展示 Haskell 对结构和变换的表达能力，所以先选择组合逻辑。组合逻辑没有时间维度，更适合一周内做出完整 demo。

### Q16：为什么没有做 Karnaugh map 或 Quine-McCluskey？

答：

这些属于更深入的逻辑优化算法，和本次主线相比工作量较大。

我们的主线是：

```text
Haskell 知识点 -> EDA 前端应用
```

而不是：

```text
实现完整逻辑最小化算法
```

因此我们只做了基础重写规则，作为逻辑优化的示意。

### Q17：为什么没有使用 QuickCheck？

答：

QuickCheck 很适合做扩展，比如随机生成输入，验证化简前后的表达式等价。

但是由于时间限制，我们没有引入 QuickCheck 这个额外库，而是先实现了一个更直观的穷举等价性检查：

```text
对所有输入组合分别计算原表达式和化简后表达式。
如果所有输出都一致，就报告 equivalent。
```

例如程序会输出：

```text
check : equivalent on all 4 input combinations
```

所以我们并不是完全没有验证，而是选择了对小规模布尔电路更容易解释的穷举验证。  
如果继续做，可以再引入 QuickCheck 检查：

```text
eval env expr == eval env (simplify expr)
```

### Q18：为什么没有 GUI？

答：

GUI 会增加前端开发工作量，但对展示 Haskell 的核心技术点帮助不大。

目前命令行输出已经可以清楚展示：

- AST；
- 多输出 truth table；
- exhaustive equivalence check；
- netlist；
- Verilog-style assign；
- parse error；
- missing signal error。

所以我们没有把时间花在 GUI 上。

### Q19：你们已经输出 Verilog 了吗？和真实 Verilog netlist 有什么区别？

答：

我们现在有两种输出。

第一种是教学版文本 netlist：

```text
n1 = AND a b
n2 = NOT c
out = BUF n2
```

第二种是 Verilog-style `assign` 输出，例如：

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

它已经接近 Verilog 组合逻辑描述，但还不是完整工业级 Verilog netlist。  
缺少的部分包括位宽、wire 声明优化、模块实例化、always block、时序逻辑和综合约束。

所以回答时可以说：我们做了 Verilog-style code generation，但没有声称它是完整综合级 netlist。

---

## 4. 关于代码可靠性

### Q20：你们怎么验证程序是对的？

答：

我们做了几类验证。

第一，基础表达式：

```text
out = (a AND b) OR (NOT c)
```

检查真值表是否符合手算结果。

第二，MUX：

```text
out = ((NOT sel) AND a) OR (sel AND b)
```

检查 `sel = 0` 输出 `a`，`sel = 1` 输出 `b`。

第三，simplify：

```text
out = (a AND TRUE) OR (NOT (NOT b))
```

检查化简结果是否为：

```text
a OR b
```

同时程序会穷举所有输入组合并输出：

```text
check : equivalent on all 4 input combinations
```

这说明化简前后语义一致。

第四，full adder：

```text
sum = a XOR b XOR cin
carry = (a AND b) OR (cin AND (a XOR b))
```

检查多输出真值表是否符合一位全加器行为。

第五，advanced gates：

```text
out = (a NAND b) NOR (c XOR d)
```

检查 XOR、NAND、NOR 是否能被 parser、eval、truth table、netlist 和 Verilog-style output 全流程处理。

第六，bad syntax：

```text
out = (a AND) OR b
```

检查 parser 是否返回错误。

第七，missing signal：

检查缺少变量时是否输出：

```text
unknown signal: a
```

如果项目继续扩展，应该加入自动化测试、QuickCheck 或 SAT-based equivalence checking。

### Q21：化简后如何保证语义不变？

答：

目前我们使用的是基本布尔代数恒等式，这些规则本身是语义保持的。

例如：

```text
x AND TRUE = x
NOT (NOT x) = x
```

我们现在已经写了自动穷举等价性检查。  
程序会对化简前后的设计生成所有输入组合，并逐行比较输出是否一致。

对于小规模组合逻辑，这种穷举检查非常直观，也适合课堂展示。  
进一步可以用 QuickCheck 或 SAT solver 做更系统、更可扩展的验证。

### Q22：parser 会不会有歧义？

答：

我们通过固定优先级减少歧义：

```text
NOT > AND/NAND > XOR > OR/NOR
```

同时支持括号。  
但它不是完整语言 parser，不支持所有可能的边界情况。  
例如不支持位宽、不支持完整 Verilog 表达式、不支持 always block 和 generate。

这属于我们主动控制范围的结果。

---

## 5. 关于 Haskell 语言点

### Q23：这个项目最能体现 Haskell 哪些特点？

答：

主要体现五点：

1. ADT 直接描述领域模型。
2. 模式匹配让树遍历和重写非常清晰。
3. 纯函数适合做结构转换。
4. `Either` 把失败计算写进类型。
5. State monad 思想可以管理自动编号这样的状态。

### Q24：这个项目是不是必须用 Haskell？

答：

不是。其他语言当然也可以实现。

但 Haskell 的优势在于表达更直接：

- AST 用 ADT 很自然；
- eval 和 simplify 用模式匹配很清楚；
- parser combinator 是函数式语言的经典应用；
- State 和 Either 让状态和错误处理更显式。

所以 Haskell 不是唯一选择，但它非常适合展示这类结构化 EDA 前端问题。

### Q25：Type Classes 在代码里体现得够不够？

答：

我们代码里没有把每个行为都抽象成 type class，这是有意控制范围。

但 Type Classes 的思想可以通过行为抽象来解释：

- `Show Expr`：表达式如何显示；
- `Pretty` 思想：表达式如何漂亮打印；
- `Eval` 思想：表达式如何求值；
- `Netlistable` 思想：表达式如何生成 netlist。

如果继续扩展，可以写成：

```haskell
class Pretty a where
  pretty :: a -> String

class Netlistable a where
  toNetlist :: a -> String
```

本次为了保持代码集中，没有过度抽象。

### Q26：Monad 在这里是不是讲得太少？

答：

我们没有从抽象定义开始讲 Monad，而是从具体问题讲：

- parser 需要失败和组合；
- eval 需要错误传播；
- netlist 需要状态编号。

这些都是 Monad 或 Applicative 常见应用场景。

对于课堂展示来说，从具体问题出发比直接讲抽象 Monad laws 更容易理解。

---

## 6. 如果老师要求现场改一个表达式

可以这样做：

```powershell
cd D:\Haskell\finalpre
.\outputs\functional_eda_demo.exe --expr "(x AND y) OR (!z)"
```

或者新建一个文件，例如 `examples\custom.logic`：

```text
out = (x AND y) OR (!z)
```

再运行：

```powershell
.\outputs\functional_eda_demo.exe examples\custom.logic
```

支持的语法：

```text
NOT x        或 !x
x AND y      或 x && y
x OR y       或 x || y
TRUE/FALSE   或 1/0
括号
```

---

## 7. 如果现场环境出问题

### 情况 1：PowerShell 不让运行脚本

可以用：

```bat
run_demo.bat
```

或者直接运行 exe：

```powershell
.\outputs\functional_eda_demo.exe
```

### 情况 2：GHC 编译失败

直接运行已经编译好的 exe：

```powershell
.\outputs\functional_eda_demo.exe
```

### 情况 3：exe 也打不开

打开备用输出：

```text
D:\Haskell\finalpre\outputs\demo_output.txt
```

然后照着输出讲。

### 情况 4：老师想看源码

打开：

```text
D:\Haskell\finalpre\src\CircuitEDA.hs
```

重点看：

- `data Expr`
- `parseDesign`
- `eval`
- `evalAssignment`
- `simplify`
- `equivalenceReport`
- `renderNetlist`
- `renderVerilog`

---

## 8. 最推荐背熟的几句话

### 句子 1

我们不是实现完整 EDA 工具，而是用一个极简组合逻辑前端展示 Haskell 的类型系统、模式匹配、parser 组合、错误处理和状态传递如何落地。

### 句子 2

布尔电路表达式天然是树形结构，所以 Haskell 的代数数据类型和模式匹配非常适合表达和处理它。

### 句子 3

`Either String Bool` 的意义是把“求值可能失败”写进类型，避免未知信号被程序默默忽略。

### 句子 4

State monad 在这里解决的是自动生成中间 wire 名称的问题，本质上是管理当前编号这个状态。

### 句子 5

由于只有一周时间，我们主动舍弃了完整 Verilog 解析、时序逻辑、复杂优化和 GUI，优先保证 parse、AST、多输出 truth table、simplify、equivalence check、netlist、Verilog-style assign 这个核心闭环。

---

## 9. 老师如果问“你们下一步最值得做什么”

推荐回答：

下一步最值得做的是三件事。

第一，引入 QuickCheck 或 SAT solver，让等价性检查从小规模穷举升级成更系统的验证。

第二，把现在的 Verilog-style `assign` 扩展成更标准的 Verilog netlist，例如加入 wire 声明、位宽和模块端口规范：

```verilog
wire n1;
assign n1 = a & b;
assign out = n1 | ~c;
```

第三，支持简单 Verilog 子集的输入解析，而不是只解析我们自定义的 `.logic` 表达式语言。

这三个扩展都和当前代码自然衔接，而且工作量比直接做完整 EDA 工具更可控。
