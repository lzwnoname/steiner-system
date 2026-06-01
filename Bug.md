# `searchAi.cpp` 第五轮：折半拼接仍找不到匹配 + cnt = 140 现象分析

## 0. 现状

- 真凶 1 (`int → ull` 移位 UB) 已修；
- 真凶 2 (二分后 while 条件 `ans <= r`) 已修；
- 但折半拼接 0-6 仍找不到匹配；
- out.txt 中观察到："有时 cnt = 140 已经达到 SQS 总数"。

---

## 1. cnt = 140 是否合法？

设 SQS(16) 的 140 个四元组按"含 ≥7 元素的个数 k"分类（Q_0..Q_4），则：
- Σ Q_k = 140；
- Σ k × Q_k = 9 × 35 = 315（A_7..A_15 共 9 个 A_i 的总三元组数）。

ConcatAi(z=6) 入口的 cnt（按 4-bit `tmp_all` 去重）= Q_1 + Q_2 + Q_3 + Q_4 = **140 - Q_0**。

⇒ **cnt = 140 ⇔ Q_0 = 0**：当前 SQS 假设里"完全 ⊂ {0..6} 的四元组数 = 0"，即所有 140 个四元组都涉及至少一个 ≥7 元素。

**这种 SQS 数学上存在**——是否取此值取决于具体 SQS 与 {0..6} 这 7 元素集的关系。所以 cnt = 140 **不是 bug，是合法情形**。

---

## 2. 真凶 4（致命）：cnt = 140 时折半搜索表中没有空解

### 数学推导

⊂{0..6} 的三元组共 35 个。每个 t ⊂{0..6} 对应唯一 SQS 四元组 `t ∪ {x}`：
- 若 x ≥ 7：t ∈ A_x ⇒ ConcatAi 累加它的 bit；
- 若 x ≤ 6：t 属于 Q_0 类 ⇒ 不在 A_7..A_15 中。

设 N_high = ⊂{0..6} 三元组中 x ≥ 7 的，N_low = x ≤ 6 的：
- 每个 Q_0 四元组拆出 4 个"x ≤ 6"三元组 ⇒ N_low = 4 Q_0；
- N_high = 35 - 4 Q_0。

⇒ ConcatAi 端 `tuples0_6Mask`（异或前）bit 数 = N_high = 35 - 4 Q_0；
⇒ 异或后 target bit 数 = **4 Q_0**。

**特别：Q_0 = 0 ⇔ cnt = 140 ⇔ target = 0**（不需要再覆盖任何 ⊂{0..6} 三元组）。

### 代码 bug

`searchAi.cpp` 第 705-707 行：

```cpp
void search0_6Tuples(int dep, int las, ull state, ull triplesSelect) {
    if (state != 0)                                  // ★ 跳过空状态
        tuple0_6states.pb(mp(triplesSelect, state));
    if (dep == 10) return;
    ...
}
```

入口 `search0_6Tuples(0, -1, 0, 0)` 时 state = 0 ⇒ **不 push** ⇒ `tuple0_6states` 中**没有** (triplesSelect=0, state=0) 这一项。

⇒ 当 cnt = 140 时 target = 0，二分找不到 ⇒ **必然拼不上**。

### 修复

**方案 A**（最小改动）：删除 `if (state != 0)` 限制，让空解也入表：

```cpp
void search0_6Tuples(int dep, int las, ull state, ull triplesSelect) {
    tuple0_6states.pb(mp(triplesSelect, state));    // ← 总 push
    if (dep == 10) return;
    ...
}
```

**方案 B**（更明确）：`generate0_6Tuples()` 末尾显式加：

```cpp
search0_6Tuples(0, -1, 0, 0);
tuple0_6states.pb(mp(0ull, 0ull));                  // ★ 显式空解
sort(tuple0_6states.begin(), tuple0_6states.end());
```

---

## 3. cnt < 140 但仍拼不上：可能的解释

如果修了真凶 4 后，cnt < 140 的情形下仍找不到匹配，可能原因排序如下：

### 可能 A（最大概率，**数学问题**）：当前 A_15 不可扩展为 SQS(16)

文献结论：**80 个本质不同 STS(15) 中，并非全部都可扩展为 SQS(16)**。可扩展的子集是少数（具体数需查文献，但应远小于 80）。

NewS(2,3,15).txt 第 1 行作为 A_15，有较大概率属于"不可扩展" 子集。这种情况下：
- 即使 check 修复完美，能跑到 ConcatAi(z=6) 边界，A_7..A_15 局部一致；
- 但整体不存在合法 SQS(16)；
- ⇒ 折半拼接的"另一半"在 tuple0_6states 中**根本不存在** ⇒ 永远拼不上。

**验证方法**：换 NewS 第 2、3、… 行作为 A_15 跑——如果某行能拼出 SQS(16)，说明代码正确，原 A_15 不可扩展。

### 可能 B：check 仍有漏网

修复后的 check 对 sed[] 22 项做完整多视角验证。但仍有几个隐含点：

1. **sed[] 不含"含 14 或 15"项**：这 13 项由 GenerateSQS16 直接派生自 A_15、A_14，其多视角一致由 SQS 性质 + 桶哈希保证（A_{z,14} = A_{14,z} 强制一致）。✓
2. **A_15 内部正确性**：固定 A_15 是输入数据，由 NewS(2,3,15).txt 的合法性保证。✓
3. **`else if (mask[item.sed[i]])`**：用 `mask` 不是 `maskAi`，但作用是"该 state 在 A_{z+1..15} 中不可重复"——SQS 性质保证同一 state 只在唯一 A_i 中 ⇒ ✓ 软约束正确。

⇒ check 修复后**应当**强制 (A_7..A_15) 是某 SQS 的截面（如果该 SQS 存在）。如果该 SQS 不存在（可能 A），check 会让搜索完全跑空。

### 可能 C：A_z 候选 sed[] 自身的 STS 合法性不够

A_z 候选由 PRE_SOLVE 折半搜索生成，要求"35 个 state 互不重复 + 每对元素恰一次"（STS(15) 性质）。
PreSolveForAi(z) 用 mask[A_15] 过滤，保证生成的 A_z 候选与 A_15 不冲突 + 自身是合法 STS(15)。**这条由折半搜索的设计保证**。

但 PreSolve 阶段**不保证**A_z 候选与 A_14、A_13 等兼容——这部分由桶哈希 + 运行时 check 处理。

如果 PreSolve 阶段折半搜索本身有 bug，会让某些"伪 STS(15)"漏入桶——但这种 bug 很难绕过 STS 的对元素覆盖性质。可能性较低。

---

## 4. 推荐排查步骤

按"代价从小到大"：

### 步骤 1：修真凶 4，再跑

最小改动（方案 A），重新编译。如果 cnt = 140 那种情况能拼上 ⇒ 真凶 4 解决了"半数"问题。

### 步骤 2：在 ConcatAi(z=6) 入口加诊断

```cpp
if (z == 6) {
    bool tmpMask[1 << N_16] = {0};
    int cnt = 0;
    ull tuples0_6Mask_covered = 0;
    int ans_state[Num_15 * 9];
    for (int i = 15 ; i > z ; i--) {
        for (int j = 0 ; j < Num_15 ; j++) {
            assert(__builtin_popcount(Ai[i][j].state) == 3);
            assert((Ai[i][j].state & (1 << i)) == 0);
            if (Ai[i][j].state <= (1 << 6) + (1 << 5) + (1 << 4))
                tuples0_6Mask_covered |= 1ull << (ull)triplesBits2Ord[Ai[i][j].state];
            ull tmp_all = Ai[i][j].state | (1 << i);
            if (tmpMask[tmp_all]) continue;
            ans_state[cnt] = (int)tmp_all;
            cnt++;
            tmpMask[tmp_all] = true;
        }
    }
    ull target = tuples0_6FullMask ^ tuples0_6Mask_covered;
    int Q0_expected = __builtin_popcountll(target) / 4;
    
    static long long boundaryCnt = 0, hitCnt = 0;
    boundaryCnt++;
    
    // 二分查找
    int sz = (int)tuple0_6states.size();
    int l = 0, r = sz - 1, ans = sz;
    while (l <= r) {
        int mid = (l + r) >> 1;
        if (tuple0_6states[mid].first >= target) {
            ans = mid; r = mid - 1;
        } else l = mid + 1;
    }
    bool found = (ans < sz && tuple0_6states[ans].first == target);
    if (found) hitCnt++;
    
    if (boundaryCnt % 10000 == 0 || found) {
        fprintf(stderr, "[boundary] entries=%lld hits=%lld | cnt=%d Q0=%d target_bits=%d found=%d\n",
            boundaryCnt, hitCnt, cnt, Q0_expected, __builtin_popcountll(target), found);
    }
    ...
}
```

观察指标：
- **`Q0_expected` 的分布**：如果总是 Q0_expected = 0（即总是 cnt = 140），且修真凶 4 后命中 ⇒ 仅"Q0=0"那种 SQS；
- **`Q0_expected` 落在 1..8 时是否有命中**：如果**永不**命中，说明 A_15 不可扩展为非 Q0=0 类 SQS；
- **总命中率**：30 分钟 0 命中 ⇒ A_15 大概率不可扩展，建议换。

### 步骤 3：换 A_15 测试

修改 main：

```cpp
for (int t = 0 ; t < 80 ; t++) {
    // 重置：mask, maskAi, preSolveAz
    memset(mask, 0, sizeof(mask));
    memset(maskAi, 0, sizeof(maskAi));
    for (int z = 0; z < 16; z++)
        for (int m = 0; m < MatchingNums_0_11; m++)
            preSolveAz[z][m].clear();
    DEBUGVARIABLE = 0;
    
    for (int i = 0 ; i < Num_15 ; i++) {
        Ai[15][i] = tuple3{getch(), getch(), getch()};
        int v = (1 << Ai[15][i].a) | (1 << Ai[15][i].b) | (1 << Ai[15][i].c);
        mask[v]++;
        maskAi[15][v] = true;
    }
    cin.clear();
    
    fprintf(stderr, "=== Trying A_15 #%d ===\n", t);
    solveForAi();
}
```

跑前 5-10 分钟（每个 A_15 短跑），看哪个 A_15 能命中。

### 步骤 4：彻底排查（仅在前面都不行时）

如果 80 个 A_15 全部 0 命中，说明代码仍有 bug（因为 80 个 STS(15) 中至少有一些可扩展，比如 AG(4,2) 派生的那个）。这时：
- 用 AG(4,2) 派生的 A_15 显式构造（用 Python 脚本生成一个已知可扩展的 A_15），写入文件第 1 行；
- 跑这一个，必能成功 ⇒ 否则说明代码仍有 bug，需进一步深查 PRE_SOLVE / PreSolveForAi / check。

---

## 5. 优先级总结

1. **★★★ 立即修真凶 4**（删 `if (state != 0)`）— **这是 cnt = 140 时拼不上的直接原因**。
2. **★★ 加诊断**（步骤 2）—— 在不同 cnt 下统计命中率，区分 Q_0 = 0 vs Q_0 > 0 是否都拼不上。
3. **★★ 换 A_15**（步骤 3）—— 验证 NewS 第 1 行是否是"不可扩展"STS(15)。
4. **★ 极端情况**（步骤 4）—— 用已知可扩展的 A_15 验证算法正确性。

修了真凶 4 后，建议先跑步骤 2 拿数据，再决定是不是换 A_15。
