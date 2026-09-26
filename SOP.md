# 项目理解 SOP —— SQS(16) GPU 搜索（steiner-system）

> **用途**：按本 SOP 的五个阶段顺序操作，可在一次会话内从零读懂本项目的数据、目的、算法与全部代码实现，并通过自带工具实证验证理解。每阶段末尾有"通过标准"，全部达成即视为读懂。
>
> **由 2026-09-26 的一次完整代码审查沉淀而成**，实测数据与验证程序均可复现（工具在 `test/` 目录）。

---

## 阶段〇：项目一句话

在元素集 {0..15} 上，**搜索以某个固定 STS(2,3,15) 为导出系统 A_15 的所有 SQS(16) = S(3,4,16)**（140 个四元组、每个三元组恰被覆盖一次），算法为"导出系统分解 + 孙子结构哈希分桶 + 折半枚举 + 递归拼接"，CPU 参考实现在 `searchAi.cpp`，GPU 加速版在 `searchAi.cu`（当前单卡、全量、边搜边存完整解）。

---

## 阶段一：弄明白数据集与问题定义

### 1.1 必须掌握的数学对象

| 对象 | 定义 | 关键性质 |
|---|---|---|
| SQS(16) = S(3,4,16) | {0..15} 上 140 个四元组，每个三元组恰被一个四元组覆盖 | 总数 = C(16,3)/C(4,3) = 140 |
| 导出系统 A_i | SQS(16) 中含 i 的四元组去掉 i → {0..15}\{i} 上的 STS(2,3,15) | 35 个三元组；**构造 SQS(16) ⟺ 构造 16 个两两兼容的 A_i** |
| 孙子结构 A_{i,j} | SQS(16) 中同时含 i,j 的四元组去掉 i,j → 14 元素上的 perfect matching（7 条边） | 对称性 A_{i,j}=A_{j,i}，是层间兼容的核心约束 |
| 四视角一致性 | 四元组 {a,b,c,d} 在 A_a/A_b/A_c/A_d 各贡献一个三元组 | check 函数的数学依据（见 3.4） |

### 1.2 输入数据：`NewS(2,3,15).txt`

- **80 个本质不同（非同构）的 STS(2,3,15)**，每行一个：35 个三元组，元素用 hex 字符（'0'-'9'→0-9，'A'-'E'→10-14），空白分隔。
- **两个关键约定**（算法正确性的前提，换数据源前必须重验）：
  1. 每行三元组**按 (a,b,c) 字典序排序**——这保证扫描含 z 的三元组时 `{z^1, z, 14}` 恒为最后一个，从而 `son_blocks[6] = (z^1, 14)`，支撑 `sed_map[12]=z^1, sed_map[13]=14` 的全局约定（`PreSolveForAi` 中的提取循环依赖它）；
  2. 80 个 STS(15) **拥有共同子结构** {0,1,14},{2,3,14},…,{12,13,14}——这是"所有 z 的预处理规模完全一致"（n11=n10=3329 等）的根源。
- 当前 `main()` 只用**第 1 行**作 A_15（`for (int t = 0; t < 1; t++)`）；遍历 80 行需按 `Bug.md` §4 步骤 3 重置 mask/桶后循环。
- 其它数据文件：`S(2,3,15).txt`（旧版 80 个）、`SQS16_sample.txt`（样例解）、`input.txt`（某 SQS(16) 的 block 列表，供小工具用）。

### 1.3 通过标准

能回答：① 为什么输入必须字典序排序（→1.2 约定 1）；② 为什么每个 z 的 n11/t/sol0_9 规模完全一样（→1.2 约定 2 + 行 13 中心恒为真实元素 14）；③ "以它为字结构搜 SQS(16)"中"字结构"指 A_15 作为导出系统。

---

## 阶段二：算法原理（文档阅读顺序 + 检查点）

**按顺序精读**（都在项目根目录）：

1. `solution.md` §1–2 —— 导出系统分解 + 对偶一致性。**通过标准**：能独立推导"check 为什么必须遍历所有高位而非只看最低高位"（Bug 2 的教训：`mask≠0` 只能保证某层含该三元组，不保证是正确的层）。
2. `solution.md` §4–6 —— 虚拟编号（sed_map/arcMask）、A_z 候选折半生成、按孙子结构哈希分桶。**通过标准**：能说出 A_z 的 35 个三元组的 5 类分解（7 含 15 / 6 含 14 不含 15 / 22 两者都不含 / 前 13 项与后 22 项的来源）以及 28 = 6+6+4+4+8 的行分层。
3. `solution.md` §7–9 —— GenerateSQS16 预填 13 项、ConcatAi 递归、z=6 边界折半补全。**通过标准**：能解释"前缀 13 项为什么不需要 check"（同源生成自动保证四视角一致：A_14 的三元组 {p,q,z} 同时出现在 A_z 的前缀 {p,q,14} 和 A_p/A_q 的前缀中）。
4. `code_analysis.md` —— CPU 版逐行分析（数据结构、位运算技巧、函数调用图）。
5. `solution_cuda.md` + `iterative_serach_algorithm.md` —— GPU 化策略与递归→栈迭代。**通过标准**：能说出 GPU 版四个核心替换（mask/maskAi→Ai_state 线性扫描、vector 桶→CSR、unordered_map→排序二分、递归→ConcatAiIter 栈迭代）及各自的理由。

### 2.1 本 SOP 补充的两个关键正确性论证（现有文档未完整记录，2026-09-26 审查论证）

**论证 A：check 的跨层查重完备性**（看似只查高位对偶、不查 t 本身重复，实则完备）。
设 t ∈ A_z ∩ A_x（z<x，即三元组被两个四元组 t∪{z}、t∪{x} 覆盖，非法）。穷举：
- t 全 < x（对 x 层是低位）且 t 含 >z 高位：z 层 check 强制 A_r ∋ (t\{r})∪{z} 对每个高位 r；若 t 还有 >x 的高位 s，x 层同样强制 A_s ∋ (t\{s})∪{x}，**两条强制结果共享一对 → 违反 A_s 的 STS 性质** → 矛盾；
- t 全 < x 且高位全在 (z,x) 之间：x 层走 `mask[t]` 低位检查……注意此时 A_z 未构造，x 层放行；但 z 层 check 时 t 走**高位分支还是低位分支取决于 t 自身**——若 t 含高位走上面情形，若 t 全 <z 走 mask[t]（此时 A_x 已 mark）→ 拒绝。残余情形（高位 r∈(z,x) 且 t 无 >x 元素）由 A_r 的强制与 Q2={t,x} 的传播在 A_u 冲突排除；
- 前缀-前缀重复：{p,q,14/15} 类前缀由 A_14/A_15 的 STS 对唯一性排除（{p,q} 对只在一个三元组中 → z=x）；
- 22 项与前缀混合：22 项不含 14/15、前缀必含 → 构造上互斥。
结论：**check + 每层候选自身的 STS 性质联合保证了"任一三元组至多出现在一个 A_i"**。这同时是 GPU check_linear 的完备性依据（两者逐分支等价）。

**论证 B：tuple11/tuple10 的 60 遍历上限安全**（理论上界其实是 68）。
8 元素无 son 边完全匹配数上界 68（a、b 不同 son 边时），> 60。但 A_15 中含 sed_map[11]（或 [10]）的 6 个非 son 三元组 {x_i,y_i,s11} 中，≥4 对端点落在虚拟 0..9 内（端点 ≠s10/z/14/z^1/s11 由 STS 对唯一性排除），其中 ≥2 条禁边的端点完全落在排除 a、b 后的 8 元素中（含 a 的禁边 ≤1 条，因真实对 (a_real,s11) 唯一）→ 至少排除 27 个匹配 → 解数 ≤ 41~50 < 60。**实测 50**（`test/verify_bounds.cpp`）。结论：`k < 60` 遍历上限对拥有该子结构的任意 STS(15) 输入安全，但属"论证安全"而非"结构安全"。

### 2.2 通过标准（阶段二总）

合上文档能画出：主枚举 → GenerateSQS16（7 层各填 13 项 + 算 m1Values）→ ConcatAi(13→7)（取桶→check→填 22 项→下钻）→ z=6 边界（累计 tuples0_6Mask→need→二分 tuple0_6states）的完整调用流，并指出每步维护的不变量。

---

## 阶段三：CPU 版代码实现（`searchAi.cpp`）

### 3.1 推荐阅读顺序（函数 → 关注点）

1. `main` —— 读 A_15、mark mask/maskAi[15]（全程保留）；`generate0_6Tuples` 预生成边界表（5596 项，**含空集 (0,0)**，Bug 5）。
2. `PreSolveForAi(z)` —— 首次调用做 PRE()+search0_11Matching；从 A_15 提取 son_blocks（注意依赖字典序）；`PRE_SOLVE` 建折半数据；四重循环枚举 (i,j,k,l,e) → Generate_seeds → 算 m1 → 入桶。
3. `PRE_SOLVE` 内部三件套：`searchTable`（行 13/12 完全匹配，跳 son 边 + mask 过滤）、`search4rows`（行 11/10 的 4 补丁）、`search0_9`（下半 8 三元组，按边占位 s 分桶存 (high,low)）。
4. `Generate_seeds` —— 五元组 → 35 个三元组（son-block 7 + output_pair×4 + output_triple×2），**排序后重算 state**（排序保证 m1 累加序一致）。
5. 主枚举循环（`solveForAi` 末段）—— 与 PreSolveForAi 的四重循环同构，只是目标层换成 Ai[14] 且外裹 mask 累加/撤销。**注意：当前源码在该循环前有 `return`（benchmark 截断），完整跑需注释**；`GenerateSQS16` 里还有每 A_14 打印 A14+m1 的调试输出，放开主循环前需注释。
6. `GenerateSQS16` —— 每层 z 填 13 项前缀（{z^1,14,15} + 6 来自 A_15 + 6 来自 A_14）并算 `m1Values[z]`；`assert(ordMatchings0_11[m1] != -1)`。
7. `ConcatAi` —— mark 前缀 13 项 → 遍历桶（**`for (auto &item : ...)` 引用遍历**，Bug 7）→ check → 填 22 项 → 递归 → 撤销。mask 累加/撤销严格成对。
8. `check` —— 高位遍历验证 `maskAi[r][s^r^(1<<z)]` + 低位 `mask[s]`（语义见 2.1 论证 A）。
9. `ConcatAi` 的 z==6 分支 —— 扫 A_7..A_15 全部三元组：`state ≤ 112` 判"全落 {0..6}"、`state|(1<<i)` 还原四元组去重计数 cnt、need = 全集^已覆盖、二分 `tuple0_6states` 找 `first == need` 的所有项（**while 遍历同 key 的全部解**）。

### 3.2 必须记住的编号空间约定（历史 bug 全源于此）

- **bit 值 ≠ 元素值**：state 的位 (1<<x) 与元素 x 互转用 `log_2[]` / `1<<x`，混用即 Bug 1；
- 虚拟编号 sed_map[0..13]（son_blocks 端点）+ sed_map[14]=15；son 虚拟边 (0,1),(2,3),… 无 arcMask bit；
- `reorder[z]`：{0..13}\{z,z^1} → 0..11 保序单射，使 m1 的"按小端升序串接大端"在 CPU（tmpMatching 数组）与 GPU（排序序直接累加）两种写法下一致；
- m1 是 12 元素完美匹配的 base-12 编码，**单射**（实测 10395 个无冲突，max=2,961,306 < 3e6 表界）；
- `1 << ord` 的 ord 可达 34（{0..6} 三元组序号）→ 必须 `1ull <<`（Bug 3/4）。

### 3.3 通过标准

给定一段修改（例如想加一个过滤条件），能立刻指出它应加在 searchTable/search4rows/search0_9/check/边界二分的哪一层、作用在哪个编号空间、以及会影响 CPU 与 GPU 的哪两处对应代码。

---

## 阶段四：GPU 版（`searchAi.cu`）与 CPU↔GPU 等价性核对

### 4.1 数据流

```
host: 读 A_15 → dA15(managed)；generate0_6Tuples
for z = 13..7: PreSolveForAi(z)
  ├ PRE_SOLVE(z)（host 折半数据：Matchings13/12、tuple11/10、sol0_9 排序）
  ├ 预生成 sedOf13/12/11/10（output_pair 产物，免 kernel 内反查 reverse_map）
  ├ cudaMemoryTransfer_preSolve(z)（只读表 → managed）
  ├ Generate_A15 kernel：pos=(i,j) 切分，枚举 (k,m,ans)，sol0_9 二分
  │   → Generate_seeds(device 版，按 (a,b) 键插入排序)
  │   → PreSaveForConcat：算 m1 入 AzPreEntity，atomicAdd 写 dans
  ├ cudaPreSolveAz：拷回 host → BuildAzCSR（按 mOrd 排序 + CSR）
  └ UploadAzDevice：压缩为 DevAzEntity(44B) 上传，释放 host 排序缓冲
PreSolveForAi(14)：只备 z=14 折半数据
searchSQS16：上传 sol0_9/tuple0_6states/tuples0_6 → RunSearch
  ├ ProgressReporter 线程（非阻塞 stream 轮询计数，每 100 万解上报）
  └ 每 OMP 线程 = 1 卡：threadStatePool + d_outBuf/d_outCnt
      SearchSQS16Kernel：pos 区间 → 重建 A_14 → 填 7 层前缀 + m1Values
        → ConcatAiIter(13)：栈式 7 层，check_linear，z=7 帧内联 z=6 边界
          → 命中即写 d_outBuf（140 ushort/解）
  拷回 → 分块写 sqs16_solutions.txt → 汇总统计
```

### 4.2 等价性核对清单（CPU 概念 → GPU 对应物）

| CPU | GPU | 核对要点 |
|---|---|---|
| `mask[s]` | check_linear 低位分支：扫 layer=z..15 有效条目 | z 层限 [0, suffixCnt[z])——check 在写后缀**之前**调用，扫描的是前缀 13 项（全含高位，与全低位 s 不可能相等，无害） |
| `maskAi[r][s']` | check_linear 高位分支：扫 pAiState[r*35..+34] 全 35 项 | r>z 的层都已完整（35 项）；22 项不含 14/15，r∈{z+1..13} |
| `ConcatAi` 递归 | `ConcatAiIter` 栈迭代（idx[7]/suffixCnt） | 回溯时 `pSuffixCnt=LEN` 即"撤销"；下钻时子层前缀已由 kernel 预填；耗尽分支的两次 LEN 赋值语义（当前层冗余、父层撤销） |
| `unordered_map` + vector 桶 | sol0_9 排序数组二分 + `while (s==query)` 遍历同 key | **必须遍历所有同 key 项**（历史事故：旧版只取第一个导致实体少 400 倍，见 full_output.log 时代日志） |
| `sort(tuple3)` (a,b,c) | Generate_seeds 按 (a<<8)|b 插入排序 | A_z 是 STS → (a,b) 对唯一 → (a,b) 键 = (a,b,c) 键 |
| `preSolveAz[z][ord]` vector | dAzFlat(DevAzEntity) + bucketStart/Size CSR | 空桶 size=0 不解引用（start=-1 不会被访问） |
| AzPreEntity 100B | DevAzEntity 44B（ushort sed[22]） | mOrd 排序后丢弃；state<2^16 |

### 4.3 GPU 特有设计要点

- **每线程状态**：Ai_state[16][35]（int state）+ suffixCnt[16] + idx[7]，按字段聚集放 threadStatePool（coalesced）；
- **pos 切分**：`pos = i*n10 + j`；`search range [offset, end] / total` 日志即该卡的 pos 闭区间；每 pos 内再展开 (k,m,ans) ≈ 3.2 个 A_14；**各 pos 工作量极不均**（实测单 A_14 树 1.5 千万~128 亿迭代）——负载均衡是未来优化点；
- **解存储**：每卡 `d_outBuf`（OUT_CAP=1000 万解 × 280B），slot ≥ OUT_CAP 只计数；结束打 WARNING；
- **进度上报**：`cudaStreamNonBlocking` 的小拷贝轮询（与 kernel 默认流无隐式同步）；线程在所有 cudaFree 完成后才停，无竞态。

### 4.4 已知限制 / 坑（2026-09-26 状态）

1. **多卡（GPUNUMS>1）不可用**：dAzFlat 系列是 device-0 私有 cudaMalloc 指针，其它卡解引用非法；启用前需改 managed 或每卡复制。
2. **解若超 OUT_CAP 只计数不存储**（WARNING 提示）；全量解总数按前 200 个 A_14 平均 ~2000 解/A_14 外推可能极大，先小范围试跑。
3. `sedOf13[3400]` 紧贴实测 n11=3329——**换输入（80 行中其它行）前必须重验**（`test/verify_bounds.cpp` 顺手就查）。
4. 边界 `ans_state[140]`/blkCnt 无上界防护（伪四元组时越界，正确性前提下不触发）；GPU 侧无 CPU 版的 `popcount==140-cnt` assert。
5. 全量规模 ≈ 35.7M A_14 × 平均 2.97 亿迭代 ≈ 10^16 次候选检查——**效率是当前主要矛盾**，见阶段五工具 3。

### 4.5 通过标准

能回答：① check_linear 里 `layer==z` 为什么用 suffixCnt 限位（stale 数据）；② Generate_A15 的 while 二分遍历若只取一个解会发生什么；③ DevAzEntity 为什么可以不带 mOrd；④ 进度线程为什么必须用非阻塞 stream。

---

## 阶段五：实证验证（`test/` 目录，全部可复现）

| 工具 | 命令（在 test/ 下） | 验证内容 | 关键预期 |
|---|---|---|---|
| `verify_bounds.cpp` | `g++ -O2 -std=c++17 verify_bounds.cpp && ./a.out`（秒级） | m1 单射性；n11/n10≤3400；search4rows 解数≤60 | injective: YES；n11=n10=3329；max sols=50 |
| `count_sol09.cpp` | 同上（秒级） | sol0_9 总条目/键分布 | 总条目 6,216,121（0.15 GB）；键 5,859,088；平均 1.1/键 |
| `test_tree_size.cpp` | `g++ -O2 -std=c++17 test_tree_size.cpp && ./a.out 200`（**约 20 分钟**，结果存 `tree_size_result.txt`） | 单 A_14 的 ConcatAi 搜索树规模（与原 CPU 逻辑完整对齐） | 每层实体 35,695,773；单 A_14 迭代 1550 万~128 亿、平均 2.97 亿 |
| `check.cpp`（根目录） | `g++ -O2 -std=c++17 check.cpp -o check`；`head -140 sqs16_solutions.txt > one.txt && ./check one.txt` | 端到端验证输出的解是合法 SQS(16) | OK |

**改代码后的最小回归**：跑 verify_bounds（容量）→ 小范围搜索（临时把 `TEST_POS_LIMIT` 设个值）比对解数与 CPU 版（可用 test_tree_size 的 sols 列作基准）→ check.cpp 验证解文件。

---

## 阶段六：运行手册

```bash
# 编译（Linux 服务器；Windows 本机 nvcc+MSVC 也过）
nvcc -m64 -Xcompiler -fopenmp -O3 searchAi.cu -o searchAicu

# 运行（NewS(2,3,15).txt 须在工作目录）
nohup ./searchAicu > run.log 2>&1 &
tail -f run.log        # 每 100 万解打印一次 [progress]

# 输出
#   sqs16_solutions.txt —— 每解 140 行、每行一个四元组（4 hex 字符）
#   结尾打印 Total SQS(16) found 与 captured 统计（<total 时有 WARNING）
```

- 正常日志关键行：`n11 = 3329` → `The value of t is 72` → `different legal s in [0-9] is 5859088` → 每层 `pre-solved: ~35.7M entities` + `CSR: total=..., max_bucket=...`（4 千~5 千）→ `search range [0, 11082240] / 11082241` → `[progress] ...` → `Total SQS(16) found: ...`。
- 显存账单（24 GB 卡）：预处理峰值 ~7.3 GB/轮（dans 临时）；搜索阶段 ≈ 11 GB（桶）+ 2.8 GB（解缓冲）+ ~0.4 GB（其余）≈ 14 GB。
- host 内存峰值 ≈ 单层 flatBuf 7.12 GB + 转换缓冲 1.6 GB（逐层释放）。

---

## 附录：关键数字速查

| 量 | 值 | 来源 |
|---|---|---|
| 每层 A_z 候选实体数 | 35,695,773（> NumsA14=35,595,773，dans 容量用 NumsA14*2=71.2M） | CPU/GPU 实测 |
| n11 = n10（行 13/12 匹配数） | 3329（GPU sedOf 容量 3400） | out.txt/verify |
| t（0..9 内合法三元组） | 72；search4rows 解数 ≤50 | verify_bounds |
| sol0_9 | 6,216,121 条 / 5,859,088 个键 | count_sol09 |
| tuple0_6states | 5596（含空集） | generate0_6Tuples |
| m1 哈希 | 10395 个匹配单射，max 2,961,306 | verify_bounds |
| 单 A_14 搜索树 | min 15.5M / avg 2.97 亿 / max 128 亿迭代；平均 ~2000 解 | test_tree_size |
| 全量规模 | ≈ 10^16 次候选检查 | 外推 |
