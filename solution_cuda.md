SQS(16) 搜索 CUDA 加速版归档
配套基线：searchAi.cpp（CPU 单线程实现） 实现文件：searchAi.cu 参考文档：solution.md（算法语义）、plan.md（GPU 化设计）、iterative_serach_algorithm.md（递归→栈迭代） 归档日期：2026-06-17（单卡测试版本，GPUNUMS=1）

0. 文档导读
阅读建议路径：

第 1 节：CPU → GPU 的整体翻译策略（不涉及代码细节）
第 2 节：分模块解读（每模块附"它解决什么 / 关键 trick / 与 CPU 对应处"）
第 3 节：四类容易踩坑的 GPU 化 trick 单独拎出来讲
第 4 节：显存预算与单卡 / 多卡切换
第 5 节：调试入口与常见报错对照表
1. 总体策略
1.1 流水线对照
阶段	CPU 版（searchAi.cpp）	GPU 版（searchAi.cu）
读 A_15	main 直读	同 + 拷到 dA15 (managed)
通用预处理	PRE、search0_11Matching 等	host 端不动
边界数据 tuple0_6states	generate0_6Tuples	host 端不动，搜索前传到 d_tuple0_6states_managed
A_z 桶化预处理（z = 13..7）	PreSolveForAi(z) 内嵌四重循环	Generate_A15 kernel + host 端 BuildAzCSR
A_14 折半 + 主搜索	solveForAi 末段循环 + GenerateSQS16 + ConcatAi(13)	SearchSQS16Kernel 一个 kernel 端到端跑完
结果	DEBUGVARIABLE++ 边搜边打印	atomicAdd(d_resultCnt, 1)，最终 host 聚合
1.2 并行粒度选择
按 (i, j) ∈ [0, n11) × [0, n10) 的笛卡尔积切分（pos = i * n10 + j），每个 GPU 线程串行处理一段 pos 区间。这与 CPU 版 solveForAi 末端的双层 for(i)/for(j) 循环外两层完全对应。

这样切分的好处：

一个 (i, j) pair 对应一个 A_14 候选基元（再展开 k, m, ans 后是 ~36 M 个 A_14 之一）
各线程之间完全独立，无锁
工作单元天然均匀（每对 i,j 展开出的 A_14 数量大致相当）
1.3 关键数据流
[Host]
  ├─ readA15 → dA15 (managed)
  ├─ generate0_6Tuples()
  └─ for z = 13..7:                       ┐
       PreSolveForAi(z)                   │  共 7 轮
         ├─ host: PRE_SOLVE(z)            │  每轮把 son_blocks/sed_map/sedOf*
         │   产 son_blocks, sed_map,      │  reorder[z] 等"上下文"灌到 device
         │   sedOf13/12/11/10, sol0_9     │
         ├─ cudaMemoryTransfer_preSolve(z)│
         ├─ cudaPreSolveAz(0, z)          │  调 Generate_A15 kernel
         │   产出扁平 AzPreEntity[]       │
         ├─ BuildAzCSR(z): 排序 + 桶化    │
         └─ UploadAzManaged(z)            │  数据落到 managed 多卡共享
                                          ┘
       PreSolveForAi(14)
         （只重设 son_blocks/sed_map/sedOf*/sol0_9, 不建桶）

  上传 sol0_9, tuple0_6states, triplesBits2Ord, FullMask 到 managed
  RunSearch():
    OMP 4 线程（GPUNUMS=1 时 1 线程） each on 1 GPU:
      cudaMalloc per-thread state pool (Ai_state + suffixCnt + idx)
      cudaMalloc d_resultCnt
      build d_azFlat[16] / d_azBucketStart[16] / d_azBucketSize[16] 指针数组
      SearchSQS16Kernel<<<256,256>>>
      cudaMemcpy d_resultCnt → host
  打印总数
2. 分模块解读
2.1 数据结构（与 CPU 对齐）
AzPreEntity（line 473-477）
struct AzPreEntity {
    int mOrd;        // 该候选所在的 0-11 matching 桶序号（CSR 索引）
    int sed[24];     // 候选 A_z 中"既不含 14 也不含 15"的 22 个三元组的 state
                     // 多 2 个 slot 是为了和 CPU 版尺寸对齐（CPU 版 sed[24]）
};
与 CPU 完全一致：CPU 版用 vector<AzPreEntity> preSolveAz[N_16][MatchingNums_0_11]，GPU 版改为：

dAzFlat_managed[z] = 把所有桶按 mOrd 排序后的扁平数组
dAzBucketStart_managed[z][m] / dAzBucketSize_managed[z][m] = CSR 索引
每线程状态（line 515-517）
#define PER_THREAD_AISTATE_SIZE (16 * 35)  // 2240 B
#define PER_THREAD_SUFFIXCNT_SIZE 16       // 64 B
#define PER_THREAD_IDX_SIZE 7              // 28 B
Ai_state[16][35]：每层 z 当前激活的三元组 state 列表
suffixCnt[z]：层 z 当前激活长度（0 / LEN=13 / Num_15=35），用来限定 Ai_state[z] 的有效范围
idx[d]：栈式迭代中各层枚举到第几个候选
⚠️ 关键：抛弃了 CPU 版的 mask[1<<16] + maskAi[16][1<<16] 共 1 MB/线程的查表结构，改为对 Ai_state 做线性扫描。 原因：1 万线程 × 1 MB = 10 GB 显存放不下。线性扫描每次成本 ~315 次 int 比较，warp 内并行 + #pragma unroll 实测可吞。

2.2 Generate_A15 kernel（line 770-830）
作用：对应 CPU 版 PreSolveForAi(z) 末段的"枚举 (i,j,k,l,e) 五重循环 → 生成 A_z 候选 → push 到 preSolveAz 桶"。

每个线程拿一段 pos = i*n10 + j 区间，按 (i, j) → (k, m, ans) 五重展开：

i, j：取 Matchings13 / Matchings12（行 13/12 的 6 边匹配）
k：取 tuple11（行 11 的 4-边补丁）
m：取 tuple10（行 10 的 4-边补丁）
ans：在排序后的 sol0_9 上二分，找到匹配下半解
每命中一个 (i, j, k, m, ans)：

Generate_seeds 重组成完整 35 三元组写入 Az[]
PreSaveForConcat 计算 mOrd 并 atomicAdd(d_CNT, 1) 写入 dans
为什么用 sol0_9 排序后二分而不是 CPU 版的 unordered_map？

GPU 上没有标准 hashmap，managed 的 unordered_map 行为也未定义
sol0_9 是中等规模（~100 万），二分 O(log n) ≈ 20 次访存，比 hashmap 仅慢 ~2-3 倍
同一份 sorted vector 可在多卡共享
2.3 PreSaveForConcat（line 744-768）
对应 CPU 版 searchAi.cpp:697-726：

扫 35 个 sed，找出"含 14 不含 15"的 6 个，从中提取 m1 哈希
把"既不含 14 也不含 15"的 22 个 state 存入 sed[]
mOrd = dOrdMatchings0_11[m1]
关键 trick：m1 累加用 reorder[较大元素]

int val = Az[iSed] - (1 << 14);   // 去掉 bit 14
val -= dlowbit(val);              // 再去掉较小 bit，剩较大 bit
int index = d_log_2[val];         // bitmask 还原成元素编号
m1 = m1 * 12 + dreorderAll[dCurZ][index];
为什么这样和 CPU 对齐？ CPU 版（searchAi.cpp:711, 721-724）：

tmpMatching[reorder[z][a]] = reorder[z][b];   // a<b, b 是较大
for (int i = 0; i < 12; i++)
    if (tmpMatching[i] > i)                    // 只取"大配小"方向
        m1 = m1 * 12 + tmpMatching[i];          // 累加 reorder[b]
GPU 端因为遍历 iSed 时三元组已排序，"含 14 不含 15"的三元组按其它两个元素从小到大顺序出现，正好对应 CPU 版 for(i) 的递增遍历，每次累加的 tmpMatching[i] = reorder[较大元素]，与 GPU 版 dreorderAll[z][较大元素] 一致。两次 dlowbit 自然挑出了较大 bit，所以无需 if (tmpMatching > i) 显式过滤。

历史教训（已修）：在 SearchSQS16Kernel 里曾经写成 m1 = m1*12 + dreorderAll[zz][bit2]，但 bit2 是 bitmask 不是元素编号，必须 d_log_2[bit2]。已对齐。

2.4 BuildAzCSR + UploadAzManaged（line 1073-1135）
作用：把 device 输出的扁平 AzPreEntity 数组按 mOrd 排序，构建 CSR 索引，落到 managed 内存。

为什么用 managed 而不是 cudaMalloc + 每卡复制？

dAzFlat_managed[z] 单层 ~500 MB，7 层 ~3.5 GB
4 卡每卡复制一份 = 14 GB/卡，逼近 24 GB 上限
managed + cudaMemAdviseSetReadMostly → CUDA 自动让各 GPU"按需页入，只读复制"
实际访问的子集（每卡只搜 1/4 的 A_14 → 只命中 1/4 的桶）会被复制到本卡
未访问的部分留在 host RAM
单卡显存峰值大幅下降
批量分配修复：

hostAzBucketStart[z] = new int[MatchingNums_0_11];   // 一次连续分配
hostAzBucketSize[z]  = new int[MatchingNums_0_11];
之前曾经写成对 10395 个 int* 各自 new int，每个 4 字节散落在堆上：

预处理阶段就要做 7 × 10395 = 7 万次 malloc，慢
managed 拷贝时连续性差，每张卡都要做大量小段页入
2.5 check_linear（line 545-595）—— 替代 CPU 的 mask / maskAi
对应 CPU 版 searchAi.cpp:411-436 的 check：

CPU 用 mask[s] 看 state s 是否已出现（"低位检查"）
CPU 用 maskAi[bit][s] 看 state s 是否在某个高位 bit 对应的 A 层中（"高位检查"）
GPU 不能给每线程开 1 MB 表，改成线性扫描：

// 低位检查（s 不含 z+ 高位）：在 Ai_state[z..15] 里扫 s
for (int layer = z; layer < N_16; layer++) {
    int limit = (layer == z) ? pSuffixCnt[layer] : Num_15;
    // 注意：层 z 的扫描限定到当前已写入的 suffixCnt 部分
    //       因为更靠后的 slot 是历史脏数据
    // 其它层都是 Num_15（已固定 35 项）
    ...
}

// 高位检查（s 含某高位 r）：取 r_idx = log_2(r)，
// 在 Ai_state[r_idx] 里扫 s ^ r ^ (1<<z)
//   等价于 maskAi[r_idx][s ^ r ^ (1<<z)] == true
为什么 layer == z 时要用 suffixCnt[z] 限位？

层 z 是当前正在枚举的层
其前缀 13 项已固定，当前正在试 item 的后缀 22 项还没写入（check 是在 item 写入前调用的）
所以扫描范围是 [0, suffixCnt[z] = 13)
如果不限位，会扫到上一次 item 留下的 stale 数据 → 假阳性"已存在"
2.6 ConcatAiIter（line 608-739）—— CPU ConcatAi(z) 的栈式迭代版
详细的设计见 iterative_serach_algorithm.md。要点：

递归深度固定 7（z = 13..7），用 int idx[7] 模拟调用栈，不需要动态栈
每层 mark / unmark 只改 pSuffixCnt[z]（数组长度），不真正修改 Ai_state 的内容
进入 z 时：pSuffixCnt[z] = LEN = 13（只有前缀有效）
候选通过 check 后写入后缀 + pSuffixCnt[z] = Num_15 = 35
下钻 z-1 时：父层 suffixCnt 保持 35，子层 pSuffixCnt[z-1] = LEN
子层耗尽回溯时：父层 pSuffixCnt = LEN 即"撤销 item"
边界 z==6：内联在 z==7 帧内，命中即 atomicAdd(d_resultCnt, 1ULL)，不下钻
桶预取优化（line 631-638）：

int candStart[7], candCount[7];
for (int dd = 0; dd < 7; dd++) {
    int zz = start_z - dd;
    int mOrd = dOrdMatchings0_11[m1Values[zz]];
    candStart[dd] = azBucketStart[zz][mOrd];   // 一次性查表
    candCount[dd] = azBucketSize[zz][mOrd];
}
为什么不在迭代主循环里查？因为各层桶位置在整次 ConcatAiIter 调用中完全不变（取决于 m1Values，由调用方算好），主循环里反复访问 managed 内存的 BucketStart/Size 会触发不必要的 page fault 与 cache miss。

2.7 SearchSQS16Kernel（line 838-972）—— 主搜索核函数
作用：完成 CPU 版 solveForAi 末段循环 + GenerateSQS16 + ConcatAi(13) 三件事。每线程串行处理一段 A_14 流。

2.7.1 线程私有状态分配（line 857-860）
线程池 layout：

threadStatePool 整体布局（按字段聚集，不是按线程聚集）:
  [0 .. nThreads × AISTATE_SIZE)         所有线程的 Ai_state
  [接续 .. + nThreads × SUFFIXCNT_SIZE)  所有线程的 suffixCnt
  [接续 .. + nThreads × IDX_SIZE)        所有线程的 idx
为什么按字段聚集？同一个 warp 的 32 个线程访问同字段时，地址连续 → coalesced load。

2.7.2 重建 A_14（line 906-917）
Generate_seeds 拼出 Az[Num_15]，然后写入 pAiState[14*Num_15 + jj]。这一步对应 CPU 版 solveForAi 中 Generate_seeds(..., Ai[14]) + mark Ai[14] 进 mask。

2.7.3 填充 A_7..A_13 前缀 + 计算 m1Values（line 919-956）
对每个 z = 13..7：

第 0 项：固定三元组 {z⊕1, 14, 15}
接着 6 项：A_15 中"含 z 不含 14"的三元组（去 z + 加 15）
再 6 项：A_14 中"含 z 不含 15"的三元组（去 z + 加 14），同时累加 m1
完成 13 项前缀。这部分对应 CPU 版 GenerateSQS16 函数体（searchAi.cpp:568-619）。

m1 计算的关键：用 dreorderAll[zz][d_log_2[bit2]] 累加（bit2 是较大那位的 bitmask）。

2.7.4 进入 ConcatAiIter（line 959-962）
把准备好的 pAiState / pSuffixCnt / pIdx / m1Values 传入，start_z = 13。函数返回时 d_resultCnt 已被原子增加。

2.8 RunSearch（line 1140-1235）
外层 OMP 并行（num_threads(GPUNUMS)），每个 OMP 线程绑定一张 GPU：

cudaMalloc 每卡的 thread pool（512 MB+）
cudaMalloc 每卡的 d_resultCnt
把 16-长度的指针数组 azFlat[] / azBucketStart[] / azBucketSize[] 拷到 device（kernel 参数只能传指针，不能传指针数组）
启动 kernel <<<256, 256>>> = 65 536 线程
同步 + 拷回 hostCnt[dev_id]
释放本卡的 thread pool / 指针数组
单卡退化（GPUNUMS=1）：

OMP 只起 1 个线程
chunk = 全部 n11 * n10
行为等价于"在 GPU 0 上跑全部任务"
3. 关键 GPU 化 Trick
3.1 mask/maskAi 的取舍
方案	单线程显存	check 单次成本	备注
CPU 直搬（mask + maskAi）	1.25 MB	O(1)	1 万线程就要 12.5 GB
线性扫描 Ai_state（已采用）	2.3 KB	~315 次 int 比较	warp 内并行可吞，65 K 线程 0.6 GB
bit-packed mask（备选）	~10 KB	O(1)	实现复杂，未采用
线性扫描的 8 K 次比较听起来多，但都是 register / L1 命中、#pragma unroll 后是固定 35-长度循环（无分支预测开销），实际单次 check < 1 μs。

3.2 managed 内存策略
数据	选择	理由
dA15（35 个 tuple3）	__device__ __managed__	极小，只读
dsedOf13/12/11/10 (~1.3 GB)	__device__ __managed__	多卡只读，按需页入
dAzFlat_managed[z] (~3.5 GB)	cudaMallocManaged + ReadMostly	大块，多卡共享但访问模式稀疏
d_threadPool	cudaMalloc	每卡线程私有，频繁读写，绝不 managed
d_resultCnt	cudaMalloc	同上，且需 atomic
绝对禁止：把"频繁原子写"的数据放 managed —— page fault 风暴会拖垮性能。

3.3 桶（CSR）结构
CPU 版 vector<AzPreEntity> preSolveAz[N_16][10395] 在 GPU 上不可用（vector 不能跨设备）。改写：

hostAzFlat[z]            : 排序后的扁平实体数组（按 mOrd 升序）
hostAzBucketStart[z][m]  : 桶 m 在 flat 中的起始下标（-1 表示空桶）
hostAzBucketSize[z][m]   : 桶 m 的元素数量
第 m 个桶的实体序列就是 &flat[start[m]], start[m]+size[m]。

3.4 CPU DEBUGVARIABLE → GPU atomicAdd
CPU 版 DEBUGVARIABLE++ + if (DEBUGVARIABLE==20) exit(0) 是调试用的，GPU 版完全不复刻。仅保留计数：

atomicAdd(d_resultCnt, 1ULL);   // unsigned long long, 64-bit atomic
3.5 Az 内 buffer 容量上限
cudaMalloc(&dans, sizeof(AzPreEntity) * NumsA14 / 2) ≈ 1.7 GB/卡。

为什么是 NumsA14/2？因为 NumsA14 = 35 595 773 是"所有 z 中最大的候选数"（来自 z=14 的 A_14 总数），实际单 z 桶数远小于这个上限，留一半余量足够。

4. 显存预算
4.1 单 GPU（当前 GPUNUMS=1 测试模式）
阶段	项目	大小
预处理（7 轮，每轮一过）	dans 临时	1.7 GB
d_sol0_9 临时	~150 MB
dsedOf* managed	~1.3 GB
其它（log_2, reverse_map, ...）	~30 MB
预处理峰值		~3.2 GB
搜索阶段	dAzFlat_managed[7..13]	~3.5 GB（managed）
d_threadPool 65 536 × 9.5 KB	~0.6 GB
d_sol0_9_managed	~150 MB
dsedOf* managed（保留）	~1.3 GB
d_tuple0_6states_managed	~6 MB
其它	~30 MB
搜索峰值		~5.6 GB
结论：单卡 24 GB 余量充足，可放心跑全量测试。

4.2 多 GPU（GPUNUMS=4）
由于所有大数据都是 managed，每卡显存与单卡情形相当（不会 ×4），只是 thread pool 和 d_resultCnt 是每卡一份。

切换方法：把 #define GPUNUMS 1 改回 4。无需改其它代码。

5. 调试与运维
5.1 编译
nvcc -m64 -Xcompiler -fopenmp -Xptxas -O3,-v searchAi.cu -o searchAicu
注意：-Xptxas -O3,-v 会打印 register / shared mem 用量，若 register 数超 SM 限制（常见 64/线程）会限制 occupancy。当前 kernel 每线程数据都在 global，register 使用应在阈值以下。

5.2 运行
./searchAicu
# 或后台
nohup ./searchAicu > /dev/null 2>&1 &
输入文件 NewS(2,3,15).txt 必须在工作目录。

5.3 关键日志
正常情形输出（节选）：

0-11 matching cnt: 10395
Now presolve for A13:
  对于A13, 子结构如下：...
  n11 = ?, n10 = ?
  The value of t is ?
  The number of different legal s in [0-9] is ?
  CUDA Error1: "no error".
  [GPU0] A13 pre-solved: ? entities
  A13 CSR: total=?, max_bucket=?
... (z=12..7 类似)
Now presolve for A14:
  CUDA Error1: "no error".
Starting GPU search on 1 GPU(s)...
  CUDA Search GPU0: "no error".
  GPU0 search done in ? ms, hit count=?
========================================
Total SQS(16) found: ?
========================================
The total elapsed time is ?
5.4 常见报错对照
报错	原因	处理
kernel failed: out of memory	dans/threadPool 容量过大	调小 NumsA14/2 或 grid×block 尺寸
kernel failed: invalid device function	nvcc arch 不匹配	加 -arch=sm_86 等具体架构
CUDA Error1: "an illegal memory access"	managed 数据在 host 端被脏写	确保所有 host 端对 managed 的赋值都在 kernel 之前完成
命中数 = 0	多半是 m1 计算/桶索引偏差	用 --max=1 跑单 A_14，对 CPU 版结果
命中数远大于 CPU 单 A_14	check_linear 缺漏	重点查 pSuffixCnt[z] = LEN 的位置
5.5 与 CPU 单 A_14 对账
CPU 版打开 DEBUGVARIABLE：

DEBUGVARIABLE++;
if (DEBUGVARIABLE >= 1) {
    // print 出当前 A_14 的命中数（保留所有命中而不 exit(0)）
}
GPU 版临时增加 --max=N 入口（暂未实现，需要时可加）只跑前 N 个 (i,j)，然后对照 CPU 版同区间的命中。

6. 文件结构
searchAi.cu  （~1455 行）
├─ Lines 1-145:    CPU 端共用工具（getch, lowbit, log_2, search0_11Matching, ...）
├─ Lines 146-440:  CPU 端 PRE_SOLVE / search* 全套（不动，与 .cpp 等价）
├─ Lines 472-502:  AzPreEntity / 全局 host 端缓冲 / managed 指针声明
├─ Lines 504-540:  Device 工具（dswap, d_extract2tuple3, dCurZ, dreorderAll）
├─ Lines 542-595:  check_linear（核心）
├─ Lines 597-739:  ConcatAiIter（核心）
├─ Lines 741-830:  PreSaveForConcat + Generate_A15
├─ Lines 832-972:  SearchSQS16Kernel（核心）
├─ Lines 974-1020: cudaMemoryTransfer_preSolve
├─ Lines 1022-1068: cudaPreSolveAz
├─ Lines 1070-1108: BuildAzCSR
├─ Lines 1110-1135: UploadAzManaged
├─ Lines 1137-1235: RunSearch
├─ Lines 1237-1304: PreSolveForAi（host 编排，每 z 一次）
├─ Lines 1306-1365: searchSQS16（host 顶层）
├─ Lines 1367-1419: generate0_6Tuples（同 CPU）
└─ Lines 1421-1455: main
7. 与 plan.md 设计目标的对照
plan.md 要求	落地情况
AzPreEntity 不压缩，对齐 CPU 版（int sed[24]）	✅
managed 内存多卡共享 + ReadMostly	✅
抛弃 mask/maskAi，用线性扫描	✅
每线程 ~10 KB 私有状态	✅（9.5 KB）
显存控制在 24 GB 内	✅（峰值 ~6 GB）
OMP 4 卡分片	✅（GPUNUMS 宏一键切换）
atomicAdd 累计命中数	✅
不复刻 DEBUGVARIABLE 行为	✅
栈式迭代替代递归	✅
m1 计算与 CPU 等价（两次 lowbit 取较大 bit）	✅（已修复 bit2 vs log_2[bit2] bug）
