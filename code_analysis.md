# SQS(16) 搜索代码逐行分析（`searchAi.cpp`）

> **目标读者**：知道 Steiner 系统 $S(t,k,v)$ 的定义、了解 C++ 基本语法，但不一定熟悉组合设计或位运算技巧。
>
> **目标**：读完本文后，能从零开始理解 `searchAi.cpp` 中每一个函数、每一行关键代码的含义。

---

## 第一部分：问题与基本概念

### 1.1 什么是 SQS(16)

**Steiner 四元系统** $S(3,4,16)$，简称 SQS(16)，是定义在 16 个元素 $\{0,1,\dots,15\}$ 上的一个**四元组（block）集合**，满足：

- 每个四元组含 4 个不同元素；
- 元素集 $\{0,\dots,15\}$ 的**每个三元子集恰好出现在一个四元组中**。

由计数：三元子集总数 $= \binom{16}{3} = 560$，每个四元组覆盖 $\binom{4}{3}=4$ 个三元子集，所以四元组总数

$$\text{Num\_16} = \frac{560}{4} = 140$$

代码第 29 行：
```cpp
const int Num_16 = N_16 * (N_16 - 1) * (N_16 - 2) / 6 / 4;  // = 140
```

### 1.2 导出系统 A_i（核心思想）

给定一个 SQS(16)，对每个元素 $i$，定义**导出系统**：

> $A_i$ = 把 SQS(16) 中所有含 $i$ 的四元组取出，删掉 $i$，得到的三元组集合。

性质：$A_i$ 是基底 $\{0,\dots,15\}\setminus\{i\}$（15 个元素）上的 **STS(15)** = $S(2,3,15)$，恰含 $\frac{\binom{15}{2}}{\binom{3}{2}} = 35$ 个三元组。

代码第 30 行：
```cpp
const int Num_15 = N_15 * (N_15 - 1) / 2 / 3;  // = 35
```

**关键洞察**：构造 SQS(16) ⟺ 构造一组两两兼容的 $(A_0, A_1, \dots, A_{15})$。

### 1.3 孙子结构 A_{i,j}

对 $i \neq j$，定义：

> $A_{i,j}$ = 把 SQS(16) 中同时含 $i$ 和 $j$ 的四元组取出，删去 $i, j$，得到的二元组集合。

$A_{i,j}$ 是 14 个元素上的 **perfect matching**（7 条不相交边），且满足对称性 $A_{i,j} = A_{j,i}$。

这是约束不同 $A_i$ 相容的核心：$A_i$ 中含 $j$ 的三元组去 $j$ 后 = $A_j$ 中含 $i$ 的三元组去 $i$ 后。

### 1.4 四视角一致性

四元组 $\{a,b,c,d\} \in$ SQS 在四个导出系统中各贡献一个三元组：

| 导出系统 | 三元组 |
|----------|--------|
| $A_a$ | $\{b,c,d\}$ |
| $A_b$ | $\{a,c,d\}$ |
| $A_c$ | $\{a,b,d\}$ |
| $A_d$ | $\{a,b,c\}$ |

**逆命题（拼接合法性的依据）**：若正在确定 $A_z$，其某三元组 $\{p,q,r\}$ 中 $r > z$ 且 $A_r$ 已固定，则该三元组所属四元组只能是 $\{p,q,r,z\}$。四视角一致性要求 $A_r$ 必须已含 $\{p,q,z\}$。代码中 `check` 函数正是逐高位地强制这一条件。

---

## 第二部分：数据结构与全局变量

### 2.1 三元组的表示（`tuple3`）

```cpp
// 第 33-53 行
struct tuple3 {
    int a, b, c;      // 三个元素（已排序：a < b < c）
    int state;        // state = (1<<a) | (1<<b) | (1<<c)，位掩码

    tuple3(int a, int b, int c) {
        this->a = a; this->b = b; this->c = c;
        this->state = (1 << a) + (1 << b) + (1 << c);
    }

    bool operator<(const tuple3 &x) const {
        return a == x.a ? (b == x.b ? (c < x.c) : (b < x.b)) : a < x.a;
    }
} Ai[N_16][Num_15];  // 16 个导出系统，每个 35 个三元组
```

**`state` 的作用**：用 16 位整数中 3 个 bit 的组合唯一标识一个三元组。例如 $\{2,5,7\}$ → `state = (1<<2)|(1<<5)|(1<<7) = 0b00100100 = 164`。这使得"该三元组是否出现过"可以用数组下标快速查询。

### 2.2 核心去重数组

```cpp
// 第 118-119 行
int  mask[1 << N_16 + 1];        // mask[state] = 该三元组当前被多少个已固定 A_i 占用
bool maskAi[N_16][1 << N_16 + 1]; // maskAi[i][state] = A_i 是否含此三元组
```

- **`mask`**：全局去重。由 SQS 性质，同一三元组在不同 $A_i$ 中至多出现一次，所以 `mask[state]` 实际只取 0 或 1（但用 int 是为了方便增减）。
- **`maskAi`**：按 $A_i$ 区分的标记。`check` 函数用它做"高位对偶必须由特定 $A_r$ 提供"的验证。

### 2.3 虚拟编号系统（`sed_map` / `arcMask`）

枚举 $A_z$ 时，$A_z$ 中"含 15"的 7 个三元组必须等于 $A_{15}$ 中"含 $z$"的 7 个三元组。这 7 个三元组对应的 7 条二元组称为 **son_blocks**，覆盖 $\{0,\dots,15\}\setminus\{z,15\}$ 共 14 个元素，构成一个 perfect matching。

为统一处理所有 $z$，把 14 个元素重新编号为虚拟 $0..13$：

```cpp
// sed_map[2i]   = son_blocks[i].first   （真实元素）
// sed_map[2i+1] = son_blocks[i].second  （真实元素）
// sed_map[14]   = 15                    （被扣掉的 15 固定映射）
```

这样 son_blocks 在虚拟空间恒为 $(0,1),(2,3),\dots,(12,13)$，所有 $A_z$ 的搜索都在统一基底上进行，最后经 `sed_map` 还原真实元素。

`arcMask[j][k]` 给每个**非 son-block 的虚拟二元组** $(j,k)$ 分配唯一 bit：

```cpp
// 第 262-286 行 PRE() 函数
c = 1, full_mask = 0;
for (j = 0; j < 12; j++)
    for (k = j+1; k < 12; k++) {
        if (k == j+1 && j%2 == 0) continue;  // 跳过 son-block 自配对边 (0,1),(2,3),...
        arcMask[j][k] = arcMask[k][j] = c;   // 分配 bit
        reverse_map[...][c] = {j, k};         // 反查
        full_mask |= c;
        c += c;  // 下一个 bit
    }
```

共 $\binom{12}{2} - 6 = 60$ 条边。`full_mask` 是这 60 条边的并集，用于后续"是否覆盖所有边"的检查。

### 2.4 其他关键全局变量速查

| 变量 | 含义 |
|------|------|
| `Matchings13[]` / `matching13[][2]` | 虚拟行 13 的 6 边匹配占位 + 与行 11/10 配对的端点 |
| `Matchings12[]` / `matching12[][2]` | 虚拟行 12 的 6 边匹配占位 + 与行 11/10 配对的端点 |
| `tuple11[i][j][]` / `tuple10[i][j][]` | 行 11/10 的 4 三元组（按配对端点索引） |
| `tuple0_9[]` / `element0_9[][3]` | $\{0..9\}$ 内合法三元组的占位与元素 |
| `sol0_9[]` / `id_map` | 下半 8 三元组解集，按二元组占位归类 |
| `ordMatchings0_11[]` | 12 元素 perfect matching 哈希值→序号反查 |
| `preSolveAz[z][]` | 按"A_z 与 A_14 孙子结构哈希"分桶的 $A_z$ 候选 |
| `reorder[z][]` | $A_z$ 视角下 12 个有效元素 ↔ $0..11$ 的重映射 |
| `m1Values[z]` | 主搜索阶段各 $z$ 的孙子结构哈希 |
| `tuple0_6states` | $\{0..6\}$ 折半解表（已排序），供二分查找 |

---

## 第三部分：程序流程总览

```
main()
├── 读入 A_15（35 个三元组）→ Ai[15][]，累加 mask / maskAi[15]
├── generate0_6Tuples()          // 预生成 {0..6} 折半表
└── solveForAi()
    ├── 初始化 reorder[z][]（z=7..13）
    ├── for z = 13..7:
    │     PreSolveForAi(z)        // 枚举 A_z 候选并分桶
    ├── PreSolveForAi(14)         // 准备 A_14 折半数据
    └── for 每个 A_14 候选:
          ├── Generate_seeds(..., Ai[14])  // 组装完整 A_14
          ├── 累加 mask / maskAi[14]
          ├── GenerateSQS16()             // 预填 A_z 已知项 + 递归
          │   ├── for z=13..7: 填 13 项 + 算 m1Values[z]
          │   └── ConcatAi(13)             // 递归拼接
          │       ├── 取桶 preSolveAz[13][m1Ord]
          │       ├── for item in bucket:
          │       │     check(item) → 通过则填 22 项 → ConcatAi(12)
          │       └── ... 直到 z=6
          │           └── 二分查 {0..6} 补全表 → 输出 SQS(16)
          └── 撤销 mask / maskAi[14]
```

---

## 第四部分：逐函数详解

### 4.1 `main()`（第 876-909 行）

```cpp
freopen("NewS(2,3,15).txt", "r", stdin);  // 读输入
freopen("out.txt", "w", stdout);          // 输出重定向

for (int t = 0; t < 1; t++) {  // 只用第 1 个 STS(15)
    for (int i = 0; i < Num_15; i++) {
        Ai[15][i] = tuple3{getch(), getch(), getch()};  // 读 3 个 hex 字符
        int v = (1 << Ai[15][i].a) | (1 << Ai[15][i].b) | (1 << Ai[15][i].c);
        mask[v]++;            // 标记该三元组已被 A_15 占用
        maskAi[15][v] = true; // A_15 含此三元组
    }
}
```

**`getch()`**（第 57-68 行）：从 stdin 逐字符读，跳过非 hex 字符，返回 $0..15$ 的整数值。

**`int2ch()`**（第 78-81 行）：$0..9$ → `'0'..'9'`，$10..15$ → `'A'..'F'`。

读完 $A_{15}$ 后调用 `generate0_6Tuples()` 预生成边界表，再进入 `solveForAi()`。

---

### 4.2 `generate0_6Tuples()` + `search0_6Tuples()`（第 824-874 行）

**目的**：预先生成 $\{0..6\}$ 上所有合法的"四元组覆盖方案"，供递归终点二分查找。

**步骤 1**：枚举 $\{0..6\}$ 的 $\binom{7}{3}=35$ 个三元组，建立 `state→序号` 映射 `triplesBits2Ord[]`，并记录全集掩码 `tuples0_6FullMask`：

```cpp
for (i...) for (j>i...) for (k>j...) {
    triples0_6[cnt][0..2] = {i,j,k};
    triplesBits2Ord[(1<<i)+(1<<j)+(1<<k)] = cnt;
    tuples0_6FullMask |= 1ull << (ull)cnt;  // 35 个 bit 全置位
    cnt++;
}
```

**步骤 2**：枚举 $\{0..6\}$ 的 $\binom{7}{4}=35$ 个四元组，存入 `tuples0_6[]`。

**步骤 3**：`search0_6Tuples(dep, las, state, triplesSelect)` 深度优先搜索所有合法的四元组子集：

```cpp
void search0_6Tuples(int dep, int las, ull state, ull triplesSelect) {
    tuple0_6states.pb(mp(triplesSelect, state));  // 记录当前状态（含空集）
    if (dep == 10) return;  // 深度上限
    for (int i = las+1; i < cnt; i++) {
        // 选第 i 个四元组，检查它覆盖的 4 个三元组是否未被占用
        int allBitsValue = (1<<t0) + (1<<t1) + (1<<t2) + (1<<t3);
        ull tmpValue = 0;
        for (int j = 0; j < 4; j++) {
            int triValue = allBitsValue ^ (1 << tuples0_6[i][j]);  // 去掉一个元素得到三元组
            tmpValue |= 1ull << (ull)triplesBits2Ord[triValue];
        }
        if (triplesSelect & tmpValue) continue;  // 三元组冲突，跳过
        search0_6Tuples(dep+1, i, state | (1ull<<(ull)i), triplesSelect | tmpValue);
    }
}
```

- `triplesSelect`：当前选中的四元组子集覆盖的三元组占位（35 bit）
- `state`：选中的四元组占位（35 bit，每个 bit 对应一个四元组序号）
- **包含空集** `(0, 0)`（第 826 行 `pb` 在递归条件之前），这是递归终点 `Q0=0` 时命中的关键。

最后排序 `tuple0_6states`，供二分查找。

---

### 4.3 `solveForAi()`（第 739-822 行）——顶层编排

```cpp
void solveForAi() {
    // 1. 初始化 reorder[z][·]
    for (int z = 13; z > 6; z--) {
        int tmpcnt = 0;
        for (int i = 0; i < N_16 - 2; i++)   // i = 0..13
            if (i != z && i != (z ^ 1)) {      // 跳过 z 和 z^1
                reorder[z][i] = tmpcnt;        // 映射到 0..11
                invReorder[z][tmpcnt] = i;
                tmpcnt++;
            }
    }
```

**`reorder[z]` 的含义**：在 $A_z$ 视角下，排除 $z$ 和 $z \oplus 1$（在 SQS 结构中 $z$ 和 $z \oplus 1$ 恒在同一四元组中），把剩余 12 个元素重新编号为 $0..11$。这使得 $A_{z,14}$（孙子结构）可以统一用 12 元素的 perfect matching 表示。

```cpp
    // 2. 预处理 A_13 ~ A_7
    for (int z = 13; z >= 7; z--)
        PreSolveForAi(z);

    // 3. 准备 A_14 折半数据（z==14 时 PreSolveForAi 直接 return）
    PreSolveForAi(14);

    // 4. A_14 主枚举（双重循环遍历所有折半组合）
    for (i, j, k, l, e):
        Generate_seeds(..., Ai[14]);     // 组装完整 A_14
        累加 mask / maskAi[14];
        GenerateSQS16();                 // 预填 + 递归拼接
        撤销 mask / maskAi[14];
}
```

> **注意**：当前代码第 756 行有 `return` 提前退出，只做 $A_{13}$ 的预处理 benchmark。完整搜索需注释掉这行。

---

### 4.4 `PreSolveForAi(z)`（第 625-737 行）——枚举 $A_z$ 候选并分桶

#### 4.4.1 首次初始化

```cpp
static bool isEntryFirst = false;
if (!isEntryFirst) {
    PRE();                        // 设置 arcMask, reverse_map, log_2
    search0_11Matching(0, 0);     // 预枚举 12 元素 perfect matching
    isEntryFirst = true;
}
```

`search0_11Matching` 枚举 $11!! = 10395$ 种 perfect matching，建立哈希反查表 `ordMatchings0_11[m]`。

#### 4.4.2 提取 son_blocks

```cpp
len = 0;
rep(i, 0, Num_15 - 1) if (Ai[15][i].state & (1 << z)) {
    int val = Ai[15][i].state - (1 << z);  // 去掉 z
    int fir = lowbit(val);                  // 最低位 bit
    son_blocks[len].first = log_2[fir];     // 转元素值
    val -= fir;
    son_blocks[len++].second = log_2[lowbit(val)];
}
```

从 $A_{15}$ 中提取含 $z$ 的 7 个三元组，去掉 $z$ 后得到 7 条二元组（son_blocks）。

**`lowbit(x)`**（第 103-107 行）：`x & -x`，取最低位 1 的 bit 值。例如 `lowbit(0b10100) = 0b00100`。

**`log_2[]`**（第 211 行 + 第 284-285 行）：预计算的"bit 值→位序号"反查表。`log_2[0b00100] = 2`。

#### 4.4.3 调用 `PRE_SOLVE(z)` 设置折半搜索基础

`PRE_SOLVE(z)` 设置 `sed_map`、枚举行 13/12 的 matching、行 11/10 的四元组、行 0-9 的三元组解集（详见 §4.5-4.8）。

#### 4.4.4 z=14 直接返回

```cpp
if (z == 14) return;  // A_14 不需要预处理入桶
```

$A_{14}$ 的候选在主循环中流式枚举，不需要预存。

#### 4.4.5 枚举 $A_z$ 候选（四重循环 + 下半匹配）

```cpp
for (i = 0; i < n11; i++) {           // 遍历行 13 的 matching
  for (j = 0; j < n10; j++) {         // 遍历行 12 的 matching
    if ((Matchings13[i] & Matchings12[j]) == 0) {  // 两 matching 不冲突
      ull s = Matchings13[i] | Matchings12[j];     // 上半占位
      // 提取与行 11/10 的配对端点
      int a = matching13[i][0], b = matching12[j][0];
      if (a > b) swap(a, b);
      int c = matching13[i][1], d = matching12[j][1];
      if (c > d) swap(c, d);

      for (k = 0; k < 60; k++)         // 遍历行 11 的 4 三元组
        if (tuple11[a][b][k].first && (s & tuple11[a][b][k].first) == 0) {
          s |= tuple11[a][b][k].first;
          for (l = 0; l < 60; l++)     // 遍历行 10 的 4 三元组
            if (tuple10[c][d][l].first && (s & tuple10[c][d][l].first) == 0) {
              s |= tuple10[c][d][l].first;
              // 现在 s 应该覆盖了上半 60 条边中的 52 条
              // 还需要下半 8 条边
              ull query_s = full_mask ^ s;  // 还缺的边占位
              if (!id_map.count(query_s)) { s -= tuple10[...]; continue; }
              for (auto e : sol0_9[id_map[query_s]]) {
                // 组装完整 A_z
                Generate_seeds(Matchings13[i], Matchings12[j],
                               tuple11[a][b][k].second,
                               tuple10[c][d][l].second, e, Ai[z]);
```

这是一个经典的**折半搜索**：上半（行 13,12,11,10）的占位 `s` 确定后，下半（行 0-9）需要的占位 `query_s = full_mask ^ s` 是确定的。在预建的 `sol0_9` 表中按 `query_s` 查找匹配的下半解 `e`。

#### 4.4.6 计算哈希并分桶

```cpp
AzPreEntity Az;
Az.AzNum = AzCnt;
int tmpMatching[12] = {0};
int sedCnt = 0;
for (int iSed = 0; iSed < Num_15; iSed++) {
    // 含 14 不含 15 的三元组 → 计算 m1 哈希
    if ((Ai[z][iSed].state & (1 << 14)) && !(Ai[z][iSed].state & (1 << 15))) {
        int val = Ai[z][iSed].state - (1 << 14);  // 去掉 14
        int firstBit = lowbit(val);                // 较小元素的 bit
        int secondBit = lowbit(val - firstBit);     // 较大元素的 bit
        tmpMatching[reorder[z][log_2[firstBit]]] = reorder[z][log_2[secondBit]];
    }
    // 跳过含 14 或 15 的三元组
    if ((Ai[z][iSed].state & (1 << 14)) || (Ai[z][iSed].state & (1 << 15)))
        continue;
    Az.sed[sedCnt++] = Ai[z][iSed].state;  // 存"既不含 14 也不含 15"的 22 个
}
assert(sedCnt == 22);
ull m1 = 0;
for (int i = 0; i < 12; i++)
    if (tmpMatching[i] > i)
        m1 = m1 * 12 + tmpMatching[i];
preSolveAz[z][ordMatchings0_11[m1]].pb(Az);  // 入桶
```

**m1 哈希的含义**：$A_z$ 中"含 14 不含 15"的 6 个三元组正是 $A_{z,14}$（孙子结构）。把它们的 6 条边经 `reorder[z]` 映射后，按较小端点升序串接较大端点，形成一个基-12 的 6 位数 `m1`。`ordMatchings0_11[m1]` 给出对应的 perfect matching 序号，作为桶键。

**为什么只存 22 个？** $A_z$ 的 35 个三元组中：
- 7 个含 15（由 $A_{15}$ 直接决定）
- 6 个含 14 不含 15（由 $A_{14}$ 直接决定，即 $A_{z,14}$）
- 22 个既不含 14 也不含 15（递归阶段枚举）

递归时前 13 个直接从 $A_{15}$/$A_{14}$ 重建，后 22 个从桶中取候选。

---

### 4.5 `PRE_SOLVE(z)`（第 288-345 行）——折半搜索基础设施

#### 设置 `sed_map`

```cpp
sed_map[14] = 15;  // 被扣掉的 15 映射到虚拟 14
rep(i, 0, len - 1) {
    sed_map[i << 1]     = son_blocks[i].first;    // 虚拟 2i → 真实
    sed_map[i << 1 | 1] = son_blocks[i].second;   // 虚拟 2i+1 → 真实
}
```

#### 枚举行 13/12 的 perfect matching

```cpp
searchTable(0, 0, 11);  // 行 13：虚拟元素 sed_map[13]，结果存 Matchings13[]
searchTable(0, 0, 10);  // 行 12：虚拟元素 sed_map[12]，结果存 Matchings12[]
```

`searchTable` 详解见 §4.6。

#### 枚举行 11/10 的 4 三元组

```cpp
for (i, j with i < j < 10) {
    used[i] = used[j] = true;  // 预占 i, j（它们将与行 13/12 配对）
    search4rows(11, ..., tuple11[i][j]);  // 行 11
    search4rows(10, ..., tuple10[i][j]);  // 行 10
    used[i] = used[j] = false;
}
```

`search4rows` 详解见 §4.7。

#### 枚举行 0-9 的三元组

```cpp
t = 0;
for (i, j, k in 0..9) {
    if (arcMask[i][j] > 0 && arcMask[i][k] > 0 && arcMask[j][k] > 0
        && !mask[(1<<sed_map[i]) + (1<<sed_map[j]) + (1<<sed_map[k])]) {
        tuple0_9[t] = arcMask[i][j] + arcMask[i][k] + arcMask[j][k];
        element0_9[t] = {i, j, k};
        t++;
    }
}
search0_9(t, 0, 0);  // 枚举选 8 个互不冲突的
```

`search0_9` 详解见 §4.8。

---

### 4.6 `searchTable(i, s, g)`（第 149-184 行）——行 13/12 的 matching 枚举

```cpp
void searchTable(int i, ull s, int g) {
    if (i == 6) {  // 6 条边配对完毕
        if (g == 11) { Matchings13[n11] = s; matching13[n11][0/1] = ...; n11++; }
        else          { Matchings12[n10] = s; matching12[n10][0/1] = ...; n10++; }
        return;
    }
    int j = -1, v = (g==11) ? (1<<sed_map[13]) : (1<<sed_map[12]);
    do { j++; } while (j < 12 && matching[j] != -1);  // 找最小未配对位
    for (int k = j+1; k < 12; k++) {
        if (k == j+1 && j%2 == 0) continue;  // 跳过 son-block 边
        if (matching[k] == -1 && !mask[(1<<sed_map[k]) + (1<<sed_map[j]) + v]) {
            matching[j] = k; matching[k] = j;
            searchTable(i+1, s + arcMask[j][k], g);
            matching[j] = matching[k] = -1;
        }
    }
}
```

**逻辑**：
1. 每层选"最小未配对虚拟位 $j$"（保证唯一性，避免重复枚举）。
2. 尝试与所有 $k > j$ 配对，跳过 son-block 自配对边（$(0,1),(2,3),\dots$）。
3. 检查三元组 $\{sed\_map[j], sed\_map[k], sed\_map[g]\}$ 不在 $A_{15}$ 中（`!mask[...]`）。
4. 递归配对下一条边，直到 6 条边完成。

结果 `Matchings13[i]` 是行 13 matching 的边占位（60 bit 中 6 个 bit 为 1）。`matching13[i][0/1]` 记录与行 11、10 配对的两个端点。

---

### 4.7 `search4rows(x, i, s_all, s, tup[])`（第 188-209 行）——行 11/10 的 4 三元组

```cpp
void search4rows(int x, int i, ull s_all, ull s, pair<ull,ull> tup[]) {
    if (i == 4) { tup[sol++] = mp(s_all, s); return; }
    int j = 0;
    while (j < 10 && used[j]) j++;  // 找最小未占用位
    used[j] = true;
    for (int k = j+1; k < 10; k++) {
        if (!used[k] && !(k==j+1 && j%2==0)
            && !mask[(1<<sed_map[k]) + (1<<sed_map[j]) + (1<<sed_map[x])]) {
            used[k] = true;
            search4rows(x, i+1,
                        s_all + arcMask[j][k] + arcMask[j][x] + arcMask[k][x],
                        s + arcMask[j][k], tup);
            used[k] = false;
        }
    }
    used[j] = false;
}
```

**逻辑**：选 4 个三元组，每个形如 $\{a, b, x\}$（$x$ = 11 或 10）。每次选最小未占用位 $j$，与某 $k$ 配对，共选 4 对。`s_all` 是 4 个三元组涉及的全部边占位（12 条边 = 4×3，但每条边在三元组内出现一次），`s` 是行上 4 条边占位。

---

### 4.8 `search0_9(t, i, s)`（第 122-147 行）——行 0-9 的 8 三元组

```cpp
void search0_9(int t, int i, ull s) {
    if (i == 8) {  // 选满 8 个三元组
        ull high_bit = 0, low_bit = 0;
        if (!id_map.count(s)) id_map[s] = cnt++;
        int id = id_map[s];
        for (int j = 0; j < 8; j++)
            if (a[j] < (t >> 1))        // 前半三元组
                low_bit |= 1ull << a[j];
            else                        // 后半三元组
                high_bit |= 1ull << (a[j] - (t >> 1));
        sol0_9[id].pb(mp(high_bit, low_bit));
        return;
    }
    int las = (i == 0) ? -1 : a[i-1];
    for (int j = las+1; j < t; j++)
        if ((tuple0_9[j] & s) == 0) {  // 边不冲突
            a[i] = j;
            search0_9(t, i+1, s + tuple0_9[j]);
            a[i] = -1;
        }
}
```

**逻辑**：从 $t$ 个合法三元组中选 8 个，使边占位互不重叠。按"全部边占位 $s$"为键存入 `sol0_9[id_map[s]]`。每个解被拆成 `(high_bit, low_bit)` 两半，便于后续 `Generate_seeds` 按需重建。

---

### 4.9 `Generate_seeds()`（第 347-369 行）——组装完整 $A_z$

```cpp
inline void Generate_seeds(ull s13, ull s12, ull s11, ull s10, pair<ull,ull> e, tuple3 sed[]) {
    len = 7;
    // 前 7 个：son-block 三元组 {son_blocks[i].first, son_blocks[i].second, 15}
    rep(i, 0, 6) sed[i] = tuple3{son_blocks[i].first, son_blocks[i].second, 15};

    // 行 13,12,11,10 的三元组（通过 output_pair 从边占位解码）
    output_pair(s13, 13, sed);
    output_pair(s12, 12, sed);
    output_pair(s11, 11, sed);
    output_pair(s10, 10, sed);

    // 行 0-9 的三元组（通过 output_triple 从边占位解码）
    output_triple(e.second, t, false, sed);  // low 半
    output_triple(e.first,  t, true,  sed);  // high 半

    // 排序并设置 state
    sort(sed, sed + len);
    for (int i = 0; i < len; i++)
        sed[i].state = (1 << sed[i].a) + (1 << sed[i].b) + (1 << sed[i].c);
}
```

**`output_pair(s, las, sed)`**（第 226-237 行）：从边占位 `s` 逐 bit 取出，通过 `reverse_map` 反查每条边对应的虚拟二元组 $(j,k)$，构造三元组 $\{sed\_map[j], sed\_map[k], sed\_map[las]\}$，排序后存入 `sed[len++]`。

**`output_triple(s, t, high, sed)`**（第 239-254 行）：从边占位 `s` 逐 bit 取出，通过 `log_2` 反查三元组在 `element0_9` 中的索引，构造三元组 $\{sed\_map[a], sed\_map[b], sed\_map[c]\}$。

最终 `sed[0..34]` 是 35 个完整的三元组，已排序、已设 state。

---

### 4.10 `search0_11Matching(dep, m)`（第 377-400 行）——12 元素 matching 哈希表

```cpp
void search0_11Matching(int dep, ull m) {
    if (dep == 6) {
        matchings0_11[matchings0_11Cnt][0..11] = matching[0..11];
        ordMatchings0_11[m] = matchings0_11Cnt;  // 哈希值 m → 序号
        matchings0_11Cnt++;
        return;
    }
    int j = -1;
    do { j++; } while (j < 12 && matching[j] != -1);  // 最小未配对位
    for (int i = j+1; i < 12; i++)
        if (matching[i] == -1) {
            matching[j] = i; matching[i] = j;
            search0_11Matching(dep+1, m * 12 + i);  // 串接较大端点 i
            matching[i] = matching[j] = -1;
        }
}
```

**哈希值 `m` 的定义**：6 对匹配中，按较小端点 $j$ 升序排列，将较大端点 $i$ 串接为基-12 数：

$$m = (((i_1 \cdot 12 + i_2) \cdot 12 + \dots)$$

共 $11!! = 10395$ 种。`ordMatchings0_11[m]` 给出 $m$ → 序号的反查（未注册的为 $-1$）。

---

### 4.11 `GenerateSQS16()`（第 568-623 行）——预填 $A_z$ 已知项 + 计算 m1

```cpp
inline void GenerateSQS16() {
    for (int z = 13; z >= 7; z--) {
        int len = 0;
        int tmpMatching[12] = {0};

        // (1) son-block 中同时含 14、15 的唯一三元组 {z^1, 14, 15}
        Ai[z][len++] = tuple3{z ^ 1, 14, 15};

        // (2) A_15 中含 z 不含 14 的 → A_z 中 {p, q, 15}
        for (int i = 0; i < Num_15; i++) {
            if ((Ai[15][i].state & (1 << z)) && !(Ai[15][i].state & (1 << 14))) {
                int val = Ai[15][i].state - (1 << z);
                int tmp = lowbit(val); val -= tmp;
                Ai[z][len++] = tuple3{log_2[tmp], log_2[lowbit(val)], 15};
            }
            // (3) A_14 中含 z 不含 15 的 → A_z 中 {p, q, 14}，并累计 tmpMatching
            if ((Ai[14][i].state & (1 << z)) && !(Ai[14][i].state & (1 << 15))) {
                int val = Ai[14][i].state - (1 << z);
                int tmp = lowbit(val); val -= tmp;
                Ai[z][len++] = tuple3{log_2[tmp], log_2[lowbit(val)], 14};
                tmpMatching[reorder[z][log_2[tmp]]] = reorder[z][log_2[lowbit(val)]];
            }
        }

        // 算 m1 哈希
        ull m1 = 0;
        for (int i = 0; i < 12; i++)
            if (tmpMatching[i] > i)
                m1 = m1 * 12 + tmpMatching[i];
        m1Values[z] = m1;
        assert(ordMatchings0_11[m1] != -1);
    }
    ConcatAi(13);  // 开始递归拼接
}
```

**填入的 13 项** = 1（$\{z^1,14,15\}$）+ 6（来自 $A_{15}$）+ 6（来自 $A_{14}$）= 13。

**m1 的计算**与 `PreSolveForAi` 中完全一致：取"含 14 不含 15"的 6 个三元组，经 `reorder[z]` 映射后串接。`assert` 确认该哈希对应合法 matching（桶非空）。

---

### 4.12 `ConcatAi(z)`（第 457-566 行）——递归拼接核心

#### 递归终点 z=6（第 459-530 行）

```cpp
if (z == 6) {
    bool tmpMask[1 << N_16] = {0};
    int cnt = 0;
    ull tuples0_6Mask = 0;
    ull ans_state[Num_16];

    // 扫描 A_7..A_15 的全部三元组
    for (int i = 15; i > z; i--) {
        for (int j = 0; j < Num_15; j++) {
            // 三元组全落在 {0..6} 内 → 记录其 ord 占位
            if (Ai[i][j].state <= (1<<6)+(1<<5)+(1<<4))
                tuples0_6Mask |= 1ull << (ull)triplesBits2Ord[Ai[i][j].state];
            // 还原完整四元组（补上元素 i）
            ull tmp_all = (ull)Ai[i][j].state | (1ull << (ull)i);
            if (tmpMask[tmp_all]) continue;  // 去重
            ans_state[cnt] = tmp_all;
            cnt++;
            tmpMask[tmp_all] = true;
        }
    }

    // 还需要覆盖的三元组占位
    tuples0_6Mask ^= tuples0_6FullMask;  // need = 全集 ^ 已有

    // 二分查找折半表
    int l = 0, r = tuple0_6states.size() - 1, ans = 0;
    while (l <= r) {
        int mid = (l + r) >> 1;
        if (tuple0_6states[mid].first >= tuples0_6Mask) {
            r = mid - 1; ans = mid;
        } else l = mid + 1;
    }

    // 命中 → 输出 SQS(16)
    while (ans < tuple0_6states.size() && tuple0_6states[ans].first == tuples0_6Mask) {
        // 输出高位四元组（ans_state[]）+ 低位四元组（tuple0_6states[ans].second）
        ans++;
    }
    return;
}
```

**逻辑**：$A_7 \dots A_{15}$ 已固定时，SQS 中"至少含一个 $\geq 7$ 元素"的四元组已全部确定。剩下只需补全"完全落在 $\{0..6\}$ 内"的四元组。

- `tuples0_6Mask`：已被高位四元组覆盖的 $\{0..6\}$ 三元组占位
- `need = tuples0_6FullMask ^ tuples0_6Mask`：还需覆盖的三元组占位
- 在预建的 `tuple0_6states` 表中二分查找 `first == need` 的项，其 `second` 给出补全的四元组子集

#### 递归主体 z ≥ 7（第 532-565 行）

```cpp
int len = 13;  // 前 13 项已由 GenerateSQS16 填好

// 累加前 13 项的 mask
for (int i = 0; i < len; i++) {
    mask[Ai[z][i].state]++;
    maskAi[z][Ai[z][i].state] = true;
}

int matching0_11Ord = ordMatchings0_11[m1Values[z]];
for (auto &item : preSolveAz[z][matching0_11Ord]) {  // 引用遍历，避免拷贝
    // 对偶一致性校验
    if (!check(item, Num_15 - len, z)) continue;

    // 通过：解码 22 个 state 并填入 Ai[z][13..34]
    for (int i = len; i < Num_15; i++) {
        Ai[z][i] = extract2tuple3(item.sed[i - len]);
        mask[Ai[z][i].state]++;
        maskAi[z][Ai[z][i].state] = true;
    }

    ConcatAi(z - 1);  // 递归下一层

    // 撤销 22 项的 mask
    for (int i = len; i < Num_15; i++) {
        mask[Ai[z][i].state]--;
        maskAi[z][Ai[z][i].state] = false;
    }
}

// 撤销 13 项的 mask
for (int i = 0; i < len; i++) {
    mask[Ai[z][i].state]--;
    maskAi[z][Ai[z][i].state] = false;
}
```

**`extract2tuple3(val)`**（第 449-455 行）：把 state（3 个 bit）拆成 3 个 bit 值，再用 `log_2` 转回元素值：

```cpp
tuple3 extract2tuple3(int val) {
    int a = lowbit(val);           // 最低位 bit 值
    int b = lowbit(val ^ a);       // 次低位 bit 值
    int c = lowbit(val ^ a ^ b);   // 最高位 bit 值
    return tuple3{log_2[a], log_2[b], log_2[c]};  // 用 log_2 转回元素值
}
```

> **注意**：必须用 `log_2[bit]` 把 bit 值转回元素值。如果直接把 bit 值当元素值传给 `tuple3(a,b,c)`，`state = (1<<8)|...` 会越界（这是历史上的 Bug 1）。

**mask 的累加-撤销**严格成对，保证回溯后状态干净。`mask` 用于"全 $\leq z$ 三元组不可重复"，`maskAi[i]` 用于"高位对偶必须由 $A_i$ 提供"。

---

### 4.13 `check(item, size, z)`（第 411-436 行）——对偶一致性校验

```cpp
inline bool check(AzPreEntity &item, int size, int z) {
    int highBitsMask = ((1 << N_16) - 1) ^ ((1 << z + 1) - 1);  // > z 的所有位
    for (int i = 0; i < size; i++) {
        int highVal = item.sed[i] & highBitsMask;  // s 中 > z 的高位元素
        if (highVal) {
            // 逐个高位 r 验证：A_r 必须已含 {s 去掉 r，补上 z}
            int s = item.sed[i];
            while (highVal) {
                int r = lowbit(highVal);
                if (!maskAi[log_2[r]][s ^ r ^ (1 << z)])
                    return false;  // A_r 不含对偶三元组 → 不兼容
                highVal ^= r;
            }
        } else if (mask[item.sed[i]]) {
            // s 完全 ⊂ {0..z-1}：要求尚未被任何已固定 A_i 使用
            return false;
        }
    }
    return true;
}
```

**两种检查**：

1. **高位检查**（三元组含 $> z$ 的元素）：三元组 $\{p, a, b\}$（$a, b > z$）对应四元组 $\{p, a, b, z\}$。四视角一致性要求：
   - $A_a$ 含 $\{p, b, z\}$（验证 `maskAi[a][{p,b,z}]`）
   - $A_b$ 含 $\{p, a, z\}$（验证 `maskAi[b][{p,a,z}]`）

   **必须遍历所有高位**，不能只看最低高位。若只验最低位，`mask[{p,b,z}]≠0` 只能保证"某个 $A_x$ 含此三元组"，但 $x$ 不一定等于 $a$，会导致伪三元组渗入（历史上 Bug 2）。

2. **低位检查**（三元组全 $\leq z$）：由 SQS 性质，同一三元组在不同 $A_i$ 中至多出现一次。若 `mask[s] ≠ 0` 说明已被占用 → 冲突。

---

### 4.14 `PRE()`（第 262-286 行）——全局初始化

```cpp
inline void PRE() {
    c = 1, full_mask = 0;
    // 给每个非 son-block 虚拟二元组分配 bit
    for (j = 0; j < 12; j++)
        for (k = j+1; k < 12; k++) {
            if (k == j+1 && j%2 == 0) continue;  // 跳过 (0,1),(2,3),...
            arcMask[j][k] = arcMask[k][j] = c;
            // 建立 bit → (j,k) 反查（分段存储）
            reverse_map[idx][idc] = {j, k};
            full_mask |= c;
            c += c;  // 下一个 bit（左移）
        }
    // 预计算 log_2 表
    for (int i = 2; i < (1 << 21); i++)
        log_2[i] = log_2[i >> 1] + 1;
}
```

`reverse_map` 分 4 段存储（每段 16 bit），因为 60 条边的 bit 分布在 64 位中，需要按 16 位分段反查。

---

## 第五部分：$A_z$ 的 35 个三元组结构

| 类别 | 数量 | 来源 | 处理阶段 |
|------|------|------|----------|
| 含 14 且含 15 | 1 | $\{z^1, 14, 15\}$（son-block） | `GenerateSQS16` 直接填 |
| 含 15 不含 14 | 6 | $A_{15}$ 中含 $z$ 的三元组映射 | `GenerateSQS16` 填 |
| 含 14 不含 15 | 6 | $A_{14}$ 中含 $z$ 的三元组映射 | `GenerateSQS16` 填，并算 `m1Values[z]` |
| 既不含 14 也不含 15 | 22 | 递归枚举 | 存于 `AzPreEntity::sed[]`，`ConcatAi` 经 `check` 后填 |
| **合计** | **35** | | |

---

## 第六部分：关键不变量与设计意图

### 6.1 mask 的层次语义

| 阶段 | mask 反映 |
|------|-----------|
| `main` 中读入 $A_{15}$ | $A_{15}$ 的 35 个三元组（全程保留） |
| 主循环中枚举 $A_{14}$ | $A_{15}$ + 当前 $A_{14}$ |
| `ConcatAi(z)` 递归中 | $A_{15}$ + $A_{14}$ + $A_{13}$ + ... + $A_z$ |

任一时刻 `mask`/`maskAi` 恰好反映"当前已固定的 $A_{\geq z}$"。

### 6.2 折半搜索的复用

`PRE_SOLVE` 建立的折半结构（行 13/12/11/10 + 行 0-9 解集）被两处复用：
1. `PreSolveForAi(z)`：枚举 $A_z$ 候选并分桶
2. `solveForAi` 主循环：流式枚举 $A_{14}$ 候选

### 6.3 排序的作用

`Generate_seeds` 最后对 35 个三元组排序（按 `tuple3` 的字典序 `(a,b,c)`）。排序保证：
- `check` 函数中高位检查的遍历顺序一致
- `PreSolveForAi` 中 `m1` 哈希计算的累加顺序与 `GenerateSQS16` 一致（均按较小元素升序）

### 6.4 `reorder` 的单调性

`reorder[z]` 把 $\{0,\dots,13\} \setminus \{z, z\oplus1\}$ 映射到 $0..11$，且**保持原始大小关系**（跳过 $z$ 和 $z\oplus1$ 后顺序编号）。这使得：
- `lowbit` 取出的较小元素经 `reorder` 后仍较小
- `tmpMatching[i] > i` 的条件总是成立（当 $i$ 被填充时）
- `m1` 哈希的累加顺序与 `search0_11Matching` 的注册方式一致

---

## 第七部分：代码中常见的位运算技巧

### 7.1 `lowbit(x) = x & -x`

取最低位 1 的 bit 值。例如 `lowbit(0b10100) = 0b00100`。利用补码性质：`-x = ~x + 1`，所以 `x & -x` 恰好保留最低位 1。

### 7.2 `log_2[]` 预计算表

```cpp
for (int i = 2; i < (1 << 21); i++)
    log_2[i] = log_2[i >> 1] + 1;
```

`log_2[1<<5] = 5`，`log_2[1<<10] = 10`。把 bit 值转回位序号。范围 $2^{21}$ 覆盖到 bit 20。

### 7.3 state 掩码

三元组 $\{a,b,c\}$ → `state = (1<<a) | (1<<b) | (1<<c)`。检查"某元素是否在此三元组中"只需 `state & (1<<x)`。

### 7.4 边占位的"加法"等价于"按位或"

`arcMask[j][k]` 是单 bit，`s + arcMask[j][k]` 等价于 `s | arcMask[j][k]`（因为不重叠）。代码中混用 `+` 和 `|`，语义相同。

---

## 第八部分：端到端执行示例

以 $A_{15}$ 固定后的 $A_{13}$ 预处理为例：

1. **`PreSolveForAi(13)`** 被调用
2. 从 $A_{15}$ 提取含 13 的 7 个三元组 → `son_blocks[0..6]`
3. **`PRE_SOLVE(13)`**：
   - 设 `sed_map`：虚拟 0..13 → 真实元素
   - `searchTable` 枚举行 13 的 matching（$sed\_map[13] = 14$）→ `Matchings13[]`
   - `searchTable` 枚举行 12 的 matching（$sed\_map[12] = 12$，即 $z^1 = 12$）→ `Matchings12[]`
   - `search4rows` 枚举行 11/10 的 4 三元组 → `tuple11[][]/tuple10[][]`
   - `search0_9` 枚举行 0-9 的 8 三元组 → `sol0_9[]`
4. **四重循环**枚举 $(i, j, k, l)$：
   - $i$ 选行 13 matching，$j$ 选行 12 matching（不冲突）
   - $k$ 选行 11 四元组，$l$ 选行 10 四元组
   - `query_s = full_mask ^ s` 查 `sol0_9` 得下半解 $e$
5. **`Generate_seeds`** 组装完整 $A_{13}$（35 个三元组）
6. 计算 `m1` 哈希 → 入桶 `preSolveAz[13][m_ord]`

主搜索阶段：
7. **`solveForAi`** 枚举 $A_{14}$ 候选
8. **`GenerateSQS16`** 对每个 $A_{14}$：
   - 填 $A_{13..7}$ 各 13 项 + 算 `m1Values[z]`
9. **`ConcatAi(13)`** → 取桶 → `check` → 填 22 项 → `ConcatAi(12)` → ... → `ConcatAi(6)`
10. **z=6**：二分查 `tuple0_6states` → 输出 SQS(16)

---

## 第九部分：调试与验证

### 9.1 编译运行

```bash
g++ -O3 searchAi.cpp -o searchAi
./searchAi    # 读 NewS(2,3,15).txt，输出到 out.txt
```

### 9.2 验证工具 `check.cpp`

```bash
g++ -O2 check.cpp -o check
./check sqs16.txt    # 验证 140 个四元组是否构成合法 SQS(16)
```

校验内容：
- 数量 = 140
- 元素合法（$0..15$）
- block 互不重复
- **每个 3-子集恰被覆盖一次**（核心检查）

### 9.3 关键 assert

代码中有多处 `assert` 用于调试：
- `assert(sedCnt == 22)`：$A_z$ 中"既不含 14 也不含 15"的三元组必须恰好 22 个
- `assert(ordMatchings0_11[m1] != -1)`：`m1` 哈希必须对应合法 matching
- `assert(__builtin_popcount(tmp_all) == 4)`：还原的四元组必须恰好 4 个元素
- `assert(Ai[z][len-1].a != (z^1))`：含 14 的三元组中不能含 $z^1$（否则与 son-block 矛盾）

---

## 附录：函数调用关系图

```
main
├── getch / int2ch / ch2int        // I/O 辅助
├── generate0_6Tuples
│   └── search0_6Tuples           // DFS 枚举 {0..6} 四元组覆盖方案
└── solveForAi
    ├── PreSolveForAi (z=13..7)
    │   ├── PRE                    // 全局初始化（arcMask, log_2）
    │   ├── search0_11Matching     // 12 元素 matching 哈希表
    │   ├── PRE_SOLVE
    │   │   ├── searchTable        // 行 13/12 matching
    │   │   ├── search4rows        // 行 11/10 四元组
    │   │   └── search0_9         // 行 0-9 八元组
    │   └── Generate_seeds        // 组装完整 A_z
    │       ├── output_pair       // 边占位 → 三元组
    │       └── output_triple     // 边占位 → 三元组
    ├── PreSolveForAi(14)         // 准备 A_14 折半数据
    └── A_14 主枚举循环
        ├── Generate_seeds
        └── GenerateSQS16
            └── ConcatAi (z=13→6)
                ├── check          // 对偶一致性校验
                ├── extract2tuple3 // state → tuple3
                └── (z=6) 二分查找 tuple0_6states
```
