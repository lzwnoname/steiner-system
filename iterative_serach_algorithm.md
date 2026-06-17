# ConcatAi 递归 → 栈式迭代改造文档

> 归档日期：2026-06-06
> 关联文件：`searchAi.cpp:457-566`（CPU 递归版）、`searchAi.cu` / `searchAi+ai_iterative.cu`（GPU 半成品 + 迭代版本）
> 适用场景：SQS(16) 搜索过程下移到 GPU，每个 GPU 线程独立跑一份 `ConcatAi(13)`，递归不能直接搬到 device 上，必须改成栈式迭代。

---

## 1. CPU 递归版语义梳理

`ConcatAi(z)` 自上而下递归，层级 `z = 13 → 12 → … → 7`，到 `z == 6` 进入边界处理。每一层结构如下：

```
ConcatAi(z):
    if (z == 6):
        # 边界：组装 A_7..A_15 的 4-block 集合，
        # 与 A_0..A_6 的可能子集做二分匹配，命中即一组 SQS(16)
        do_base_case()
        return

    # —— 进入层 z —— #
    mark_prefix(z)                       # Ai[z][0..12]，由 GenerateSQS16 提前填好
    for item in preSolveAz[z][m1Values[z] 对应 ord]:
        if not check(item, z): continue
        mark_item_suffix(z, item)        # Ai[z][13..34] = 解码 item.sed[0..21]
        ConcatAi(z - 1)                  # 下钻
        unmark_item_suffix(z, item)
    unmark_prefix(z)
```

### 1.1 关键状态（CPU 版的全局变量）

| 名称 | 类型 | 作用 |
| --- | --- | --- |
| `Ai[16][35]` | `tuple3` | 每层的 35 个 STS(15) triple，搜索时被填充 / 回滚 |
| `mask[1<<16]` | `int` | 三元组 state 的多重计数；`check` 据此判定冲突 |
| `maskAi[16][1<<16]` | `bool` | 每层（按 z 分桶）的状态命中表，跨层兼容性检查 |
| `m1Values[z]` | `ull` | 当前 A14 在第 z 层的 0–11 配对哈希；用来挑桶 |
| `preSolveAz[z][mOrd]` | `vector<AzPreEntity>` | 第 z 层、第 mOrd 个匹配桶中所有候选 |

### 1.2 边界 `z == 6` 做的事

1. 扫 `Ai[15..7][0..34]`，把每个 triple 拼上一位 `1 << i` 得到 4-block 状态 `tmp_all`，去重落入 `ans_state[]`。
2. 对其中只覆盖 `{0..6}` 子集的 triple，更新 `tuples0_6Mask`（用 `triplesBits2Ord` 索引位）。
3. `tuples0_6Mask ^= tuples0_6FullMask` 取互补，二分 `tuple0_6states`，找到 `first >= 该 mask` 的首个位置，再线性扫连续相等段。
4. 每命中一段累加一次：GPU 版用 `atomicAdd(d_resultCnt, 1ULL)`。
   （CPU 版同位置的 `DEBUGVARIABLE++` 仅是调试用计数器，GPU 版不需要复刻其 `==20 exit(0)` 之类的提前终止行为。）

### 1.3 为什么必须改迭代

- CUDA device 函数的栈很浅；ConcatAi 递归深度 7 看似不深，但每层栈帧带 `Ai[][]`、`mask[]`、`maskAi[][]` 等大数组，叠加后随时爆栈。
- `preSolveAz` 是 `vector`，device 端无法直接迭代；必须先扁平化为 device 可见的连续数组 + CSR 索引。
- 核函数里禁止动态 `new` / `vector`，递归回溯路径上的"撤销"动作必须可静态推断。

---

## 2. 栈式迭代设计

### 2.1 关键观察

- 递归深度固定为 7：`d ∈ [0, 6]` 对应 `z = start_z - d`（`start_z = 13`）。
- 每层只有"枚举候选 + 是否下钻"这一种状态机，**无需变长栈**，用 `int idx[7]` 即可模拟整条调用链。
- 每个候选成功后压入 / 失败/回溯时弹出的一对操作严格对称，迭代版只要在"进入下层"和"父层下次循环"两个边界做对应的 mark/unmark 即可。

### 2.2 状态机与 mark/unmark 时机

| 时机 | 动作 |
| --- | --- |
| 进入层 z | mark Ai[z] 前 13 个前缀 |
| 候选通过 check | mark item 后缀（22 项） |
| 下钻到 z-1 | 同上 mark 保留 → 进入子层后 mark 子层前缀 |
| 子层 idx 耗尽 | unmark 子层前缀 → 弹出 → unmark 父层最近压入的 item 后缀 |
| 父层全部候选用尽 | unmark 父层前缀 → 弹出再上一层 |

### 2.3 主循环骨架

```cpp
while (d >= 0) {
    z = start_z - d;
    if (idx[d] >= numCand[d]) {            // 当前层耗尽
        unmark_prefix(z);
        d--;
        if (d < 0) break;
        unmark_item_suffix(start_z - d);   // 撤销父层下钻前的 item
        continue;
    }

    item = candidates[d][idx[d]++];
    if (!check(item, z)) continue;
    mark_item_suffix(z, item);

    if (z - 1 == 6) {                      // 边界：直接执行底盘逻辑
        do_base_case();
        unmark_item_suffix(z);             // 不下钻，立刻回滚
    } else {
        d++;
        mark_prefix(start_z - d);
        idx[d] = 0;
    }
}
```

完整实现参见 `searchAi+ai_iterative.cu` 的 `ConcatAiIter`（约 850 行起）。

---

## 3. CUDA 适配要点

### 3.1 `check` 改成参数化

原 `check` 依赖 `__device__ __managed__` 全局 `dmask` / `dmaskAi`，多线程并发时会互相污染。改成 `check_param(item, size, z, pMask, pMaskAi)`，由调用方传每线程指针。

### 3.2 `extract2tuple3` 复刻为 `d_extract2tuple3`

CPU 版用 `lowbit` + `log_2`，device 版替换为 `dlowbit` + `d_log_2`，并通过 `__device__ __host__ tuple3(int,int,int)` 构造（已在结构体里就绪）。

### 3.3 边界局部数组的去重策略

CPU 版用 `bool tmpMask[1<<16] = {0}`（单次 64KB + 清零），GPU 上每线程不允许这么大栈。改为：

```cpp
ull ans_state[Num_16];  // 上限 140
int blkCnt = 0;
// 线性查重：候选最多 ~140，扫描总量 9×35×140 ≈ 4.4 万次比较，可忽略
```

### 3.4 命中计数走原子

GPU 版只需要"命中 SQS(16) 的总数"，用 `atomicAdd(d_resultCnt, 1ULL)`；调用方传一个 `unsigned long long *`。CPU 版位置上的 `DEBUGVARIABLE` / `if(DEBUGVARIABLE==20) exit(0)` 是调试代码，不复刻。

### 3.5 与 CPU 版的等价性自查

- 进/出层时机：✅ 进层立刻打前缀，idx 耗尽立刻撤前缀。
- item 后缀生命周期：✅ check 通过后压入，子层全部回溯完才撤销，对应 CPU 的 "for…ConcatAi(z-1)…撤销"。
- 边界判断 `z-1==6`：✅ 内联在 `z==7` 帧里，与 CPU 在 `z==6` 入口立即 return 等价。
- `tuples0_6Mask` / 二分 / 命中累加：✅ 一一对照 `searchAi.cpp:461-528`。

---

## 4. 已知遗留 / 后续工作

1. **`mask` / `maskAi` 显存压力**：每线程 1MB+ 现状跑不动多线程，需进一步压缩或彻底替换为线性扫描（见 `plan.md` 的方案）。
2. **候选数据结构**：当前 `ConcatAiIter` 接口要求调用方传 `d_cands[7]` 与 `d_nCand[7]`，预处理结果必须先做 CSR 化并保留在显存上（当前 `PreSolveForAi` 在拷回 host 后立即 `free`，需要修复）。
3. **A14 的 `m1Values[7..13]` 预计算**：迭代函数本身不算这个，由调用方/A14 流水阶段提前算好。

---

## 5. 参考实现位置

- `__device__ inline tuple3 d_extract2tuple3(int)`：`searchAi+ai_iterative.cu:784`
- `__device__ inline bool check_param(...)`：`searchAi+ai_iterative.cu:794`
- `__device__ void ConcatAiIter(...)`：`searchAi+ai_iterative.cu:852`

