# SQS(16) 搜索算法实现文档（`searchAi.cpp`）

> **目标**：在元素集 `{0, 1, …, 15}` 上搜索 Steiner 四元系统 SQS(16) = S(3, 4, 16)。
> 一个 SQS(16) 由 `Num_16 = C(16,3)/C(4,3) = 560/4 = 140` 个四元组（block）构成，
> 满足"每个 3-元素子集恰好被一个四元组覆盖"。
>
> 本文档基于已完成的 CPU 实现 `searchAi.cpp`，逐模块梳理数据结构、数学原理与代码细节，
> 使读者能据此理解全部实现。配套验证工具见 `check.cpp`（校验任意 140 个四元组是否为合法 SQS(16)）。

---

## 目录

1. [总体思路：用导出系统 A_i 分解 SQS(16)](#1)
2. [关键数学性质：孙子结构与对偶一致性](#2)
3. [全局常量与数据结构速查](#3)
4. [虚拟编号与状态压缩（`PRE` / `sed_map` / `arcMask`）](#4)
5. [A_z 候选的折半生成（`PRE_SOLVE` 及其子过程）](#5)
6. [按孙子结构哈希分桶（`search0_11Matching` / `preSolveAz`）](#6)
7. [固定 (A_15, A_14) 后的递归拼接（`GenerateSQS16` / `ConcatAi`）](#7)
8. [对偶一致性校验（`check` + `maskAi`）](#8)
9. [边界 z=6：{0..6} 折半补全（`generate0_6Tuples` / 二分）](#9)
10. [顶层流程（`main` / `solveForAi`）](#10)
11. [历史 Bug 与修复要点](#11)
12. [编译、运行与验证](#12)

---

<a name="1"></a>
## 1. 总体思路：用导出系统 A_i 分解 SQS(16)

### 1.1 定义 A_i

对每个 `i ∈ {0, …, 15}`，定义

> **A_i** = { 把 SQS(16) 中含元素 `i` 的所有四元组取出，删掉 `i` 后得到的三元组所成的集合 }

由 SQS 的导出系统（derived design）性质，**每个 A_i 都是基底 `{0,…,15} \ {i}` 上的一个 STS(2,3,15)**，恰含 `Num_15 = C(15,2)/C(3,2) = 35` 个三元组。

因此"求一个 SQS(16)"等价于"求一组两两兼容的 `(A_0, …, A_15)`"。代码用 `Ai[16][35]`（`tuple3` 类型）存储这 16 个导出系统。

### 1.2 搜索骨架

代码采用"逐层固定 + 递归拼接"的策略，按 `i` 从高到低确定各 A_i：

1. **固定 A_15**：从 `NewS(2,3,15).txt` 读入一个本质不同的 STS(2,3,15) 作为 A_15（输入文件含 80 个，当前实现一次跑第 1 个）。
2. **预处理 A_13 ~ A_7**：对每个 `z ∈ {7,…,13}`，枚举所有与 A_15 兼容的 A_z 候选，按"A_z 与 A_14 的孙子结构哈希"分桶存入 `preSolveAz[z][·]`。
3. **预处理 A_14**：准备 A_14 的折半枚举数据。
4. **主循环**：流式枚举 A_14 候选；对每个 A_14，固定 (A_15, A_14) 后递归拼接 A_13 → A_7（`GenerateSQS16` → `ConcatAi`）。
5. **边界 z=6**：剩余的 A_0 ~ A_6 等价于"在 `{0..6}` 内补全若干四元组"，用预生成的折半表二分匹配补全。

> 注：A_0~A_6 不再各自枚举导出系统，而是统一归结为"`{0..6}` 上还缺哪些三元组"的覆盖问题（见第 9 节）。

---

<a name="2"></a>
## 2. 关键数学性质：孙子结构与对偶一致性

### 2.1 孙子结构 A_{i,j}

对任意 `i ≠ j`，定义"孙子结构"

> **A_{i,j}** = 把 SQS(16) 中同时含 `i, j` 的四元组取出，删去 `i, j` 后得到的二元组集合。

它是基底 `{0,…,15}\{i,j}`（14 个元素）上的一个 **perfect matching**（7 条边），且满足对称性：

> **A_{i,j} = A_{j,i}**

含义：A_i 中所有含 `j` 的三元组（去 `j` 后是二元组）必须等于 A_j 中所有含 `i` 的三元组（去 `i` 后是二元组）。这是约束不同 A_i 相容的核心。

### 2.2 四元组的"四视角一致性"（贯穿全代码的 invariant）

设四元组 `{a, b, c, d} ∈ SQS`，则它在四个导出系统中各贡献一个三元组：A_a 含 `{b,c,d}`、A_b 含 `{a,c,d}`、A_c 含 `{a,b,d}`、A_d 含 `{a,b,c}`。这四个三元组的状态（见 §3 的 `state`）互不相同。

**逆命题（拼接合法性的依据）**：若我们正在确定 A_z，其某个三元组 `t = {p, q, r}` 中存在已固定的高位元素 `r > z`（即 A_r 已确定），则该三元组所属的四元组只能是 `{p, q, r, z}`；按四视角一致性，**A_r 中必须已含三元组 `{p, q, z}`**。`check` 函数（§8）正是逐高位地强制这一条件，从而保证拼接出的结构是某个真实 SQS 的截面。

### 2.3 SQS 性质推论："同一三元组的 state 在不同 A_i 中至多出现一次"

三元组 `{x, y, z}` 在 A_i 中出现 ⇔ 四元组 `{i, x, y, z} ∈ SQS`。由 SQS 定义，三元组 `{x,y,z}` 唯一决定含它的四元组 ⇒ 第 4 元素唯一 ⇒ **同一 state 只能出现在唯一一个 A_i 中**。这条性质使得全局计数数组 `mask[state]`（"该 state 是否被任意已固定 A_i 用过"）成为有效的去重/对偶判据。

---

<a name="3"></a>
## 3. 全局常量与数据结构速查

| 名称 | 类型 | 含义 |
|---|---|---|
| `N_16 / N_15` | const int | 16 / 15 |
| `Num_16` | const int | SQS(16) 四元组数 = 140 |
| `Num_15` | const int | STS(15) 三元组数 = 35 |
| `tuple3{a,b,c,state}` | struct | 一个三元组；`state = (1<<a)|(1<<b)|(1<<c)`，按 `(a,b,c)` 字典序可比 |
| `Ai[16][35]` | tuple3 | 16 个导出系统，每个 35 个三元组 |
| `mask[1<<17]` | int | `mask[state]` = 该三元组 state 当前被多少个已固定 A_i 占用（去重/对偶用） |
| `maskAi[16][1<<17]` | bool | `maskAi[i][state]` = A_i 当前是否含 state 这条三元组（**按 i 区分**，对偶校验用） |
| `sed_map[16]` | int | 虚拟编号 → 真实元素 的映射（见 §4） |
| `arcMask[12][12]` | ull | 虚拟二元组 `(j,k)` 占用的 bit；son-block 自配对边不分配 bit（值 0） |
| `full_mask` | ull | 所有合法虚拟二元组 bit 的并（60 条边） |
| `reverse_map[4][·]` | Pii | bit → 虚拟二元组 `(j,k)` 的反查（按 16 位分段） |
| `log_2[1<<21]` | int | bit 值 → 位序号（如 `log_2[1<<5]=5`） |
| `son_blocks[7]` | Pii | 当前处理的 z 对应的 7 条固定二元组 |
| `Matchings13/12[]`, `matching13/12[][2]` | ull/int | 上半 row 13/12 的 6 边匹配占位 + 与 row 11/10 配对的端点 |
| `tuple11/10[16][16][105]` | pair<ull,ull> | 上半 row 11/10 的 4 三元组（`(全部边占位, 行边占位)`） |
| `tuple0_9[120]`, `element0_9[120][3]` | ull/int | `{0..9}` 内合法三元组的占位与元素 |
| `sol0_9[·]`, `id_map` | vector / map | 下半 8 三元组解集，按二元组占位归类 |
| `MatchingNums_0_11` | const int | 12 元素 perfect matching 数 = 11!! = 10395 |
| `matchings0_11[·][16]`, `ordMatchings0_11[·]` | int | perfect matching 列表 / 哈希值→序号 反查（未注册为 -1） |
| `AzPreEntity{AzNum, sed[24]}` | struct | A_z 候选中"既不含 14 也不含 15"的 22 个三元组 state |
| `preSolveAz[16][10395]` | vector<AzPreEntity> | 按"A_z 与 A_14 孙子结构哈希"分桶的 A_z 候选 |
| `reorder/invReorder[16][16]` | int | A_z 视角下 12 个有效元素 ↔ 0..11 的重映射 |
| `m1Values[16]` | ull | GenerateSQS16 阶段算出的各 z 的孙子结构哈希 |
| `tuples0_6[35][4]`, `triples0_6[35][·]`, `triplesBits2Ord[·]` | int | `{0..6}` 内的 35 个四元组 / 35 个三元组 / 三元组 state→序号 |
| `tuples0_6FullMask` | ull | `{0..6}` 内 35 个三元组占位全集 |
| `tuple0_6states` | vector<pair<ull,ull>> | `{0..6}` 折半解：`(覆盖的三元组占位, 选中的四元组占位)`，已排序 |

> **元素编码约定**：输入/输出用 hex 字符，`'0'-'9'` → 0-9，`'A'-'F'` → 10-15。

---

<a name="4"></a>
## 4. 虚拟编号与状态压缩（`PRE` / `sed_map` / `arcMask`）

枚举 A_z（`z ≠ 15`）时，A_z 中"含 15"的部分必须等于 A_15 中"含 z"的部分。这部分有 7 个三元组，形如 `{x, y, 15}`；它们的 7 条二元组 `{x, y}` 称为 **son_blocks**，覆盖 `{0..15}\{z,15}` 共 14 个元素，构成一个 perfect matching。

### 4.1 `sed_map`：虚拟编号 → 真实元素

把这 14 个元素重新编号为虚拟 `0..13`，约定：

```
sed_map[2i]   = son_blocks[i].first
sed_map[2i+1] = son_blocks[i].second   (i = 0..6)
sed_map[14]   = 15                      (被扣掉的 15 固定映射到虚拟 14)
```

于是 son_blocks 在虚拟空间里恒为 `(0,1),(2,3),(4,5),(6,7),(8,9),(10,11),(12,13)`。所有 A_z 的折半搜索都在统一的"虚拟 14 元素 + 固定 son_blocks"基底上进行，最后经 `sed_map` 还原成真实元素。

> 特别地，son_blocks 的最后一条 `(sed_map[12], sed_map[13])` 对 `z ≠ 14` 恒为 `(z^1, 14)`（因为 A_15 输入的 son-block 结构使每个 z 与 z^1 配对、且与 14 同组）；对 `z = 14` 则为 `(12, 13)`。`searchTable` 的 `v = (1<<sed_map[13])` 因此随 z 取不同真实元素。

### 4.2 `arcMask`：虚拟二元组的 bit 编码

`PRE()` 给每个**无序虚拟二元组 `(j,k)`（`0≤j<k<12`）** 分配一个唯一 bit：

- **跳过 son-block 自配对边**：当 `k == j+1 且 j 为偶数`（即 `(0,1),(2,3),…`）时不分配 bit（`arcMask=0`）——这些已由 son_blocks 固定占用，不参与 row 上的匹配枚举。
- 共 `C(12,2) - 6 = 66 - 6 = 60` 条边，每条占 1 bit，`full_mask` 是它们的并。
- `reverse_map` 提供 bit → `(j,k)` 的反查；`log_2[]` 提供 bit → 位序号。

---

<a name="5"></a>
## 5. A_z 候选的折半生成（`PRE_SOLVE` 及其子过程）

固定 A_15 与 son_blocks 后，A_z 还剩 `35 - 7 = 28` 个三元组待定，分布在虚拟 `0..13`（含 14 但不含 15 的部分已由 son-block 之外的 row 处理）。按"含某虚拟行 row 的三元组"分组：

| 虚拟行 row | 真实元素 | 含此行的三元组数 | 处理过程 |
|---|---|---|---|
| 13 | `sed_map[13]`（z≠14 时=14） | 6 | `searchTable(·,11)` 上半 |
| 12 | `sed_map[12]`（z≠14 时=z^1） | 6 | `searchTable(·,10)` 上半 |
| 11 | `sed_map[11]` | 4 | `search4rows(11,·)` |
| 10 | `sed_map[10]` | 4 | `search4rows(10,·)` |
| 0~9 | 行内 | 8 | `search0_9(·)` 下半 |

合计 `6+6+4+4+8 = 28`。

### 5.1 上半：行 13 / 12 的 perfect matching（`searchTable`）

`searchTable(0,0,11)` 枚举虚拟 `0..11` 上的 perfect matching（6 条边）。每条边 `(j,k)` 对应 A_z 中三元组 `{sed_map[j], sed_map[k], sed_map[13]}`；过程用 `mask[…]` 排除"该真实三元组已在 A_15 中"的边（避免与 A_15 冲突）。结果占位存入 `Matchings13[]`，并记录与 row 11、10 配对的端点 `matching13[*][0/1] = (matching[11], matching[10])`。
`searchTable(0,0,10)` 同理处理行 12，结果存 `Matchings12[]` / `matching12[*]`。

> `do{j++;}while(matching[j]!=-1)` 每层选"最小未配对虚拟位"作为 j，保证每个 matching 只被枚举一次。

### 5.2 上半：行 11 / 10 的 4 三元组（`search4rows`）

对每对端点 `(i,j)`（来自 row 13/12 与 row 11/10 的配对），`search4rows(x, …)` 在虚拟 `0..9` 中枚举 4 个不冲突三元组（每个形如 `{a, b, x}`，x = 11 或 10）。结果按 `(i,j)` 索引存入 `tuple11[i][j][·]` / `tuple10[i][j][·]`，每项是 `(s_all, s)`：`s_all` 是这 4 个三元组涉及的全部边占位，`s` 是 row 上 4 条边占位。

### 5.3 下半：行 0~9 内三元组（`search0_9`）

`{0..9}` 内合法三元组共 `t`（≤72，剔除已被 A_15 占用的）存于 `tuple0_9[]` / `element0_9[]`。`search0_9` 从中选 8 个使二元组占位互不重叠，按"二元组占位 `s`"为键存入 `sol0_9[id_map[s]]`；每个解被拆成 `(high_bit, low_bit)` 两半（按三元组下标对半拆），便于后续按需重建。

### 5.4 折半拼接（`Generate_seeds`）

给定五元组 `(Matchings13[i], Matchings12[j], tuple11[a][b][k].second, tuple10[c][d][l].second, e)`，其中上半总占位 `s_up`，下半需要的占位为 `query_s = full_mask ^ s_up`，在 `id_map`/`sol0_9` 中查找匹配的下半解 `e`。命中后 `Generate_seeds` 依次写入 7（son-block）+6+6+4+4+8 = 35 个三元组到目标数组 `Ai[z]`（经 `sed_map`/`reverse_map`/`log_2` 还原真实元素并排序设 `state`）。

> 这一折半结构同时被 §6（A_z 候选预处理）与 §10（A_14 主枚举）复用。

---

<a name="6"></a>
## 6. 按孙子结构哈希分桶（`search0_11Matching` / `preSolveAz`）

直接枚举与 A_14 兼容的所有 A_z 数量过大（A_14 自身候选 ≈ 3.56e7）。策略是"先按 A_z 与 A_14 的共同孙子结构 A_{z,14} 哈希分桶"，递归阶段直接取桶。

### 6.1 12 元素 perfect matching 的哈希（`search0_11Matching`）

A_{z,14} 落在 12 个元素上（去掉 z、z^1 后经 `reorder[z]` 映射成 `0..11`），共 `11!! = 10395` 种。`search0_11Matching` 预枚举全部 perfect matching，哈希值定义为：

```
每层选最小未配对位 j，与某 i>j 配对，串入较大端点 i：
m = (((i_1)*12 + i_2)*12 + … )      // 6 个较大端点按较小端点升序串接
```

并建立反查 `ordMatchings0_11[m] = 序号`（未注册的 m 为 `-1`，作为非法/不可达的哨兵）。

### 6.2 桶 `preSolveAz[z][m_ord]`（`PreSolveForAi`）

对每个 `z ∈ {7,…,13}`，用 §5 的折半枚举生成所有与 A_15 兼容的 A_z 候选；对每个候选：

1. 扫描其 35 个三元组，取"含 14 不含 15"的 6 个（即 A_{z,14} 的 6 条边），经 `reorder[z]` 映射后算哈希 `m1`；
2. 把"既不含 14 也不含 15"的 **22 个三元组的 state** 存入 `AzPreEntity::sed[]`；
3. 按 `ordMatchings0_11[m1]` 入桶 `preSolveAz[z][·]`。

> 三元组分布：35 = 7(son-block，含15) + 6(含15不含14) + 6(含14不含15) + ... 其中"含14或含15"共 13 个，被递归阶段由 A_15/A_14 直接重建，故桶里只存剩余 **22 个**（`assert(sedCnt==22)`）。
>
> `m1` 哈希计算用单向赋值 `tmpMatching[reorder[小端点]] = reorder[大端点]`，再 `if (tmpMatching[i] > i)` 串接——由 `reorder` 的单调性，这与 §6.1 的注册方式完全一致。

---

<a name="7"></a>
## 7. 固定 (A_15, A_14) 后的递归拼接（`GenerateSQS16` / `ConcatAi`）

主循环（§10）流式枚举出一个 A_14 后，进入 `GenerateSQS16`。

### 7.1 预填充每层 A_z 的"已知 13 项"（`GenerateSQS16`）

对 `z = 13 → 7`，先填好 A_z 中可由 A_15、A_14 直接决定的 13 个三元组：

1. `{z^1, 14, 15}`：son-block 中"同时含 14、15"的唯一三元组（1 个）；
2. A_15 中"含 z 不含 14"的三元组 `{p,q,z}` → A_z 中 `{p,q,15}`（6 个）；
3. A_14 中"含 z 不含 15"的三元组 `{p,q,z}` → A_z 中 `{p,q,14}`（6 个），同时据此累计 `tmpMatching` 算出该层的孙子结构哈希 `m1Values[z]`。

合计 `1+6+6 = 13` 项，写入 `Ai[z][0..12]`。随后 `assert(ordMatchings0_11[m1] != -1)` 确认该哈希对应合法 matching。

### 7.2 递归拼接（`ConcatAi(z)`，z 从 13 递减）

```
进入 ConcatAi(z)：
  把 Ai[z][0..12] 的 13 项累加进 mask / maskAi[z]；
  取桶 bucket = preSolveAz[z][ ordMatchings0_11[m1Values[z]] ]；
  for (item : bucket):                 // 引用遍历，避免拷贝
      if (!check(item, 22, z)) continue;   // §8 对偶一致性校验
      把 item 的 22 个 state 经 extract2tuple3 还原写入 Ai[z][13..34]，累加 mask / maskAi[z]；
      ConcatAi(z - 1);                 // 递归下一层
      撤销这 22 项的 mask / maskAi[z]；
  撤销 13 项的 mask / maskAi[z]；
```

- `extract2tuple3(val)`：把 state（3 个 bit）拆成 3 个 bit，再经 `log_2[]` 还原为元素值构造 `tuple3`（**注意必须用 `log_2`，否则会把 bit 值误当元素值——见 §11 Bug 1**）。
- 递归终点为 `z = 6`（§9）。

> `mask` / `maskAi` 的累加—撤销严格成对，保证回溯后状态干净。`mask` 用于 §8 的"全 ≤ z 三元组不可重复"判据，`maskAi[i]` 用于"高位对偶必须由 A_i 提供"判据。

---

<a name="8"></a>
## 8. 对偶一致性校验（`check` + `maskAi`）

`check(item, size, z)` 判定一个 A_z 候选的 22 个三元组能否与已固定的 A_{>z} 相容。对每个三元组 state `s`：

```cpp
highBitsMask = ((1<<16)-1) ^ ((1<<(z+1))-1);   // > z 的所有位
highVal = s & highBitsMask;                     // s 中 > z 的高位元素
if (highVal) {
    // 逐个高位 r 验证：A_r 必须已含 (s 去掉 r、补上 z) 这个三元组
    while (highVal) {
        r = lowbit(highVal);
        if (!maskAi[log_2[r]][ s ^ r ^ (1<<z) ]) return false;
        highVal ^= r;
    }
} else if (mask[s]) {
    // s 完全 ⊂ {0..z-1}：要求尚未被任何已固定 A_i 使用（SQS 同一 state 唯一性）
    return false;
}
```

### 8.1 为什么必须"遍历所有高位"而非只看最低高位

三元组 `t = {p, a, b}`（`a < b` 都是高位）对应四元组 `{p, a, b, z}`。四视角一致性要求：
- **A_a 含 `{p, b, z}`**（验证 `maskAi[a][...]`）；
- **A_b 含 `{p, a, z}`**（验证 `maskAi[b][...]`）。

二者都命中 ⇒ A_a、A_b 对同一四元组的描述一致 ⇒ 不会产生"伪四元组"。
若只验证最低高位 a（旧实现的 bug），`mask[{p,b,z}]≠0` 仅能保证"**某个** A_x 含 `{p,b,z}`"，**x 不一定等于 a**；伪三元组会沿层链式渗入，最终在边界 z=6 表现为"block 计数超过 140"（见 §11 Bug 3）。

### 8.2 `maskAi` 用 bool 的正确性

由 §2.3，同一 A_i 内 35 个三元组 state 互不相同，不同 A_i 之间同一 state 也至多出现一次，故 `maskAi[i][state]` 只需布尔标记，无需计数。

---

<a name="9"></a>
## 9. 边界 z=6：{0..6} 折半补全（`generate0_6Tuples` / 二分）

递归到 `z = 6` 时，A_15 ~ A_7 已固定，SQS 中"至少含一个 ≥7 元素"的四元组已全部确定；剩下只需补全"完全落在 `{0..6}` 内"的四元组。

### 9.1 预生成折半表（`generate0_6Tuples`，程序启动时执行一次）

- 枚举 `{0..6}` 内全部 `C(7,3)=35` 个三元组，建立 `triplesBits2Ord[state] = 序号(0..34)`；`tuples0_6FullMask` = 35 个三元组占位全集。
- 枚举 `{0..6}` 内全部 `C(7,4)=35` 个四元组，存 `tuples0_6[]`。
- `search0_6Tuples`：DFS 选取互不冲突的四元组子集（深度上限 10），每个状态记 `(triplesSelect, state)`：`triplesSelect` 是该子集覆盖的三元组占位（`1ull<<ord`，**必须用 64 位移位**，因 ord 可达 34，见 §11 Bug 4），`state` 是选中的四元组占位。**包含空集** `(0, 0)`（不再跳过，见 §11 Bug 5）。
- 全部 `(triplesSelect, state)` 按 `triplesSelect` 排序，供二分。

### 9.2 边界处理（`ConcatAi(z==6)`）

```
扫描 Ai[7..15] 的全部三元组：
  - 凡 state ⊂ {4,5,6}…{0..6} 的（state ≤ (1<<6)+(1<<5)+(1<<4)，即三元素都 ≤ 6），
    在 tuples0_6Mask 累加其 ord 占位；
  - 用 tmp_all = state | (1<<i) 还原成完整四元组 4-bit 掩码，tmpMask 去重统计 cnt
    （cnt = 含 ≥1 个 ≥7 元素的不同四元组数 = 140 - Q0，必 ≤ 140）。
need = tuples0_6FullMask ^ tuples0_6Mask;        // 还需 {0..6} 覆盖的三元组占位
二分 tuple0_6states 找 first == need 的项：
  命中 ⇒ 该项的 state 给出补全的 {0..6} 四元组；连同 ans_state[] 里的高位四元组，
        即构成完整 140 个四元组的 SQS(16)，输出之。
```

- `assert(__builtin_popcount(v) == 140 - cnt)`：补全的四元组数应恰好 = 140 − 高位四元组数。
- 当 `Q0 = 0`（即 cnt = 140）时 `need = 0`，依赖折半表中存在空集项 `(0,0)` 才能命中（§11 Bug 5）。

---

<a name="10"></a>
## 10. 顶层流程（`main` / `solveForAi`）

```
main():
  读入 A_15（35 个三元组）→ Ai[15][]，累加 mask / maskAi[15]；
  generate0_6Tuples();                 // 预生成 {0..6} 折半表（§9.1）
  solveForAi();

solveForAi():
  初始化 reorder[z][·] / invReorder（z=7..13，把 {0..15}\{z,z^1} 映射到 0..11）；
  for z = 13 .. 7:  PreSolveForAi(z);  // 生成并分桶 A_z 候选（§6）
  PreSolveForAi(14);                   // 仅准备 A_14 的折半数据（z==14 直接 return，不入桶）
  // A_14 主枚举：复用 z=14 的折半结构（son_blocks=(0,1)..(12,13)）
  for (五元组折半枚举出每个 A_14 候选):
      Generate_seeds(..., Ai[14]);
      累加 mask / maskAi[14]；
      GenerateSQS16();                 // §7 → ConcatAi(13) → … → ConcatAi(6)
      撤销 mask / maskAi[14]；
```

> **`PreSolveForAi` 的一次性初始化**：首次调用时执行 `PRE()` + `search0_11Matching`（用 `static bool isEntryFirst` 保证只跑一次）。
>
> **mask 的层次语义**：A_15 在 `main` 累加且全程保留；A_14 在主循环内累加/撤销；A_z（z≤13）在 `ConcatAi` 内累加/撤销。任一时刻 `mask`/`maskAi` 恰好反映"当前已固定的 A_{≥z}"。

---

<a name="11"></a>
## 11. 历史 Bug 与修复要点

实现过程中定位并修复的关键缺陷（详见 `Bug.md` 演进记录），按教训价值列出：

| # | 缺陷 | 后果 | 修复 |
|---|---|---|---|
| Bug 1 | `extract2tuple3` 把 `lowbit` 返回的 **bit 值**直接当元素值传给 `tuple3(a,b,c)` 构造 | `state=(1<<8)|(1<<32)|…` 越界/UB，mask 被污染，z=13 之后全拒 | 用 `log_2[bit]` 转回元素值：`tuple3{log_2[a],log_2[b],log_2[c]}` |
| Bug 2 | `check` 只验证**最低高位**的对偶（`lowbit(highVal)`），且用不区分来源的 `mask` | 伪三元组沿层链式渗入，边界 z=6 出现 **cnt > 140** | 引入 `maskAi[i][state]` 按 A_i 区分，`check` **遍历所有高位**逐一验证 |
| Bug 3 | `search0_6Tuples` 中 `1 << ord`（`int`，ord 可达 34）移位 UB | 折半表与边界端 bit 空间错位，二分永不命中 | 改 `ull tmpValue` + `1ull << ord` |
| Bug 4 | z=6 边界二分后 `while (ans <= r)` 条件几乎恒假 | 即便存在匹配也输出不到 | 改 `while (ans < tuple0_6states.size() && ... == need)`，`ans` 初始化为表尾哨兵 |
| Bug 5 | `search0_6Tuples` 跳过空状态 `(0,0)` | `Q0=0`（cnt=140）时 need=0，二分找不到空集 | 无条件 `pb`，让空集也入表 |
| Bug 6 | `m1Values[7]` 未赋值（`GenerateSQS16` 循环曾写 `z>7`） | `ConcatAi(7)` 取桶 `[-1]` 越界 UB | 循环改为 `z >= 7` |
| Bug 7（性能） | `for (auto item : bucket)` 按值拷贝 `AzPreEntity`（~100B/项） | 每次 ConcatAi 拷贝数百 KB | 改 `for (auto& item : bucket)` |

> 经验：本问题中所有"语义 bug"都源于**编号空间混淆**（bit 值 vs 元素值 vs 三元组序号 vs 虚拟编号）和**对偶一致性验证不完整**。`check.cpp` 提供端到端的独立验证，是定位这些问题的关键工具。

---

<a name="12"></a>
## 12. 编译、运行与验证

### 12.1 搜索程序

```bash
g++ -O3 searchAi.cpp -o searchAi
./searchAi            # 读 NewS(2,3,15).txt（第 1 个 STS(15) 作 A_15），输出写 out.txt
```

- 输入：`NewS(2,3,15).txt`，80 个本质不同 STS(2,3,15)，每个 35 个三元组，hex 字符 `0-9 / A-E` 表示元素 0-14。
- 输出：`out.txt`，包含各阶段统计（`n11/n10`、桶大小、`The block have cnt`、找到的 SQS(16) 等）。
- `DEBUGVARIABLE == 20` 时 `exit(0)`，即找到 20 个解后停止（调试用，可调整）。

### 12.2 结果验证（`check.cpp`）

```bash
g++ -O2 -std=c++17 check.cpp -o check
./check sqs16.txt     # 或 ./check 从 stdin 读
```

校验输入的 140 个四元组是否构成合法 SQS(16)：检查数量=140、元素合法、block 互不重复、**每个 3-子集恰被覆盖一次**（核心）。合法输出 `OK`（退出码 0），否则列出缺失/重复的三元组（退出码 1）。

---

## 附：A_z 35 个三元组的结构归类（按"含 14/15 的情况"）

| 类别 | 数量 | 来源 / 处理 |
|---|---|---|
| 含 14 且含 15（son-block `{z^1,14,15}`） | 1 | GenerateSQS16 直接填 |
| 含 15 不含 14（`{p,q,15}`） | 6 | 由 A_15 含 z 的三元组映射，GenerateSQS16 填 |
| 含 14 不含 15（`{p,q,14}` = A_{z,14}） | 6 | 由 A_14 含 z 的三元组映射，GenerateSQS16 填，并算 m1 |
| 既不含 14 也不含 15 | 22 | 存于 `AzPreEntity::sed[]`，ConcatAi 经 check 后填 |
| **合计** | **35** | |
