# `searchAi.cpp` Bug 清单

> 现象回顾：
> - `Already have 13 items` 是正确的（每个 z 应该 1+6+6=13）。
> - 第 396 行 `The block have ...` 输出 137~153 等异常数字（远超 SQS(16) 的 140 个 block）。
> - 长时间未输出"边界拼接成功"的结果。
> - 终端输出中 `Concating 6` 之后还会出现 `Concating 5` / `New items` 等更深层 / 同层错乱，说明边界后递归未正确终止。

按"是否直接解释症状"由高到低排序如下。

---

## Bug 1：`ConcatAi(z)` 边界 `z==6` 缺 `return`

**位置**：`searchAi.cpp` 380–410 行。

**错误**：

```cpp
void ConcatAi(int z) {
    if (z == 6) {
        ...
        cout << "The block have " << cnt << endl;
        ...
        while (...) {
            cout << tuple0_6states[ans].second << endl;   // 缺 ans++
        }
        // ← 没有 return!
    }
    cout << "Concating " << z << endl;
    int len = 13;
    ...
    for (auto item : preSolveAz[z][matching0_11Ord]) {
        ...
        ConcatAi(z - 1);   // ← z=6 进来后会递归 ConcatAi(5)
        ...
    }
}
```

**为什么是 bug**：边界处理完后没有 return，函数继续往下走"普通拼接"逻辑：用 `Ai[6][0..12]` 的残留 state 累加 `mask`，再用 `m1Values[6]`（从未赋值，恒为 0）取 `preSolveAz[6][0]`（从未填充，空 vector），然后递归 `ConcatAi(5)`。这会让边界毫无产出且把递归推进到 `z<6` 的非法状态。

**修复**：

```cpp
if (z == 6) {
    ...
    while (ans <= r && tuple0_6states[ans].first == tuples0_6Mask) {
        cout << tuple0_6states[ans].second << endl;
        ans++;             // 加上自增
    }
    return;                // 边界处理完务必 return
}
```

---

## Bug 2：`generate0_6Tuples()` 在 `main` 中从未被调用

**位置**：`main` 函数 660–690 行；`generate0_6Tuples()` 定义在 638–658 行。

**错误**：`main` 直接进入 `solveForAi()`，没有先初始化边界折半数据。

**为什么是 bug**：`tuple0_6states`、`tuples0_6FullMask`、`triplesBits2Ord` 等所有 0_6 折半数据都为空 / 0。`ConcatAi(6)` 边界中 `tuple0_6states.size()-1` 是 `(size_t)-1` 下溢成巨大值，二分行为完全失控；`tuples0_6FullMask` 为 0，目标值与"实际占位"的差也错。

**修复**：在 `main` 调用 `solveForAi()` 之前加：

```cpp
generate0_6Tuples();
```

---

## Bug 3：`tuples0_6Ord[1<<7]` 数组从未被填充却被使用

**位置**：定义 370 行；使用 388 行；填充本应在 `generate0_6Tuples` 中，但实际填充的是另一个数组 `triplesBits2Ord`（376 行）。

**错误**：

```cpp
if (Ai[i][j].state <= (1 << 6) + (1 << 5) + (1 << 4))
    tuples0_6Mask |= tuples0_6Ord[Ai[i][j].state];   // ← 永远是 0
```

**为什么是 bug**：变量名前缀 `tuples0_6Ord` 与 `triplesBits2Ord` 张冠李戴，作者似乎想用"三元组占位 → bit 序号"反查表，但实际查的是一个未初始化的全局数组。导致 `tuples0_6Mask` 全程 = 0，二分目标值错。

**修复**：删除 `tuples0_6Ord`，统一使用 `triplesBits2Ord`，并把它的语义从"序号"改成"bit"：

```cpp
ull triplesBits2Bit[1 << 8] = {0};   // 1 ULL << ord
...
// 使用处：
tuples0_6Mask |= triplesBits2Bit[Ai[i][j].state];
```

---

## Bug 4：`generate0_6Tuples` 中 `triplesBits2Ord` / `tuples0_6FullMask` 的 off-by-one

**位置**：638–656 行。

**错误**：

```cpp
triples0_6[cnt][2] = k;
cnt++;                                                     // 先自增
triplesBits2Ord[(1 << i) + (1 << j) + (1 << k)] = cnt;     // 写入的是自增后的值
tuples0_6FullMask |= 1ull << (ull)cnt;                     // 同样
```

**为什么是 bug**：把第 0 个三元组的"序号"记成 1，bit 0 被跳过；第 34 个被记成 35，越界 / 溢出范围。`tuples0_6FullMask` 缺 bit 0 且 bit 35 是有效但原本不存在的位。

**修复**：把自增放到最后：

```cpp
triples0_6[cnt][0] = i; triples0_6[cnt][1] = j; triples0_6[cnt][2] = k;
triplesBits2Ord[(1<<i)+(1<<j)+(1<<k)] = cnt;
tuples0_6FullMask |= 1ull << cnt;
cnt++;
```

---

## Bug 5：`search0_6Tuples` 中 `tmpValue` 位空间错乱

**位置**：622–635 行。

**错误**：

```cpp
int allBitsValue = (1 << t[0]) + (1 << t[1]) + (1 << t[2]) + (1 << t[3]);   // 元素位空间
int tmpValue = 0;
for (int j = 0 ; j < 4 ; j++)
    tmpValue |= allBitsValue - (1 << t[j]);   // 这只是把 4 个元素掩码或起来
if (triplesSelect & tmpValue) continue;       // triplesSelect 应是"三元组 ord"位空间
```

`allBitsValue - (1<<x)` 是元素位空间下的"3 元素掩码"，4 个再或回去 = `allBitsValue` 自己。这与 `triplesSelect`（"三元组序号占位"位空间）是两个不同维度的位掩码，比较毫无意义。

**为什么是 bug**：折半搜索本应记录"用了哪些三元组"，但每个四元组拆出的 4 个三元组没有被映射成"三元组 ord 的 bit"，导致冲突检测无效，`tuple0_6states` 内容全错。

**修复**：

```cpp
int tmpValue = 0;
for (int j = 0 ; j < 4 ; j++) {
    int triBits = allBitsValue ^ (1 << t[j]);   // 该三元组的元素掩码
    tmpValue |= 1 << triplesBits2Ord[triBits];  // 转成 ord 空间下的 bit
}
if (triplesSelect & tmpValue) continue;
search0_6Tuples(dep+1, i, state | (1ull<<i), triplesSelect | tmpValue);
```

---

## Bug 6：`tuple0_6states` 未排序就二分

**位置**：399 行的二分；产生位置在 `search0_6Tuples` DFS 顺序入栈。

**错误**：DFS 入栈顺序不保证 `pair.first` 单调递增，但下面要求二分"找到第一个 ≥ 目标"。

**修复**：在 `generate0_6Tuples()` 末尾加：

```cpp
sort(tuple0_6states.begin(), tuple0_6states.end());
```

---

## Bug 7：边界处二分查找循环写错（死循环 / 逻辑错）

**位置**：399–409 行。

**错误**：

```cpp
int l = 0, r = tuple0_6states.size() - 1, ans = 0;
while (l <= r) {
    int mid = (l + r) >> 1;
    if (tuple0_6states[mid].first >= tuples0_6Mask) {
        r = mid - 1;
        ans = mid;
    } else l = mid;          // ← 应该是 l = mid + 1
}
while (ans <= r && tuple0_6states[ans].first == tuples0_6Mask) {
    cout << tuple0_6states[ans].second << endl;
    // ← 缺 ans++，无限输出第一项
}
```

**为什么是 bug**：
1. `l = mid` 在 `l == mid < r` 时不前进，无限循环；
2. 第二个 while 缺自增；
3. 二分结束后 `r = ans - 1`，再用 `ans <= r` 永远为假，应该用 `ans < tuple0_6states.size()` 判定。

**修复**：

```cpp
int l = 0, r = (int)tuple0_6states.size() - 1, ans = (int)tuple0_6states.size();
while (l <= r) {
    int mid = (l + r) >> 1;
    if (tuple0_6states[mid].first >= tuples0_6Mask) {
        ans = mid; r = mid - 1;
    } else l = mid + 1;
}
while (ans < (int)tuple0_6states.size()
       && tuple0_6states[ans].first == tuples0_6Mask) {
    cout << tuple0_6states[ans].second << endl;
    ans++;
}
```

---

## Bug 8：`reorder[z][i]` 的 `tmpcnt` 漏自增

**位置**：491–497 行（`searchAi.cpp` 的 `PreSolveForAi`），以及 678–683 行（CUDA 版本里同样问题）。

**错误**：

```cpp
int tmpcnt = 0;
for (int i = 0 ; i < N_16 - 2 ; i++)
    if (i != z && i != (z ^ 1)) {
        reorder[z][i] = tmpcnt;
        invReorder[z][tmpcnt] = i;
        // ← 缺 tmpcnt++;
    }
```

**为什么是 bug**：所有 `reorder[z][i]` 全为 0，所有 `invReorder[z][0]` 被反复覆盖。后续用 `reorder[z][...]` 计算的哈希键 `m1` 全是 0（或同一桶），`preSolveAz[z][0]` 被塞满所有候选；`GenerateSQS16` 阶段查 `m1` 也总是 0。看似递归能进，但桶内大量"不该同桶"的项也会通过 `check`（如果碰巧不冲突），从而进入边界 `z=6`，但绝大多数情况下边界折半要求的精确占位匹配又匹配不上。

**修复**：循环体内加 `tmpcnt++;`。

---

## ~~Bug 9：`m1` 哈希键的两端构造顺序 / 取位规则不一致~~（已撤回）

**结论：经复核此项 *不是* bug。**

两端虽然遍历的源不同（PreSolve 端遍历 `Ai[z]`，GenerateSQS16 端遍历 `Ai[14]`），但两边筛出的"6 条共同孙子结构边" `(p_i, q_i)`（p<q，均 ∈ `{0..15}\{z,14}`）的等价排序顺序相同：

- PreSolve 端：在 `Ai[z]` 的字典序里，"含 14 不含 15"的 6 条三元组形如 `(p, q, 14)`，14 永远在 c 位置 ⇒ 按 (p, q) 升序 ≡ 按 p 升序。
- GenerateSQS16 端：在 `Ai[14]` 的字典序里，"含 z 不含 15"的 6 条三元组形如包含 z 的某个排列 `(?, ?, ?)`。可分三类：
  - z 在 c 位置（即 p<q<z）：按 (p,q,z) 字典序 = 按 p 升序；
  - z 在 b 位置（即 p<z<q）：按 (p,z,q) 字典序 = 按 p 升序；
  - z 在 a 位置（即 z<p<q）：按 (z,p,q) 字典序 = 按 p 升序（a=z 固定，再按 b=p 升序）。
  三类混合后，`Ai[14]` 字典序仍等价于按"非 z 的较小端点 p"升序。

并且两端取的进制位都是"较大端点 q"：

- PreSolve 端：`val = state - (1<<14); val -= lowbit(val); index = log_2[val]` ⇒ `index` = 较大端点 q。
- GenerateSQS16 端：构造 `Ai[z][len++] = tuple3{log_2[tmp], log_2[lowbit(val)], 14}` 时，`a=较小端点`、`b=较大端点 q`；随后 `m1 = m1*12 + reorder[z][Ai[z][len-1].b]` 取的就是 q。

⇒ 两端串接顺序与值都相同，**m1 一致**，本条作废。

---

## Bug 10：`The block have N` 出现 N > 140，证明 `Ai[7..15]` 数据被污染

**位置**：385–396 行。

**正确语义复核**：

```cpp
for (int i = 15; i > z; i--) {            // i ∈ {7..15}, z=6
    for (int j = 0; j < Num_15; j++) {
        ...
        int val = Ai[i][j].state | (1 << i);   // 还原成完整四元组 4-bit 掩码
        if (tmpMask[val]) continue;
        cnt++;
        tmpMask[val] = true;
    }
}
```

由于 `Ai[i][j].state = (1<<a)|(1<<b)|(1<<c)` 且 `{a,b,c} = 四元组 \ {i}`，因此 `val = (1<<a)|(1<<b)|(1<<c)|(1<<i)` 是**完整四元组的 4-bit 掩码**，与 i 是哪一端无关。同一四元组在 A_a, A_b, A_c, A_d 里出现 4 次，但 val 都相同 ⇒ `tmpMask[val]` 正确去重。

⇒ `cnt = 140 - (完全在 {0..6} 中的四元组数) ≤ 140`。

**实际输出 137~153 中超过 140 的部分（141, 143, 145, 149, 151, 153）全部不合法**，说明 `Ai[7..15]` 中有"伪三元组"被计入。

**可能源头（按优先级）**：

1. **`Ai[z][13..34]` 在到达 z=6 之前未被覆盖** —— 理论上 `ConcatAi(z')` 进入 `for (item)` 时会写满 `Ai[z'][13..34]`，但若递归进入了 `ConcatAi(z'-1)` 分支后 **`Ai[z']` 写入的 22 项与 `PreSolveForAi(z')` 留下的残留项部分混合**（例如 22 项里有某些 state=0 或被 move 后的悬挂值），这些奇怪 state 的 val 会成为伪 key，落在合法 4-bit 掩码空间外 ⇒ tmpMask 不冲突，被多算。
2. **`tuple3` 默认构造未初始化字段（Bug 12）** —— `AzPreEntity::sed[24]` 是 `tuple3 sed[24]`，整个数组用默认构造创建后，前 22 项被赋值，**后 2 项 (sed[22], sed[23]) 的 state 为垃圾值**。但 `ConcatAi` 只读 `item.sed[0..21]`（`Num_15 - len = 22` 项），不会触及尾部 ⇒ 看似不影响。但若某个 z 下 `sedCnt < 22`（即"既不含 14 也不含 15 的三元组数" 少于 22），则 `sed[sedCnt..21]` 保留垃圾，**ConcatAi 的 for 循环会读到这些垃圾**，写入 `Ai[z][len..Num_15-1]`，污染统计。
3. **`Generate_seeds` 中 sort 使用未初始化的 state**：

```cpp
sort(sed, sed + len);   // ← 用 operator< 比较 (a,b,c)，OK
for (int i = 0 ; i < len ; i++)
    sed[i].state = ...;   // ← 之后才设 state
```

排序前 `state` 是垃圾（因为 `sed[i] = {a,b,c}` 这种 brace-list 赋值不调用 `tuple3(int,int,int)`，而是聚合赋值，`state` 保持上一次的值）。但排序基于 `(a,b,c)` 不依赖 state，OK；排序后再重设 state，最终值正确 ✓。这条不是问题。

4. **关键怀疑：`output_pair` / `output_triple` 中 `sed[len++] = {tmp[0],tmp[1],tmp[2]}` 是 brace-list assignment**：

```cpp
sed[len++] = {tmp[0], tmp[1], tmp[2]};  // 等价于聚合赋值，state 字段未设
```

后续 `Generate_seeds` 末尾的 `for(i=0;i<len;i++) sed[i].state = (1<<a)|(1<<b)|(1<<c);` 会修正所有项 ✓。看似 OK。

**真正的修复方向**：在 `ConcatAi(z=6)` 边界统计前**显式校验** `Ai[i][j].state` 是 3-bit 合法掩码：

```cpp
for (int i = 15; i > z; i--) {
    for (int j = 0; j < Num_15; j++) {
        int s = Ai[i][j].state;
        // 校验：s 必须恰好有 3 个 bit，且 bit 都在 [0,15]\{i}
        assert(__builtin_popcount(s) == 3);
        assert((s & (1 << i)) == 0);
        int val = s | (1 << i);
        ...
    }
}
```

加这两条 assert 后立刻能定位出哪一项 `Ai[i][j].state` 不合法，进而追溯污染源（多半是 Bug 8 + Bug 11 联动产生）。

---

## ~~Bug 10 旧版本~~（撤回，语义错判已纠正）

---

## Bug 11：`Ai[z]`（z ∈ [7,13]）在 `PreSolveForAi(z)` 阶段被反复覆写、残留进入 `GenerateSQS16`

**位置**：`PreSolveForAi(z)` 526–553 行使用 `Ai[z]` 作为临时 buffer 写入 `Generate_seeds(...)`；`GenerateSQS16` 437–461 行只重置 `Ai[z][0..12]`。

**错误**：`PreSolveForAi(z)` 的最后一次 `Generate_seeds(..., Ai[z])` 会在 `Ai[z][0..34]` 留下 35 个三元组。进入 `GenerateSQS16` 后只重写前 13 个，**`Ai[z][13..34]` 是上轮预处理的残留**，但好在 `ConcatAi` 真正使用的位置是 `item.sed[i-len]` 写入 `Ai[z][13..34]`，会覆盖这部分。

**为什么是 bug（实际不算严重）**：在 `ConcatAi(6)` 边界统计 `The block have` 时，循环 `for (j=0; j<Num_15; j++) Ai[i][j].state ...`，会把 `Ai[z][13..34]` 的"残留 state"也读出来去 `tuples0_6Mask |= ...`、`tmpMask[val] = true`，这就**直接污染了边界统计**。它解释了为什么不同递归路径下 cnt 抖动（141/143/145/.../153）：因为残留内容随 `PreSolveForAi(z)` 的最后一次 z 不同。

**修复**：`ConcatAi(z=6)` 边界遍历时只取 `Ai[i][0..12]`（即 `Ai[i][0..len-1]`，已确定部分）—— 但当前递归到边界时 `Ai[i][0..34]` 应该都是已确定的（前 13 + 拼接后的 22）。所以更稳的做法是**记录每层 `len`，并在每次进入 `GenerateSQS16` 前清零 `Ai[z]`**：

```cpp
// 在 GenerateSQS16 的 for-z 循环里：
for (int i = 0; i < Num_15; i++) Ai[z][i] = tuple3{0,0,0};   // 或 memset
int len = 0;
Ai[z][len++] = ...;
```

或在 `PreSolveForAi(z)` 最后加 `memset(Ai[z], 0, sizeof(Ai[z]))`。

---

## Bug 12：`tuple3` 默认构造不初始化字段

**位置**：38 行。

**错误**：

```cpp
struct tuple3 {
    int a, b, c, state;
    tuple3() {}    // ← 三个字段都是未初始化垃圾
};
```

**为什么是 bug**：`Ai[N_16][Num_15]` 全局数组在程序启动时是零初始化的（全局变量特例），所以一开始没问题；但 `Ai[z][i] = tuple3{0,0,0};` / `move` 等操作如果使用默认构造再赋值，state 会临时是垃圾值。配合 Bug 11 / `output_pair` 中只赋 `(a,b,c)` 不赋 `state` 的写法，存在多处隐含未定义行为。

**修复**：

```cpp
tuple3() : a(0), b(0), c(0), state(0) {}
```

并在所有 `sed[len++] = {a,b,c}` 后立即 `sed[len-1].state = (1<<a)|(1<<b)|(1<<c)`，或直接调用三参构造 `sed[len++] = tuple3{a,b,c}`。

---

## Bug 13：`cnt` 等全局名字在多处复用导致互相覆盖

**位置**：`cnt` 在 `search0_9`（PRE_SOLVE 中作为 `id_map` 的计数器，296 行 `cnt = 0`）、`generate0_6Tuples`（作为三元组 / 四元组计数器）、`search0_6Tuples`（作为循环上界）三处共用同一个全局 `int cnt;`（100 行）。

**错误**：例如在 `solveForAi → PreSolveForAi → PRE_SOLVE → cnt = 0; search0_9(...)` 后，`cnt` 已被重置为"0_9 解的数量"。如果之后再调 `generate0_6Tuples()` 或 `search0_6Tuples()`，`cnt` 的语义已经被替换。

**为什么是 bug**：跨模块状态污染，行为完全依赖调用顺序；目前 `generate0_6Tuples()` 没被调用，问题暂时藏起来，一旦修了 Bug 2 调上后，后续 `search0_6Tuples` 内 `for (int i = las+1; i < cnt; i++)` 会拿到错误上界（应是"0_6 四元组数 = 35"）。

**修复**：把 `generate0_6Tuples` 内的计数器改成局部变量；或显式分两个全局 `cnt0_9, cnt0_6`。

---

## ✦ 第二轮：修复后运行新发现的 Bug ✦

> 现象回顾（来自 `out.txt`，4M+ 行，仍在递归中）：
> - 输出中 z 序列正常下降到过 9，但 **z=8、7、6 从未出现**，即递归无法深入到 A_8 / A_7 / A_6。
> - `Concating XX with m1=YY` 中的 m1（实为 `ordMatchings0_11[m1Values[z]]`）出现 `Concating 12 with m1=0`、`Concating 10 with m1=0` 等异常。
> - 大循环已经试过约 23 个 A_14 候选（13 出现 1 次，12 的不同 m1 出现 23 个），但能下到 11/10/9 的 A_14 候选只有 1 个。
> - 程序仍在写出，**没有死循环 / 死锁**，问题是"组合爆炸 + 命中率极低"或"hash 错配"。

---

## Bug 14：`ordMatchings0_11[]` 默认值 0 与"合法序号 0"无法区分（hash 错配伪命中）

**位置**：327 行声明 `int ordMatchings0_11[Hash0_11Num];`；383–399 行 `search0_11Matching` 中填值；427 行使用。

**错误**：

```cpp
int ordMatchings0_11[Hash0_11Num];   // 全局零初始化
...
void search0_11Matching(int dep, ull m) {
    if (dep == 6) {
        ...
        ordMatchings0_11[m] = matchings0_11Cnt;     // 第一个 matching 的 m=320807 → 序号 0
        matchings0_11Cnt++;
    }
    ...
}
...
int matching0_11Ord = ordMatchings0_11[m1Values[z]];   // ← 未注册的 m 也返回 0
cout << "Concating " << z << "with m1=" << matching0_11Ord << endl;
```

**为什么是 bug**：
1. `Hash0_11Num = 3e6`，但合法 hash 仅 10395 个，其它绝大多数下标为默认值 0。
2. 任何"未被注册"的 `m1Values[z]`（即不对应任何合法 perfect matching 的 hash 值）都会被映射到 `preSolveAz[z][0]` 桶 —— 这与"恰好对应序号 0"那个合法 matching 共用同一个桶，造成**严重的伪命中**。
3. 输出中观察到 `Concating 12 with m1=0` 与其它合法序号 1922/1925/1927/... 并存，意味着某些 A_14 候选算出的 `m1Values[12]` 落在了"未注册的 hash"上，错误地访问了序号 0 的桶。
4. 序号 0 的桶（对应 matching `(0,1),(2,3),(4,5),(6,7),(8,9),(10,11)`）通常装着不少候选 → 这些候选会被错误地用于不该匹配的递归路径，浪费大量时间，且**永远无法递归到边界**（因为桶里项与"实际应当对应的 hash 桶"语义不符，越深入冲突越多）。

**为什么会出现"未注册 hash"？**：A_14 候选在 PreSolve 阶段虽然与 A_15 兼容（共享 son_block），但并未要求与"任意 z 的 A_z 候选"共享孙子结构。具体地，A_14 中"含 z 不含 15 的 6 条三元组"的两两端点对，要求构成 12 个虚拟编号上的 perfect matching ⇒ 6 条边端点不重不漏。**理论上当 A_14 是合法 SQS 衍生时这必然成立**，但**当前 PreSolveForAi(14) 生成的 A_14 候选数量为 35,695,773**，远多于真实合法的 A_14（必须存在某个 SQS 与之兼容才合法），其中包含很多"局部合法但全局非 SQS"的 A_14。这些"伪 A_14"的 m1Values[z] 可能算出非 perfect matching 的奇怪 hash。

**修复（两选一）**：

1. **把 `ordMatchings0_11[]` 改用哨兵值**：

```cpp
int ordMatchings0_11[Hash0_11Num];
memset(ordMatchings0_11, -1, sizeof(ordMatchings0_11));  // 初始化为 -1
...
int matching0_11Ord = ordMatchings0_11[m1Values[z]];
if (matching0_11Ord < 0) {
    // 当前 A_14 与 A_z 孙子结构不兼容，跳过
    return;
}
```

2. **或者用 `unordered_map<ull, int>` 替代固定大小数组**，未注册返回 `end()`。

3. 进一步：在 ConcatAi 入口立即过滤掉未注册 hash 的整条递归路径。

---

## Bug 15：`m1Values[12]` 出现 `0` 表明 m1 进制项中含 0（reorder 越界 / 排除元素被取）

**位置**：`GenerateSQS16` 中 461–467 行；`reorder[z]` 填充在 `PreSolveForAi(z)` 502–509 行。

**前提复核**：`reorder[z][i]` 仅对 `i ∈ {0..13}\{z, z^1}` 填值（12 个真实元素映射到 0..11），其余位置（i = z, z^1, 14, 15）保持默认 0。

**怀疑场景**：当前 `Ai[15]` 输入恰巧 son_blocks 是 `(0,1),(2,3),...,(12,13)`，每个 z 的 `z^1` 恰好就是其在 son_block 中的"伴随元素 w"，所以理论上 `reorder[z]` 排除 z 与 z^1 是正确的。但若**未来换不同的 A_15**（其 son_blocks 不是按 `z^1` 配对），则 `reorder[z]` 排除的元素错误，会让 m1 计算把 reorder[z][w] 当 reorder[z][z^1]，进而：

- A_14 中含 z 不含 15 的 6 条三元组的"另两个端点"包含了 w（即原本应被排除的伴随元素），但 `reorder[z][w]` 是被填了的合法虚拟编号 ⇒ 串接的 hash 错位。

**对当前测试输入的影响**：此 bug **暂时不触发**（因为 son_blocks 恰好是 `(z, z^1)` 形式）。但代码的"`z^1`"硬编码是脆弱设计。

**修复**：

```cpp
// 用 son_blocks 推出每个 z 的伴随元素 w（即与 z 同对的另一元素）
int partner[N_16];
memset(partner, -1, sizeof(partner));
for (int i = 0 ; i < 7 ; i++) {
    partner[son_blocks_for14[i].first]  = son_blocks_for14[i].second;
    partner[son_blocks_for14[i].second] = son_blocks_for14[i].first;
}
// 之后所有用到 z^1 的地方改成 partner[z]
Ai[z][len++] = tuple3{partner[z], 14, 15};
...
for (int i = 0 ; i < N_16 - 2 ; i++)
    if (i != z && i != partner[z]) {
        reorder[z][i] = tmpcnt; tmpcnt++;
    }
```

---

## Bug 16：`AzPreEntity::sed[24]` 大小固定为 24，写入时可能超出（潜在）

**位置**：350 行声明；549 行写入 `Az.sed[sedCnt++] = Ai[z][iSed]`。

**风险**：理论上 `sedCnt = Num_15 - 13 = 22`，未越界。但若 PRE_SOLVE 阶段 `mask` 数据异常导致候选三元组中"含 14 或 15"的判定逻辑错（例如 `Generate_seeds` 中三元组的 `state` 还未被重设时进入 PreSolveForAi 的 `iSed` 循环），可能让 `sedCnt > 22`。

**当前代码顺序**：

```cpp
Generate_seeds(..., Ai[z]);   // 末尾会 sort + 重设 state
// 这里 Ai[z][0..34].state 是正确的 3-bit 真实掩码
for (iSed = 0; iSed < Num_15; iSed++) {
    if ((Ai[z][iSed].state & (1<<14)) && !(Ai[z][iSed].state & (1<<15))) { m1 += ...; }
    if ((state & (1<<14)) || (state & (1<<15))) continue;
    Az.sed[sedCnt++] = Ai[z][iSed];
}
```

正常情况下 sedCnt 恰好 22 ✓。但若 `state` 字段**没被正确重设**（参考 Bug 12）—— 比如 `tuple3` 默认构造创建的 `Az` 局部变量内 `sed[24]` 全是垃圾 state —— 这里只写前 22 项，**后 2 项 `sed[22], sed[23]` 保持垃圾**。`AzPreEntity Az;` 是**局部变量**（行 534），构造器为 `tuple3 sed[24]` → 调用 `tuple3()`（默认构造），不初始化任何字段。

⇒ `Az.sed[22], Az.sed[23]` 的 `(a, b, c, state)` 是**栈上残留的垃圾值**。

后续 `preSolveAz[z][...].pb(Az);` 把整个 `Az` 拷贝进 vector，垃圾也跟着进。

**为什么是 bug**：ConcatAi 的 check / 读取只用 `sed[0..21]`（`size = Num_15 - len = 22`）⇒ 看似不用 sed[22], sed[23]。但**check 的范围是 `for (i = 0; i < size; i++)`**，size=22 ⇒ 不读 sed[22], sed[23] ✓。**实际不影响 check**。

但若代码后续修改了 `len`（从 13 改为更小），则 size 会 > 22，触及垃圾。**当前严格 22 ⇒ 暂安全**。

不过仍建议修：把 `tuple3 sed[24]` 改为 `tuple3 sed[24] = {}`（C++11 值初始化）或在构造时 `memset`。

---

## Bug 17：A_14 候选的"伪命中桶 0"导致大量无效递归

**与 Bug 14 联动**。当 `m1Values[z]` 落在未注册 hash 时，`preSolveAz[z][0]` 桶被错误读取。该桶里的 `AzPreEntity` 对应的实际 perfect matching 是 `(0,1),(2,3),...,(10,11)`，但当前递归路径上的 A_z 与 A_14 共同孙子结构却**不是这个 matching**。

**结果**：
- 桶里 item 的 22 条三元组的端点分布与"理应满足"的端点分布**完全错配**；
- 但 `check` 函数只检查"mask 中是否已存在某些三元组" + "mask 中是否能查到带 z 替代的等价三元组"——**它不检查端点是否对得上 A_z 与 A_14 的孙子结构**；
- 部分 item 因为巧合（mask 中某些三元组确实存在）**伪通过 check**，进入 `ConcatAi(z-1)`；
- 越深入冲突越多，最终在 z=8、7 处所有桶都无法通过 check（因为前面已经被错误的内容污染）。

**这就是"递归不能深入到 z=8、7"的根本原因**之一。

**修复**：见 Bug 14（用哨兵值过滤未注册 hash）。

---

## Bug 18（强烈怀疑）：`AzPreEntity Az;` 在 PreSolveForAi 中是局部变量，每次循环创建 + push_back 大量复制

**位置**：534 行。

**性能问题**（不是正确性，但解释 35,695,773 个候选的内存压力）：每次产生 A_z 候选都构造一个 `AzPreEntity`（含 24 个 `tuple3`，约 24*16 = 384 字节），**push_back** 到 vector 时拷贝。35M 候选 × 384B = ~13GB。

**修复（性能向）**：用 `emplace_back` + 直接构造；或预分配 `vector::reserve(NumsA14)`。

---

## 修订后的优先修复顺序（合并新旧）

1. **Bug 14**（关键）：`ordMatchings0_11` 用 -1 哨兵；ConcatAi 中遇到未注册 hash 直接返回，避免污染递归。
2. **Bug 2 + 4 + 5 + 6 + 7**：边界折半数据正确（仍未到 z=6，但需提前修好）。
3. **Bug 1**：z=6 边界 return + ans++（已修部分）。
4. **Bug 3**：tuples0_6Ord → triplesBits2Ord（已修）。
5. **Bug 8**：reorder tmpcnt++（已修）。
6. **Bug 11 + 12**：清残留 + 默认构造初始化。
7. **Bug 15**：把 `z^1` 替换为 `partner[z]`，鲁棒到所有 A_15 输入。
8. **Bug 16 + 18**：栈/堆变量初始化与性能优化（次要）。
9. **Bug 10 + 13**：调试输出和命名整洁。
