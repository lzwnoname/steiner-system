# SQS(16) 搜索过程 GPU 化执行计划

> 编写日期：2026-06-06
> 关联文档：`iterative_serach_algorithm.md`（递归→迭代改造细节）
> 关联代码：`searchAi.cpp`（CPU 基线）、`searchAi+ai_iterative.cu`（已含迭代版 `ConcatAiIter`）
> 硬件假设：4 张 GPU，单卡显存 24 GB（必要时可拉到 30 GB）

---

## 0. 现状速读

### 0.1 CPU 基线流程（`searchAi.cpp`）

```
main()
  ├─ generate0_6Tuples()          // 35 元四元组扩展，得到 tuple0_6states
  └─ solveForAi()
       ├─ for z = 13 .. 7:
       │     PreSolveForAi(z)     // 生成 preSolveAz[z][mOrd] 桶集合
       ├─ PreSolveForAi(14)       // 14 不入桶，仅生成 sol0_9 / Matchings*
       └─ for each (i,j,k,l,e) → A14:
             Generate_seeds(... Ai[14])
             mark Ai[14] 进 mask/maskAi
             GenerateSQS16()
                ├─ for z = 13 .. 7: 填 Ai[z][0..12] 前缀 + 算 m1Values[z]
                └─ ConcatAi(13)   // 主搜索：逐层枚举 → 边界 z==6 二分计数
             unmark Ai[14]
```

### 0.2 已有 GPU 改造（`searchAi+ai_iterative.cu`）

| 模块 | 状态 | 说明 |
| --- | --- | --- |
| `Generate_A15` 核函数 | ✅ 实现 | 在 GPU 上枚举 (i,j,k,l,e) → A_z 候选并写入 `dans` |
| `cudaSearchingAi` | ⚠️ 半成品 | 4 卡 OMP 分片调用 `Generate_A15`，但拷回 host 后 **立即 `free(ans)`**（数据没持久化） |
| `cudaMemoryTransfer_preSolve` | ✅ 实现 | 把所有只读表（log_2、sedOf*、reorder…）拷到 device managed 区 |
| `ConcatAi` 迭代版 | ✅ 实现 | `ConcatAiIter`，参数化 mask/maskAi，已在文档 1 中归档 |
| 主搜索核函数 | ❌ 缺 | `generateSQS16` 是直接搬 CPU 代码的占位，无法编译 |
| 多卡聚合命中数 | ❌ 缺 | 当前只 sum `hostCnt`，但拿不到 SQS(16) 计数 |

### 0.3 主要风险点

1. **预处理产物没持久化**：`PreSolveForAi(z)` 末尾 `free(ans)`，搜索阶段拿不到 `preSolveAz`。必须先修。
2. **每线程 mask/maskAi 显存爆炸**：`int mask[1<<16]`=256 KB + `bool maskAi[16][1<<16]`=1 MB，每线程 1.25 MB → 2 万线程就要 25 GB，无解。必须压缩。
3. **`preSolveAz` 总量大**：7 个 z 层 × 量级 NumsA14（~36M） × `sizeof(AzPreEntity)` = 100 B → 25 GB 满载，需要打包压缩。

---

## 1. 总体并行策略

> 直接对标已有的 `Generate_A15` 并行思路：把"对 A14 的枚举"按 OMP 切分到 4 卡，再在每卡上按 grid×block 切分到大量线程。

### 1.1 任务粒度

- **单元任务**：1 个 A14 → 跑 1 次 `ConcatAiIter(13)` → 累加命中 SQS(16) 数。
- **线程映射**：每线程串行处理一段连续的 A14（chunked）。
  - 总 A14 数：`NumsA14 ≈ 3.56e7`。
  - 4 卡 × 256 blocks × 256 threads = 262 144 threads/卡 × 4 = **~1 M threads**。
  - 每线程负担 `ceil(NumsA14 / 1M) ≈ 36` 个 A14（量级合适，单卡 6–10 分钟内出第一个 chunk 的结果）。
- **GPU 间负载均衡**：和 `Generate_A15` 一样按 `n11*n10` 范围切片；`A14` 的产生顺序在 GPU 端可重现，所以可以按 A14 全局 index 范围切。

### 1.2 数据流概览

```
[Host 准备]
  ├─ 跑 PreSolveForAi(z=13..7)：生成 preSolveAz[z][mOrd]，
  │   并把它们 CSR 化、可选压缩，落到 host pinned buffer
  ├─ PreSolveForAi(14)：得到 Matchings13/12 / tuple11 / tuple10 / sol0_9 / sedOf*
  └─ 跑 generate0_6Tuples()：得到 tuple0_6states 排序后数组

[每卡装载]（OMP 4 线程，每个 cudaSetDevice）
  ├─ 把 preSolveAz CSR 数据复制到本卡（约 9 GB，见 §2.2）
  ├─ 把 sedOf*/sol0_9/log_2/Matchings* 等只读表复制到本卡
  ├─ 把 tuple0_6states / triplesBits2Ord / tuples0_6FullMask 复制到本卡
  └─ cudaMalloc 每线程私有状态区（~10 KB × N_threads）

[Kernel SearchSQS16]
  for each A14 in chunk:
      step1. 重建 Ai[14]（35 triples）+ Ai[15] 已是常量
      step2. 计算 m1Values[7..13] + 填 Ai[7..13] 的前 13 个 prefix
      step3. 取出 d_cands[d] = AzData[z=13-d] + bucket_offset[m1Values[z]]
      step4. 初始化每线程 Ai_state[16][35]、idx[7]
      step5. 调用 ConcatAiIter
      step6. 累计本线程命中数
  最后 atomicAdd 到 d_resultCnt

[Host 聚合]
  total = sum hostCnt[0..3]
```

---

## 2. 数据布局与显存预算

### 2.1 每线程私有状态（极简版，**不再用 mask/maskAi**）

| 字段 | 类型 | 大小 |
| --- | --- | --- |
| `Ai_state[16][35]` | `int` | 2 240 B |
| `idx[7]` | `int` | 28 B |
| 备用对齐 / scratch | — | 28 B |
| **小计** | | **~2.3 KB / 线程** |

> ⚠️ 设计要点：**彻底放弃** `mask[1<<16]` 与 `maskAi[16][1<<16]`，把所有"是否被 mark"的查询改成 **线性扫描 `Ai_state`**。
>
> - `mask[s]` 等价于：在 `Ai_state[15..z]` 共 `(16-z)*35 ≤ 315` 个 state 里找等于 `s` 的项。
> - `maskAi[bit][s]` 等价于：在 `Ai_state[bit][0..34]` 这 35 个 state 里找等于 `s` 的项。
> - `check_param` 单次成本：22 个 sed × (高位 ≤ 2 个 × 35 比较 + 低位走全扫 ≤ 315 比较) ≈ 8 K 次比较。GPU warp 32 路并行下完全可吞。
>
> 收益：每线程 2.3 KB，1 M threads × 2.3 KB ≈ 2.3 GB / 4 卡 = **每卡 0.6 GB**。

线程私有缓冲一律走 `cudaMalloc` 到 device global memory（不要用 local memory，否则会 spill 到 DRAM 同时还有 ECC 加倍代价）。

### 2.2 只读全局数据（每卡一份）

| 数据 | 量级 | 备注 |
| --- | --- | --- |
| `dAzData[z]` (z=7..13) | 7 × ~5 M × 56 B ≈ **2 GB / z** | 见 §2.3 压缩；7 层共 **~14 GB**（可降至 ~9 GB） |
| `dAzBucketStart[z][mOrd]` | 7 × 10 395 × 4 B ≈ 290 KB | CSR 索引：第 z 层、第 mOrd 桶起点 |
| `dAzBucketSize[z][mOrd]` | 同上 | 桶大小 |
| `dA14Stream` | 详见 §2.4 | A14 枚举流，可选预生成或 on-the-fly |
| `d_log_2[1<<21]` | 8 MB | 已有 |
| `d_tuple0_6states` | ~6 MB（按 README 数量） | sorted by `first` |
| `d_triplesBits2Ord[1<<8]` | 1 KB | |
| `d_tuples0_6FullMask` | 8 B | |
| `dsedOf13/12/11/10` | 已有，~25 MB | 仅 A14 重建时需要 |

**单卡总只读量预估：~10 GB（压缩后）+ ~1 GB 杂项 ≈ 11 GB。**
**单卡线程私有：~0.6 GB。**
**单卡使用：~12 GB**，留 12 GB 余量给 CUDA runtime / 临时 buffer / 调试，**满足 24 GB 限额**。

### 2.3 `AzPreEntity` 压缩（必要）

原结构（100 B）：
```cpp
struct AzPreEntity {
    int mOrd;          // 4 B
    int sed[24];       // 96 B（每个 int 实际只有 3 个 bit 在 [0..15]）
};
```

压缩思路：每个 `sed[i]` 是 16 位 mask，最多 3 个 bit 置位。直接保留 16-bit `unsigned short`，22 个 sed 即 44 B；加 `mOrd` (4 B) → **48 B 对齐到 56 B**（保留 12 B 给将来字段）。

```cpp
struct AzPreEntityPacked {     // 56 B
    int       mOrd;            // 4 B
    uint16_t  sed[22];         // 44 B
    uint16_t  pad[6];          // 12 B
};
```

> 替代方案：4 bit/index × 3 indices = 12 bit/sed，22 sed = 33 B + 4 B mOrd = **37 B**。能再压缩 ~30%，但解码逻辑变复杂，暂不采用。

### 2.4 A14 重建：on-the-fly vs. 预生成

- **on-the-fly**（推荐）：每个线程拿到自己分得的 `(pos_start, pos_end)` 区间，按 `Generate_A15` 的同样四重循环 `(i, k, m, ans)` 在 device 上重新枚举出对应 A14。优点是省掉 ~36 M × 35 × 4 B ≈ 5 GB 显存。
- **预生成**：先跑一遍 `Generate_A15` 把所有 A14 序列化到 `dA14Stream`。优点是解耦、便于 debug，但占显存。

**初版使用 on-the-fly**：把 `Generate_A15` 内联到 `SearchSQS16` 的最外层循环中。

---

## 3. 函数清单

### 3.1 必须新增

| 函数 | 类别 | 作用 |
| --- | --- | --- |
| `BuildAzCSR(int z)` | host | 把 `preSolveAz[z][mOrd]` 排序、扁平化到 CSR；填 host buffer。 |
| `UploadAzCSR(int dev_id, int z)` | host | 把 CSR 拷到 dev_id 卡 |
| `__global__ void SearchSQS16Kernel(...)` | kernel | 主搜索；每线程跑一段 A14 |
| `__device__ void RebuildAi14(...)` | device | 由 (i,k,m,ans) → 35-state Ai_state[14][0..34] |
| `__device__ void FillPrefixAndM1(...)` | device | GenerateSQS16 中 z=13..7 的 prefix 与 m1Values 计算的 device 版 |
| `__device__ bool check_linear(...)` | device | 替换 `check_param`，使用 `Ai_state` 线性扫描而非 mask/maskAi |
| `__device__ void ConcatAiIterPacked(...)` | device | `ConcatAiIter` 的 packed 版本：处理 `AzPreEntityPacked`，并改用 `check_linear` |
| `__device__ inline bool hasState(int* AiZ, int s)` | device | 35-长度线性查 state，必要时 `#pragma unroll` |
| `RunSearch()` | host | 顶层调度：4 卡 OMP 分片，启 kernel，聚合 |

### 3.2 必须修改

| 现有函数 | 改动 |
| --- | --- |
| `PreSolveForAi(z)` | 不再 `free(ans)`；改为把 `dans` 转换为 CSR，**保留**在 host pinned buffer，等所有 z 都跑完后统一上传到各卡。需要修复 `PreSaveForConcat` 中的 m1 计算（CPU 版按 `tmpMatching[i] > i` 过滤，GPU 版当前缺这一步，可能算错 mOrd —— 已在 §6 标记为风险） |
| `searchSQS16()` | 把当前未编译过的占位 `GenerateSQS16<<<>>>` 替换为 `SearchSQS16Kernel<<<>>>`；返回值改为聚合到 `unsigned long long total_cnt` |
| `cudaSearchingAi` | 不再 `free(d_sol0_9)`：搜索阶段也要用，需在所有 z 都处理完后才释放 |
| `Generate_A15` | 抽出 A14 重建子流程供 `SearchSQS16Kernel` 复用（即 `Generate_seeds` 部分） |

### 3.3 可保留 / 删除

- `concatAi(int, AzPreEntity*)` 空 stub：删除。
- `__device__ __managed__ AiInSearch / maskInSearch`：删除（每线程改为私有 buffer）。
- `__global__ void generateSQS16(...)`：当前未通过编译的占位整段删除，由 `SearchSQS16Kernel` 替代。

---

## 4. 实现里程碑（增量交付）

> 每个里程碑结束都应能编译通过 + 单卡可跑（即使是单线程退化版），方便 bisect。

### M1：preSolveAz 持久化 + CSR
- 修 `PreSolveForAi`：不再 `free`，把所有 z 的产物 CSR 化保存到 host pinned。
- 验证：打印 `dAzBucketSize[z][mOrd]` 总和与 CPU 版 `preSolveAz[z][mOrd].size()` 总和一致。
- 修复 `PreSaveForConcat` 的 m1 计算（与 CPU 对齐，按 `tmpMatching[i] > i` 过滤）。

### M2：PackEntity + 上传 4 卡
- 实现 `AzPreEntityPacked` 结构 + 转换函数。
- `UploadAzCSR` 把 CSR + Packed 数据拷到每张卡的 `cudaMalloc` 区（**不**用 managed，避免跨卡 page fault）。
- 用 `cudaMemGetInfo` 打印各卡剩余显存，确认不超 18 GB。

### M3：SearchKernel 单 A14 单线程版
- `SearchSQS16Kernel<<<1, 1>>>` 只跑 1 个 A14（全局 index = 0）。
- 内部直接调 `ConcatAiIterPacked`。
- 命中数对照 CPU 单 A14 的命中条数（CPU 版可临时把 `DEBUGVARIABLE++` 改成单纯 `cnt++` 拿到该 A14 的真实命中数）。

### M4：SearchKernel 多线程 + chunk
- 扩展到 `<<<1, 256>>>`，每线程跑一段 A14（chunk_size = 1 起步）。
- 每线程在 device global memory 自己的私有区维护 `Ai_state[16][35]` + `idx[7]`。
- 验证：`<<<1, 256>>>` 命中数 = 256 个 A14 单跑命中数之和。

### M5：单卡满载 + 4 卡聚合
- 扩到 `<<<256, 256>>>`，按 §1.1 切分 chunk。
- `RunSearch` 套上 `#pragma omp parallel num_threads(4)`，4 卡每卡负责 `n11*n10/4`。
- `atomicAdd(d_resultCnt, ...)` → `cudaMemcpy` 回 host → 4 卡 sum。
- 验证：先用小批量（如限制只跑前 N 个 A14）与 CPU 版对齐命中数。

### M6：性能调优
- 用 `nvprof` / `nsight compute` 看 `ConcatAiIterPacked` 的 occupancy / 寄存器压力。
- 视情况：`__launch_bounds__`、`__restrict__`、共享内存装载常用 `Ai_state[15]`、`#pragma unroll` 35-长度循环。

---

## 5. 编码规范

### 5.1 风格

- 缩进：与现有 `.cu` 一致使用 **Tab**。
- 命名：device 端变量 / 函数前缀 `d_` 或 `d`；packed 类型加 `Packed` 后缀。
- 头文件不变，新文件名：`searchAi_gpu.cu`（保留原 `searchAi.cu` 与 `searchAi+ai_iterative.cu` 作为基线参考）。

### 5.2 CUDA 约定

- 所有 device 函数加 `__device__` 修饰；可被 host 调用的工具函数加 `__device__ __host__`。
- kernel 标量参数尽量用值传，指针参数加 `__restrict__`。
- 全局 `__device__ __managed__` 仅用于真小（< 32 MB）只读表；大块只读数据走 `cudaMalloc` + `cudaMemcpyHostToDevice`。
- 多卡场景下 **避免 managed**（跨卡 page migration 代价巨大），所有数据手动多卡复制。
- 线程私有 buffer 走 `cudaMalloc` 到 device global，**不**用 local memory（>= 16 KB 自动 spill）。
- 命中计数器 `unsigned long long *d_resultCnt`，原子操作 `atomicAdd`。
- `cudaError_t cudaerr = cudaGetLastError();` 在每个 kernel 调用 + `cudaDeviceSynchronize()` 后必查。

### 5.3 防御性约束

- 任何 `cudaMalloc` 都要配 `cudaMemset(0)` 后再用。
- 每个 kernel 入口断言 `pos_start_idx < pos_end_idx`。
- `assert` 仅保留于 debug 构建（可用 `#ifdef DEBUG`）。
- 4 卡聚合处用 `#pragma omp barrier` 显式同步。
- 长循环（如 35-扫描）加 `#pragma unroll` 减少分支预测压力。

### 5.4 命中数处理

- GPU 版只统计数量，**不输出具体 SQS(16) 内容**（按用户指令）。
- `unsigned long long` 累计；最终 host 端打印一行 `Total SQS(16) = %llu`。
- CPU 版里的 `DEBUGVARIABLE` 仅是调试遗留，GPU 版不复刻其计数 / 提前 `exit(0)` 行为。
- 后续若要 dump 内容，再加一个 ringbuffer + 尾部 cudaMemcpy（不在本计划范围内）。

---

## 6. 风险与回退预案

| 风险 | 表现 | 回退 |
| --- | --- | --- |
| `AzPreEntity` 显存占用爆 | 单卡 OOM | 走 §2.3 替代方案的 4-bit packing，再压缩 30% |
| `m1` 计算 GPU 版偏差 | 命中数与 CPU 不一致 | 在 M1 阶段对照 CPU 版逐 A14 dump m1Values，补上 `tmpMatching[i] > i` 过滤 |
| 线性扫描 `Ai_state` 过慢 | kernel 时延高 | 退路 1：`mask` 退化为 64 KB bool 数组 + 限制并发线程数到 ~10 K（每卡 0.6 GB）<br>退路 2：把 35-长度 `Ai_state[bit]` 装入 shared memory（每 block 共享）|
| 单 kernel 时长超过 watchdog (~5 s on Linux) | 超时杀 | 把 chunk 拆得更细，每 chunk 调一次 kernel；中间 host 端 `cudaDeviceSynchronize` |
| 4 卡负载不均（A14 早期/末段难度差异大） | 个别 GPU 等待 | 切换为动态调度：用 `unsigned long long *d_nextChunk` 让线程 `atomicAdd` 抢任务 |

---

## 7. 待确认事项（开始写代码前）

1. `PreSaveForConcat` 中 m1 是否有意省略了 `tmpMatching[i] > i` 过滤？（可能是 BUG，也可能用户已经在别处补）
2. `dans` 的容量 `NumsA14 / 2` 是否针对每卡？是否覆盖最坏分布？
3. 多卡间是否启用 NVLINK / Peer Access？若启用，可考虑 1 份 `AzData` 跨卡共享（节省 ~9 GB ×3）。
4. 是否需要保留 CPU 版小批量对齐用的 sanity check 入口？建议保留一个 `--max=N` 启动参数，便于调试时只跑前 N 个 A14 与 CPU 对账（CPU 端把 `DEBUGVARIABLE` 改成纯计数即可）。

---

## 附：阶段产出文件结构建议

```
steiner-system/
├─ searchAi.cpp                        // 不动，CPU 基线
├─ searchAi+ai_iterative.cu            // 不动，含迭代 ConcatAiIter 参考实现
├─ searchAi_gpu.cu                     // 新：本计划主代码（M1..M5 全部进这里）
├─ iterative_serach_algorithm.md       // 文档：递归→迭代
└─ plan.md                             // 本文档
```

