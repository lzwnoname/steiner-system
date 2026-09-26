#include <stdio.h>
#include <stdlib.h>
#include <iostream>
#include <algorithm>
#include <string>
#include <string.h>
#include <cmath>
#include <vector>
#include <set>
#include <assert.h>
#include <unordered_map>
#include <queue>
#include <bitset>
#include <time.h>
#include <omp.h>
#include <cuda_runtime.h>
#include <chrono>
#include <thread>
#include <atomic>
// 考虑搜索合法的(A16, A15) pair
#define rep(i, a, b) for (int i = (a); i <= (b); ++i)
#define per(i, a, b) for (int i = (a); i >= (b); --i)
#define pb push_back
#define mp make_pair
#define all(x) x.begin(), x.end()
#define GPUNUMS 1
#define TEST_POS_LIMIT 0       // 调试用：限制搜索范围，0 则全量
#define OUT_CAP 10000000ULL    // 每卡最多存储的 SQS(16) 解数（280 B/解；超出的只计数不存储）

using namespace std;
typedef long long ll;
typedef unsigned long long ull;
typedef pair<int, int> Pii;

const int N_16 = 16;
const int N_15 = 15;
const int Num_16 = N_16 * (N_16 - 1) * (N_16 - 2) / 6 / 4;
const int Num_15 = N_15 * (N_15 - 1) / 2 / 3;
const int T_15 = 80;

struct tuple3
{
	int a, b, c;
	int state;

	tuple3() {}

	__device__ __host__ tuple3(int a, int b, int c)
	{ // 构造函数这一块需要在device function内重新定义
		this->a = a;
		this->b = b;
		this->c = c;
		this->state = (1 << a) + (1 << b) + (1 << c);
	}

	bool operator<(const tuple3 &x) const
	{
		return a == x.a ? (b == x.b ? (c < x.c) : (b < x.b)) : a < x.a;
	}

} Ai[N_16][Num_15];

__device__ __managed__ tuple3 dA15[Num_15];

int getch()
{
	while (true)
	{
		char ch;
		cin >> ch;
		if (ch >= '0' && ch <= '9')
			return ch - '0';
		if (ch >= 'A' && ch <= 'Z')
			return ch - 'A' + 10;
	}
}

int ch2int(char ch)
{
	if (ch >= '0' && ch <= '9')
		return ch - '0';
	else
		return ch - 'A' + 10;
}

char int2ch(int x)
{
	return x < 10 ? x + '0' : x - 10 + 'A';
}

const int maxn = 200000;
const int maxnum0_9 = 6.5e6;

int matching[N_16];
ull arcMask[N_16][N_16];
int n10, n11;

int m;
ull Matchings12[maxn], Matchings13[maxn];
int matching13[maxn][2];
int matching12[maxn][2];

__device__ __managed__ ull dMatchings12[maxn], dMatchings13[maxn];
__device__ __managed__ int dmatching13[maxn][2];
__device__ __managed__ int dmatching12[maxn][2];

int used[N_16];
pair<ull, ull> tuple11[16][16][105];
pair<ull, ull> tuple10[16][16][105];

__device__ __managed__ pair<ull, ull> dtuple11[16][16][105];
__device__ __managed__ pair<ull, ull> dtuple10[16][16][105];

ull tuple0_9[120];
int element0_9[120][3];

Pii reverse_map[4][1 << 16];
unordered_map<ull, int> id_map;

template <typename T>
__device__ inline T dlowbit(T x)
{
	return x & -x;
}

template <typename T>
inline T lowbit(T x)
{
	return x & -x;
}

int cnt;

int a[9];

int mask[1 << N_16];
bool maskAi[N_16][1 << N_16];
int sed_map[N_16];

// 避免 pair<ull,ull> 在 device 侧对齐不确定，用纯 struct
struct UllPair { ull first; ull second; };

struct Sol
{
	ull s;
	UllPair sol;

	bool operator<(const Sol &x) const   // const 至关重要：std::sort 在 const 上下文调用
	{
		return s < x.s;
	}
};

vector<Sol> sol0_9;

void search0_9(int t, int i, ull s)
{
	if (i == 8)
	{
		ull high_bit = 0, low_bit = 0;
		if (!id_map.count(s))
			id_map[s] = cnt++;
		for (int j = 0; j < 8; j++)
			if (a[j] < (t >> 1))
				low_bit |= 1ull << a[j];
			else
				high_bit |= 1ull << (a[j] - (t >> 1));
		Sol sv;
		sv.s = s;
		sv.sol.first = high_bit;
		sv.sol.second = low_bit;
		sol0_9.pb(sv);
		return;
	}
	int las = i == 0 ? -1 : a[i - 1];
	for (int j = las + 1; j < t; j++)
		if ((tuple0_9[j] & s) == 0)
		{
			a[i] = j;
			search0_9(t, i + 1, s + tuple0_9[j]);
			a[i] = -1;
		}
}

int sol_num;

void search4rows(int x, int i, ull s_all, ull s, pair<ull, ull> tup[105])
{
	if (i == 4)
	{
		tup[sol_num++] = mp(s_all, s);
		return;
	}

	int j = 0;
	while (j < 10 && used[j])
		j++;
	used[j] = true;
	for (int k = j + 1; k < 10; k++)
		if (!used[k] && !(k == j + 1 && (j & 1) == 0) && !mask[(1 << sed_map[k]) + (1 << sed_map[j]) + (1 << sed_map[x])])
		{
			used[k] = true;
			search4rows(x, i + 1, s_all + arcMask[j][k] + arcMask[j][x] + arcMask[k][x], s + arcMask[j][k], tup);
			used[k] = false;
		}
	used[j] = false;
}

void searchTable(int i, ull s, int g)
{
	if (i == 6)
	{
		if (g == 11)
		{
			matching13[n11][0] = matching[11];
			matching13[n11][1] = matching[10];
			Matchings13[n11++] = s;
		}
		else
		{
			matching12[n10][0] = matching[11];
			matching12[n10][1] = matching[10];
			Matchings12[n10++] = s;
		}
		return;
	}
	int j = -1, v = g == 11 ? (1 << sed_map[13]) : (1 << sed_map[12]);
	do
	{
		j++;
	} while (j < 12 && matching[j] != -1);
	for (int k = j + 1; k < 12; k++)
	{
		if (k == j + 1 && ((j & 1) == 0))
			continue;
		if (matching[k] == -1 && !mask[(1 << sed_map[k]) + (1 << sed_map[j]) + v])
		{
			matching[j] = k;
			matching[k] = j;
			searchTable(i + 1, s + arcMask[j][k], g);
			matching[j] = matching[k] = -1;
		}
	}
}

int log_2[1 << 21];
int len;

const int GPU_MAX_NUM0_9 = 2e7;

Pii son_blocks[7];

inline int Val2PairId(ull &save_c, ull &c)
{
	if (c < (1ull << 16ull))
	{
		save_c = c;
		return 0;
	}
	else if (c < (1ull << 32ull))
	{
		save_c = c >> 16ull;
		return 1;
	}
	else if (c < (1ull << 48ull))
	{
		save_c = c >> 32ull;
		return 2;
	}
	else
	{
		save_c = c >> 48ull;
		return 3;
	}
}

__device__ __managed__ int d_sed_map[N_16];
__device__ __managed__ Pii d_reverse_map[4][1 << N_16];

__device__ inline int dMax2(int a, int b)
{
	return a > b ? a : b;
}

__device__ inline int dMin2(int a, int b)
{
	return a > b ? b : a;
}

__device__ inline int dMax3(int a, int b, int c)
{
	return dMax2(a, dMax2(b, c));
}

__device__ inline int dMin3(int a, int b, int c)
{
	return dMin2(a, dMin2(b, c));
}

void output_pair(ull s, int las, tuple3 sed[])
{
	int len = 0;
	while (s)
	{
		ull x = lowbit(s), save_c = 0;
		int id = Val2PairId(save_c, x);
		int tmp[3] = {sed_map[reverse_map[id][save_c].first], sed_map[reverse_map[id][save_c].second], sed_map[las]};
		sort(tmp, tmp + 3);
		sed[len++] = tuple3{tmp[0], tmp[1], tmp[2]};
		s -= x;
	}
}

__device__ __managed__ int d_element0_9[120][3];
__device__ __managed__ int d_log_2[1 << 21];

__device__ void output_triple(ull s, int t, bool high, int d_sed[], int &d_len)
{
	int offset = high ? t / 2 : 0;
	while (s)
	{
		ull x = dlowbit(s);
		if (x >= (1ull << (t >> 1ull)))
			assert("Wrong!");
		int id = x < (1ull << 21) ? d_log_2[x] : d_log_2[x >> 21ull] + 21;
		int tmp[3] = {d_sed_map[d_element0_9[id + offset][0]], d_sed_map[d_element0_9[id + offset][1]],
					  d_sed_map[d_element0_9[id + offset][2]]};
		d_sed[d_len++] = (1 << tmp[0]) + (1 << tmp[1]) + (1 << tmp[2]);
		s -= x;
	}
}

__device__ __managed__ int d_t;

__device__ __managed__ Pii d_son_blocks[7];

__device__ inline void Generate_seeds(tuple3 sedOf13[], tuple3 sedOf12[], tuple3 sedOf11[], tuple3 sedOf10[],
									  UllPair e, int dsed[])
{

	int len = 0; // 初始化len=0，从0开始写
	rep(i, 0, 6)
		dsed[len++] = (1 << d_son_blocks[i].first) + (1 << d_son_blocks[i].second) + (1 << 15); // 前7个固定

	// 利用预处理得到的block避免重复计算
	rep(i, 0, 5) dsed[len++] = sedOf13[i].state;
	rep(i, 0, 5) dsed[len++] = sedOf12[i].state;
	rep(i, 0, 3) dsed[len++] = sedOf11[i].state;
	rep(i, 0, 3) dsed[len++] = sedOf10[i].state;

	ull high_bit = e.first, low_bit = e.second;
	output_triple(low_bit, d_t, false, dsed, len);
	output_triple(high_bit, d_t, true, dsed, len);

	// 对齐 CPU：排序后重算 state（用临时键值排序，35 元素插入排序即可）
	{
		int keys[35], vals[35];
		for (int t = 0; t < len; t++)
		{
			int st = dsed[t];
			int ba = dlowbit(st);
			int a = d_log_2[ba]; st -= ba;
			int bb = dlowbit(st);
			int b = d_log_2[bb];
			keys[t] = (a << 8) | b;  // sort key: (a,b)，不需 c
			vals[t] = dsed[t];       // 保存原 state
		}
		for (int i = 1; i < len; i++)
		{
			int k = keys[i], v = vals[i];
			int j = i - 1;
			while (j >= 0 && keys[j] > k) { keys[j+1] = keys[j]; vals[j+1] = vals[j]; j--; }
			keys[j+1] = k; vals[j+1] = v;
		}
		for (int t = 0; t < len; t++)
			dsed[t] = vals[t];
	}
}

ull c, full_mask;

int t_global;

inline void Pair2Bit(int j, int k, ull &c, ull &full_mask)
{
	arcMask[j][k] = c; // 给每个无序二元组设定二进制bit压位
	ull save_c = c;
	int id = 0;
	if (c < (1ull << 16ull)) // 根据二进制位反推得到哈希表下标，这里对64位分成4段
		save_c = c, id = 0;
	else if (c < (1ull << 32ull))
		save_c = c >> 16ull, id = 1;
	else if (c < (1ull << 48ull))
		save_c = c >> 32ull, id = 2;
	else
		save_c = c >> 48ull, id = 3;
	reverse_map[id][save_c] = mp(j, k); // 反向记录每个二进制位对应的二元组
	full_mask |= c;						// 算出所有二元组都存在时的二进制数
	c += c;
}

inline void PRE()
{
	c = 1, full_mask = 0;
	// 我们在这里要求10和11的配对二进制位放在高位
	for (int j = 0; j < 12; j++)
		for (int k = j + 1; k < 12; k++)
		{
			if (k == j + 1 && (j & 1) == 0)
				continue;
			Pair2Bit(j, k, c, full_mask);
		}

	for (int i = 2; i < (1 << 21); i++)
		log_2[i] = log_2[i >> 1] + 1;
}

inline void PRE_SOLVE(int z)
{
	sed_map[14] = 15; // 14映射成15，因为最后会把15加上
	rep(i, 0, len - 1)
	{
		sed_map[i << 1] = son_blocks[i].first;
		sed_map[i << 1 | 1] = son_blocks[i].second;
		// cout << son_blocks[i].first << ' ' << son_blocks[i].second << endl;
	}

	memset(matching, -1, sizeof(matching));
	memset(matching12, -1, sizeof(matching12));
	memset(matching13, -1, sizeof(matching13));
	memset(Matchings12, -1, sizeof(Matchings12));
	memset(Matchings13, -1, sizeof(Matchings13));

	n10 = n11 = 0;
	searchTable(0, 0, 11);
	searchTable(0, 0, 10);
	printf("n11 = %d, n10 = %d\n", n11, n10);

	memset(tuple11, 0, sizeof(tuple11));
	memset(tuple10, 0, sizeof(tuple10));
	for (int i = 0; i < 10; i++)
		for (int j = i + 1; j < 10; j++)
		{
			used[i] = used[j] = true;
			sol_num = 0;
			search4rows(11, 0, 0, 0, tuple11[i][j]);
			sol_num = 0;
			search4rows(10, 0, 0, 0, tuple10[i][j]);
			used[i] = used[j] = false;
		}

	t_global = 0;
	for (int i = 0; i < 8; i++)
		for (int j = i + 1; j < 9; j++)
			for (int k = j + 1; k < 10; k++)
				if (arcMask[i][j] > 0 && arcMask[i][k] > 0 && arcMask[j][k] > 0 && !mask[(1 << sed_map[i]) + (1 << sed_map[j]) + (1 << sed_map[k])])
				{
					tuple0_9[t_global] = arcMask[i][j] + arcMask[i][k] + arcMask[j][k];
					element0_9[t_global][0] = i;
					element0_9[t_global][1] = j;
					element0_9[t_global][2] = k;
					t_global++;
				}

	printf("The value of t is %d\n", t_global);
	id_map.clear();
	sol0_9.clear();
	sol0_9.shrink_to_fit();
	cnt = 0;
	search0_9(t_global, 0, 0);
	printf("The number of different legal s in [0-9] is %d\n", cnt);
}

const int MatchingNums_0_11 = 10395;
const int Hash0_11Num = 3e6;
int matchings0_11[MatchingNums_0_11][N_16];
int ordMatchings0_11[Hash0_11Num]; // 哈希范围其实到12的6次方<3e6
int matchings0_11Cnt;

void search0_11Matching(int dep, ull m)
{
	if (dep == 6)
	{
		for (int i = 0; i < 12; i++)
			matchings0_11[matchings0_11Cnt][i] = matching[i];
		ordMatchings0_11[m] = matchings0_11Cnt;
		matchings0_11Cnt++;
		return ;
	}
	int j = -1;
	do
	{
		j++;
	} while (j < 12 && matching[j] != -1);
	for (int i = j + 1; i < 12; i++)
		if (matching[i] == -1)
		{
			matching[j] = i;
			matching[i] = j;
			search0_11Matching(dep + 1, m * 12 + i);
			matching[i] = matching[j] = -1;
		}
}

const int NumsA14 = 35595773;
struct AzPreEntity
{
    int mOrd;
    int sed[24];
};
// device 端压缩实体：桶数据按 mOrd 排序后 mOrd 不再需要；sed 恰 22 项且 state < 2^16，
// 用 unsigned short 存储。100 B → 44 B，7 层桶显存约 25 GB → 11 GB。
struct DevAzEntity
{
    unsigned short sed[22];
};
vector<AzPreEntity> preSolveAz[N_16][MatchingNums_0_11];
int reorder[N_16][N_16], invReorder[N_16][N_16];

// ======== preSolveAz 持久化：host 暂存 + device 显存 ========
AzPreEntity *hostAzFlat[16];   // 每层排序用 host 缓冲（上传后即释放）
int *hostAzBucketStart[16];
int *hostAzBucketSize[16];
int hostAzTotalCnt[16];
DevAzEntity *dAzFlat[16];      // device 端压缩后的桶数据
int *dAzBucketStart[16];
int *dAzBucketSize[16];

// ======== sol0_9：managed 多卡共享 ========
__managed__ Sol *d_sol0_9_managed;
__managed__ int d_sol0_9_size_saved;

// ======== tuple0_6states：managed 多卡共享 ========
__managed__ pair<ull, ull> *d_tuple0_6states_managed;
__managed__ int d_t0_6sz_saved;

// ======== SQS(16) 解存储：每卡一份 device 输出缓冲 ========
// 每解 140 个四元组，每四元组 16-bit 元素掩码（4 bits 置位），共 280 B；
// 搜索结束后分块拷回 host，统一写入 sqs16_solutions.txt（每行一个四元组，4 个 hex 字符）。

// ============================================================
// Device: extract2tuple3 / check_linear / ConcatAiIter
// ============================================================

__device__ __managed__ int dOrdMatchings0_11[Hash0_11Num];

// ============================================================
// 每线程状态结构：替代 mask/maskAi，用 Ai_state 线性扫描
// Ai_state[16][35] 存 int state 值
// suffixCnt[16] 标记每层"已激活"的后缀条数（prefix 固定 13）
// ============================================================
#define PER_THREAD_AISTATE_SIZE (16 * 35) // 560 int = 2240 B
#define PER_THREAD_SUFFIXCNT_SIZE 16	   // 16 int = 64 B
#define PER_THREAD_IDX_SIZE 7			   // 7 int = 28 B

tuple3 sedOf13[3400][Num_15], sedOf12[3400][Num_15], sedOf11[N_16][N_16][70][Num_15], sedOf10[N_16][N_16][70][Num_15];
__device__ __managed__ tuple3 dsedOf13[3400][Num_15], dsedOf12[3400][Num_15], dsedOf11[N_16][N_16][70][Num_15], dsedOf10[N_16][N_16][70][Num_15];


template<typename T>
__device__ inline void dswap(T &a, T &b)
{
	a ^= b;
	b ^= a;
	a ^= b;
}

__device__ __managed__ int dreorderAll[16][N_16];
__device__ __managed__ int dCurZ;

__device__ inline tuple3 d_extract2tuple3(int val)
{
	int a_bit = dlowbit(val);
	int b_bit = dlowbit(val ^ a_bit);
	int c_bit = dlowbit(val ^ a_bit ^ b_bit);
	return tuple3(d_log_2[a_bit], d_log_2[b_bit], d_log_2[c_bit]);
}

// check_linear：对 Ai_state 做线性扫描替代 mask/maskAi
// pAiState[16*35]: 扁平 int 数组，pAiState[layer*35 + idx]
// pSuffixCnt[16]: 当前每层"有效条目数"，prefix 固定 13
__device__ inline bool check_linear(const int *__restrict__ pAiState,
									const int *__restrict__ pSuffixCnt,
									int z, const unsigned short *__restrict__ sed, int size)
{
	int highBitsMask = ((1 << N_16) - 1) ^ ((1 << (z + 1)) - 1);
	for (int iSed = 0; iSed < size; iSed++)
	{
		int s = sed[iSed];
		int highVal = s & highBitsMask;
		if (highVal)
		{
			// 高位检查：对每个高位 bit r，查 maskAi[log_2[r]]
			while (highVal)
			{
				int r = dlowbit(highVal);
				int r_idx = d_log_2[r];
				int query = s ^ r ^ (1 << z);
				bool found = false;
				const int *layerStart = pAiState + r_idx * Num_15;
#pragma unroll
				for (int j = 0; j < Num_15; j++)
				{
					if (layerStart[j] == query)
					{
						found = true;
						break;
					}
				}
				if (!found)
					return false;
				highVal ^= r;
			}
		}
		else
		{
			// 低位检查：mask[s] —— 扫描 >=z 层的有效条目
			for (int layer = z; layer < N_16; layer++)
			{
				int limit = (layer == z) ? pSuffixCnt[layer] : Num_15;
				const int *layerStart = pAiState + layer * Num_15;
#pragma unroll
				for (int j = 0; j < limit; j++)
				{
					if (layerStart[j] == s)
						return false;
				}
			}
		}
	}
	return true;
}

// 0-6 边界数据：managed 多卡共享（实际定义，不是 forward declaration）
__device__ __managed__ int d_triplesBits2Ord_dev[1 << 8];
__device__ __managed__ ull d_tuples0_6FullMask_dev;
__device__ __managed__ int d_tuples0_6_dev[35][4];   // {0..6} 内 35 个四元组，展开 low_state 存解用

// ============================================================
// ConcatAiIter：栈式迭代搜索（用 Ai_state 线性扫描，对齐 CPU 版 ConcatAi）
//   azFlat[16]         : 各 z 层压缩实体数组（device 显存，z=7..13 有数据）
//   azBucketStart[16]  : 各 z 层桶首偏移（按 mOrd 索引，device 显存）
//   azBucketSize[16]   : 各 z 层桶大小（按 mOrd 索引，device 显存）
//   m1Values[16]       : A14 在各 z 层的 m1 哈希值（已由调用方计算）
//   d_outBuf/d_outCnt  : 解存储缓冲与计数（slot >= OUT_CAP 时只计数不存储）
// ============================================================
__device__ void ConcatAiIter(
	const DevAzEntity *__restrict__ const *azFlat,
	int *__restrict__ const *azBucketStart,
	int *__restrict__ const *azBucketSize,
	const ull *__restrict__ m1Values,
	int *__restrict__ pAiState,
	int *__restrict__ pSuffixCnt,
	int *__restrict__ pIdx,
	int start_z,
	unsigned short *__restrict__ d_outBuf,
	unsigned long long *__restrict__ d_outCnt)
{
	const int LEN = 13;

	int d = 0;
	int z = start_z;

	for (int i = 0; i < 7; i++)
		pIdx[i] = -1;
	pIdx[0] = 0;

	pSuffixCnt[z] = LEN;

	// 预取各层的候选数量和起始偏移
	int candStart[7], candCount[7];
	for (int dd = 0; dd < 7; dd++)
	{
		int zz = start_z - dd;
		int mOrd = dOrdMatchings0_11[m1Values[zz]];
		candStart[dd] = azBucketStart[zz][mOrd];
		candCount[dd] = azBucketSize[zz][mOrd];
	}

	while (d >= 0)
	{
		z = start_z - d;

		// ---- idx 耗尽：回溯 ----
		if (candCount[d] < 0 || pIdx[d] >= candCount[d])
		{
			pSuffixCnt[z] = LEN;
			d--;
			if (d < 0)
				break;
			int pz = start_z - d;
			pSuffixCnt[pz] = LEN;
			continue;
		}

		// ---- 取候选 ----
		const DevAzEntity &item = azFlat[z][candStart[d] + pIdx[d]];
		pIdx[d]++;

		if (!check_linear(pAiState, pSuffixCnt, z, item.sed, Num_15 - LEN))
			continue;

		// ---- check 通过：解码并写入后缀 ----
		int *layerZ = pAiState + z * Num_15;
		for (int i = LEN; i < Num_15; i++)
		{
			layerZ[i] = item.sed[i - LEN];
		}
		pSuffixCnt[z] = Num_15;

		if (z - 1 == 6)
		{
			// ====== 边界 z==6：底盘逻辑 ======
			ull tuples0_6Mask = 0;
			ull ans_state[Num_16];
			int blkCnt = 0;

			for (int ii = N_16 - 1; ii > 6; ii--)
			{
				const int *layerII = pAiState + ii * Num_15;
				for (int jj = 0; jj < Num_15; jj++)
				{
					int st = layerII[jj];
					if (st <= (1 << 6) + (1 << 5) + (1 << 4))
					{
						tuples0_6Mask |= 1ull << (ull)d_triplesBits2Ord_dev[st];
					}
					ull tmp_all = (ull)st | (1ull << (ull)ii);
					bool seen = false;
					for (int kk = 0; kk < blkCnt; kk++)
					{
						if (ans_state[kk] == tmp_all)
						{
							seen = true;
							break;
						}
					}
					if (!seen)
						ans_state[blkCnt++] = tmp_all;
				}
			}

			tuples0_6Mask ^= d_tuples0_6FullMask_dev;

			int lo = 0, hi = d_t0_6sz_saved - 1, ansPos = 0;
			while (lo <= hi)
			{
				int mid = (lo + hi) >> 1;
				if (d_tuple0_6states_managed[mid].first >= tuples0_6Mask)
				{
					hi = mid - 1;
					ansPos = mid;
				}
				else
				{
					lo = mid + 1;
				}
			}

			while (ansPos < d_t0_6sz_saved && d_tuple0_6states_managed[ansPos].first == tuples0_6Mask)
			{
				// 存储完整解：blkCnt 个高位四元组 + low_state 展开的 {0..6} 四元组，共 140 个
				ull slot = atomicAdd(d_outCnt, 1ULL);
				if (slot < OUT_CAP)
				{
					unsigned short *dst = d_outBuf + slot * 140;
					int w = 0;
					for (int k = 0; k < blkCnt; k++)
						dst[w++] = (unsigned short)ans_state[k];
					ull ls = d_tuple0_6states_managed[ansPos].second;
					while (ls)
					{
						int bIdx = 63 - __clzll(ls);
						const int *q = d_tuples0_6_dev[bIdx];
						dst[w++] = (unsigned short)((1 << q[0]) | (1 << q[1]) | (1 << q[2]) | (1 << q[3]));
						ls &= ls - 1;
					}
				}
				ansPos++;
			}

			// 撤销后缀，留在当前层
			pSuffixCnt[z] = LEN;
		}
			else
			{
				// ---- 下钻 ----
				d++;
				int nz = z - 1;
				// nz 层前缀已由调用方填入 pAiState + nz*Num_15
				pSuffixCnt[nz] = LEN;
				pIdx[d] = 0;
			}
	}
}

// ============================================================
// Generate_A15 + PreSaveForConcat（预处理）
// ============================================================
__device__ inline void PreSaveForConcat(AzPreEntity *dpreSolveAz, int *d_CNT, int *Az)
{
	ull m1 = 0;
	AzPreEntity saveContent;
	int sedCnt = 0;
	for (int iSed = 0; iSed < Num_15; iSed++)
	{
		if ((Az[iSed] & (1 << 14)) &&
			!(Az[iSed] & (1 << 15)))
		{
			int val = Az[iSed] - (1 << 14);
			val -= dlowbit(val);
			int index = d_log_2[val];
			m1 = m1 * 12 + dreorderAll[dCurZ][index];
		}

		if ((Az[iSed] & (1 << 14)) ||
			(Az[iSed] & (1 << 15)))
			continue;
		saveContent.sed[sedCnt++] = Az[iSed];
	}
	int tmp = atomicAdd(d_CNT, 1);
	if (tmp >= NumsA14 * 2)
		return; // 超出 dans 容量（实测每层实体 35.7M < 71.2M，正常不会触发）
	saveContent.mOrd = dOrdMatchings0_11[m1];
	dpreSolveAz[tmp] = saveContent;
}

__global__ void Generate_A15(AzPreEntity *dpreSolveAz, int *d_CNT, int dn11, int dn10,
							 int x_sz, int d_solLength, Sol *d_sol0_9, ull full_mask,
							 int offset_x, int end_x)
{
	int pos_idx = blockIdx.x * blockDim.x + threadIdx.x;
	int pos_start_idx = pos_idx * x_sz + offset_x;
	int pos_end_idx = dMin2(offset_x + (pos_idx + 1) * x_sz - 1, end_x);

	int Az[Num_15];
	rep(pos, pos_start_idx, pos_end_idx)
	{
		int i = pos / dn10, j = pos % dn10;
		if ((dMatchings13[i] & dMatchings12[j]) == 0)
		{
			int a = dmatching13[i][0];
			int b = dmatching12[j][0];
			if (a > b)
				dswap(a, b);
			int c = dmatching13[i][1];
			int d = dmatching12[j][1];
			if (c > d)
				dswap(c, d);
			ull s = dMatchings13[i] | dMatchings12[j];
			rep(k, 0, 59) if (dtuple11[a][b][k].first && (s & dtuple11[a][b][k].first) == 0)
			{
				s |= dtuple11[a][b][k].first;
				rep(m, 0, 59) if (dtuple10[c][d][m].first && (s & dtuple10[c][d][m].first) == 0)
				{
					s |= dtuple10[c][d][m].first;
					int l = 0, r = d_solLength - 1, ans = r;
					ull query_s = full_mask ^ s;
					while (l <= r)
					{
						int mid = (l + r) >> 1;
						if (d_sol0_9[mid].s >= query_s)
						{
							r = mid - 1;
							ans = mid;
						}
						else
							l = mid + 1;
					}
					while (ans < d_solLength && d_sol0_9[ans].s == query_s)
					{
						Generate_seeds(dsedOf13[i],
									   dsedOf12[j],
									   dsedOf11[a][b][k],
									   dsedOf10[c][d][m],
									   d_sol0_9[ans].sol, Az);

						PreSaveForConcat(dpreSolveAz, d_CNT, Az);

						ans++;
					}
					s ^= dtuple10[c][d][m].first;
				}
				s ^= dtuple11[a][b][k].first;
			}
		}
	}
}

// ============================================================
// SearchSQS16Kernel：主搜索核函数
//   azFlat_dev[16], azBucketStart_dev[16], azBucketSize_dev[16] : z=7..13
//   threadStatePool : 每线程 Ai_state(16*35) + suffixCnt(16) + idx(7) ints
//   d_outBuf/d_outCnt : 每卡解存储缓冲与计数
// ============================================================
__global__ void SearchSQS16Kernel(
	DevAzEntity *__restrict__ const *azFlat_dev,
	int *__restrict__ const *azBucketStart_dev,
	int *__restrict__ const *azBucketSize_dev,
	int *__restrict__ threadStatePool,
	unsigned short *__restrict__ d_outBuf,
	unsigned long long *__restrict__ d_outCnt,
	int n11, int n10,
	int x_sz, int d_solLength, Sol *__restrict__ d_sol0_9,
	ull full_mask,
	int offset_x, int end_x)
{
	int pos_idx = blockIdx.x * blockDim.x + threadIdx.x;
	int thread_id = pos_idx;
	int pos_start_idx = pos_idx * x_sz + offset_x;
	int pos_end_idx = dMin2(offset_x + (pos_idx + 1) * x_sz - 1, end_x);

	if (pos_start_idx > pos_end_idx)
		return;

	int nTotalThreads = blockDim.x * gridDim.x;
	int *pAiState = threadStatePool + thread_id * PER_THREAD_AISTATE_SIZE;
	int *pSuffixCnt = threadStatePool + nTotalThreads * PER_THREAD_AISTATE_SIZE + thread_id * PER_THREAD_SUFFIXCNT_SIZE;
	int *pIdx = threadStatePool + nTotalThreads * (PER_THREAD_AISTATE_SIZE + PER_THREAD_SUFFIXCNT_SIZE) + thread_id * PER_THREAD_IDX_SIZE;

	// 初始化 Ai[15]
	rep(jj, 0, Num_15 - 1)
	{
		pAiState[15 * Num_15 + jj] = dA15[jj].state;
	}
	pSuffixCnt[15] = Num_15;

	int Az[Num_15];
	ull m1Values[16];

	rep(pos, pos_start_idx, pos_end_idx)
	{
		int i = pos / n10, j = pos % n10;
		if ((dMatchings13[i] & dMatchings12[j]) == 0)
		{
			int a = dmatching13[i][0];
			int b = dmatching12[j][0];
			if (a > b)
				dswap(a, b);
			int c = dmatching13[i][1];
			int d = dmatching12[j][1];
			if (c > d)
				dswap(c, d);
			ull s = dMatchings13[i] | dMatchings12[j];
			rep(k, 0, 59) if (dtuple11[a][b][k].first && (s & dtuple11[a][b][k].first) == 0)
			{
				s |= dtuple11[a][b][k].first;
				rep(m, 0, 59) if (dtuple10[c][d][m].first && (s & dtuple10[c][d][m].first) == 0)
				{
					s |= dtuple10[c][d][m].first;
					int l = 0, r = d_solLength - 1, ans = r;
					ull query_s = full_mask ^ s;
					while (l <= r)
					{
						int mid = (l + r) >> 1;
						if (d_sol0_9[mid].s >= query_s)
						{
							r = mid - 1;
							ans = mid;
						}
						else
							l = mid + 1;
					}
					
					while (ans < d_solLength && d_sol0_9[ans].s == query_s)
					{
						// ==== Rebuild Ai[14] ====
						Generate_seeds(dsedOf13[i], dsedOf12[j],
									   dsedOf11[a][b][k], dsedOf10[c][d][m],
									   d_sol0_9[ans].sol, Az);

						rep(jj, 0, Num_15 - 1)
						{
							pAiState[14 * Num_15 + jj] = Az[jj];
						}
						pSuffixCnt[14] = Num_15;

						// ==== Fill Ai[7..13] prefixes + compute m1Values ====
						for (int zz = 13; zz >= 7; zz--)
						{
							int *layerZ = pAiState + zz * Num_15;
							int zxor = zz ^ 1;
							layerZ[0] = (1 << zxor) + (1 << 14) + (1 << 15);
							int fillPos = 1;

							// triples from A15 with zz, without 14
							rep(ii, 0, Num_15 - 1)
							{
								int st = dA15[ii].state;
								if ((st & (1 << zz)) && !(st & (1 << 14)))
								{
									int val = st - (1 << zz);
									int bit1 = dlowbit(val);
									int bit2 = dlowbit(val ^ bit1);
									layerZ[fillPos++] = bit1 + bit2 + (1 << 15);
								}
							}

							// triples from A14 with zz, without 15 → m1
							// 对齐 CPU 版 searchAi.cpp:601: tmpMatching[reorder[z][a]] = reorder[z][b]
							// 这里直接按"对小到大顺序遍历 ii，每个三元组的较大元素累加 reorder"
							// 等价于 CPU 版的 for(i=0..11) if(tmpMatching[i]>i) m1=m1*12+tmpMatching[i]
							ull m1 = 0;
							rep(ii, 0, Num_15 - 1)
							{
								int st = Az[ii];
								if ((st & (1 << zz)) && !(st & (1 << 15)))
								{
									int val = st - (1 << zz);
									int bit1 = dlowbit(val);
									int bit2 = dlowbit(val ^ bit1);
									layerZ[fillPos++] = bit1 + bit2 + (1 << 14);
									m1 = m1 * 12 + dreorderAll[zz][d_log_2[bit2]];
								}
							}
							m1Values[zz] = m1;
							pSuffixCnt[zz] = fillPos;
						}

						// ==== Run search ====
						ConcatAiIter(azFlat_dev, azBucketStart_dev, azBucketSize_dev,
										  m1Values,
										  pAiState, pSuffixCnt, pIdx,
										  13, d_outBuf, d_outCnt);

						ans++;
					}
					s ^= dtuple10[c][d][m].first;
				}
				s ^= dtuple11[a][b][k].first;
			}
		}
	}
}

// ============================================================
// 预处理数据传输
// ============================================================
void cudaMemoryTransfer_preSolve(int z)
{
	cudaMemcpy(d_element0_9, element0_9, sizeof(int) * 120 * 3, cudaMemcpyHostToDevice);
	cudaMemcpy(d_sed_map, sed_map, sizeof(int) * 16, cudaMemcpyHostToDevice);
	cudaMemcpy(d_log_2, log_2, sizeof(int) * (1 << 21), cudaMemcpyHostToDevice);
	int tval = t_global;
	cudaMemcpy(&d_t, &tval, sizeof(int), cudaMemcpyHostToDevice);
	cudaMemcpy(d_son_blocks, son_blocks, sizeof(Pii) * 7, cudaMemcpyHostToDevice);
	cudaMemcpy(dMatchings13, Matchings13, sizeof(ull) * n11, cudaMemcpyHostToDevice);
	cudaMemcpy(dMatchings12, Matchings12, sizeof(ull) * n10, cudaMemcpyHostToDevice);
	cudaMemcpy(dtuple11, tuple11, sizeof(tuple11), cudaMemcpyHostToDevice);
	cudaMemcpy(dtuple10, tuple10, sizeof(tuple10), cudaMemcpyHostToDevice);
	cudaMemcpy(dmatching13, matching13, sizeof(matching13), cudaMemcpyHostToDevice);
	cudaMemcpy(dmatching12, matching12, sizeof(matching12), cudaMemcpyHostToDevice);
	cudaMemcpy(dsedOf13, sedOf13, sizeof(sedOf13), cudaMemcpyHostToDevice);
	cudaMemcpy(dsedOf12, sedOf12, sizeof(sedOf12), cudaMemcpyHostToDevice);
	cudaMemcpy(dsedOf11, sedOf11, sizeof(sedOf11), cudaMemcpyHostToDevice);
	cudaMemcpy(dsedOf10, sedOf10, sizeof(sedOf10), cudaMemcpyHostToDevice);
	cudaMemcpy(dreorderAll[z], reorder[z], sizeof(int) * N_16, cudaMemcpyHostToDevice);
	int tmpZ = z;
	cudaMemcpy(&dCurZ, &tmpZ, sizeof(int), cudaMemcpyHostToDevice);
	cudaMemcpy(dOrdMatchings0_11, ordMatchings0_11, sizeof(ordMatchings0_11), cudaMemcpyHostToDevice);

	// 注：原 cudaMemAdvise(…, cudaMemAdviseSetReadMostly, cudaCpuDeviceId) 已移除——
	// CUDA 13 删除了 int 设备号重载，且这些表都很小（≤8 MB），单卡下提示无收益。
	cudaError_t cudaerr = cudaGetLastError();
	printf("CUDA Error1: \"%s\".\n", cudaGetErrorString(cudaerr));
}

// ============================================================
// cudaPreSolveAz：在单卡上跑 Generate_A15，结果拷回 host buffer
// ============================================================
void cudaPreSolveAz(int dev_id, int z, AzPreEntity *hostBuf, int *hostCnt)
{
	cudaSetDevice(dev_id);

	int chunk_size = (n11 * n10 + 1 - 1) / 1;
	int offset_x = 0;
	int end_x = n11 * n10 - 1;

	int current_n = end_x - offset_x + 1;
	const dim3 GRID_SIZE = 1024;
	const dim3 BLOCK_SIZE = 1024;
	int x_sz = (current_n + 1024 * 1024 - 1) / (1024 * 1024);

	int *d_CNT;
	AzPreEntity *dans;
	Sol *d_sol0_9;

	printf("[GPU%d] A%d: sol0_9.size()=%zu (%.1f MB), dans_capacity=%d\n",
		   dev_id, z, sol0_9.size(), sizeof(Sol)*sol0_9.size()/1e6, NumsA14);

	cudaError_t err;
	err = cudaMalloc(&d_sol0_9, sizeof(Sol) * sol0_9.size());
	if (err != cudaSuccess) { printf("  cudaMalloc d_sol0_9 FAILED: %s\n", cudaGetErrorString(err)); return; }
	cudaMemcpy(d_sol0_9, &sol0_9[0], sizeof(Sol) * sol0_9.size(), cudaMemcpyHostToDevice);

	err = cudaMalloc(&dans, sizeof(AzPreEntity) * (NumsA14 * 2));
	if (err != cudaSuccess) { printf("  cudaMalloc dans FAILED: %s\n", cudaGetErrorString(err)); cudaFree(d_sol0_9); return; }
	err = cudaMalloc(&d_CNT, sizeof(int));
	if (err != cudaSuccess) { printf("  cudaMalloc d_CNT FAILED: %s\n", cudaGetErrorString(err)); cudaFree(d_sol0_9); cudaFree(dans); return; }
	cudaMemset(d_CNT, 0, sizeof(int));

	Generate_A15<<<GRID_SIZE, BLOCK_SIZE>>>(dans, d_CNT, n11, n10, x_sz, sol0_9.size(), d_sol0_9, full_mask,
											offset_x, end_x);

	cudaError_t cudaerr = cudaGetLastError();
	if (cudaerr != cudaSuccess)
		printf("PreSolve kernel failed with error \"%s\".\n", cudaGetErrorString(cudaerr));
	cudaDeviceSynchronize();

	int cnt;
	cudaMemcpy(&cnt, d_CNT, sizeof(int), cudaMemcpyDeviceToHost);
	cudaMemcpy(hostBuf, dans, sizeof(AzPreEntity) * cnt, cudaMemcpyDeviceToHost);
	*hostCnt = cnt;

	cudaFree(d_sol0_9);
	cudaFree(d_CNT);
	cudaFree(dans);

	printf("[GPU%d] A%d pre-solved: %d entities\n", dev_id, z, cnt);
}

// ============================================================
// BuildAzCSR：在 host 端对扁平实体做 mOrd 排序 + 分桶 + 压 CSR
// ============================================================
void BuildAzCSR(int z, AzPreEntity *flatBuf, int totalCnt)
{
	// 按 mOrd 排序
	sort(flatBuf, flatBuf + totalCnt,
		 [](const AzPreEntity &x, const AzPreEntity &y) {
			 return x.mOrd < y.mOrd;
		 });

	// 批量分配 bucket 数组
	hostAzBucketStart[z] = new int[MatchingNums_0_11];
	hostAzBucketSize[z] = new int[MatchingNums_0_11];
	for (int mOrd = 0; mOrd < MatchingNums_0_11; mOrd++)
	{
		hostAzBucketStart[z][mOrd] = -1;
		hostAzBucketSize[z][mOrd] = 0;
	}

	int curMOrd = -1;
	for (int i = 0; i < totalCnt; i++)
	{
		if (flatBuf[i].mOrd != curMOrd)
		{
			curMOrd = flatBuf[i].mOrd;
			hostAzBucketStart[z][curMOrd] = i;
		}
		hostAzBucketSize[z][curMOrd]++;
	}

	hostAzFlat[z] = flatBuf;
	hostAzTotalCnt[z] = totalCnt;

	int maxSz = 0;
	for (int m = 0; m < MatchingNums_0_11; m++)
		if (hostAzBucketSize[z][m] > maxSz) maxSz = hostAzBucketSize[z][m];
	printf("A%d CSR: total=%d, max_bucket=%d\n", z, totalCnt, maxSz);
}

// ============================================================
// UploadAzDevice：host 排序后的 AzPreEntity(100B) 压缩为 DevAzEntity(44B) 上传；
// 上传后释放该层的 host 排序缓冲（~3.6 GB/层），控制 host 内存峰值。
// ============================================================
void UploadAzDevice(int z)
{
	DevAzEntity *tmp = (DevAzEntity *)malloc(sizeof(DevAzEntity) * hostAzTotalCnt[z]);
	if (!tmp)
	{
		printf("UploadAzDevice A%d: host malloc (%.2f GB) FAILED\n", z,
			   sizeof(DevAzEntity) * hostAzTotalCnt[z] / 1e9);
		exit(1);
	}
	for (int i = 0; i < hostAzTotalCnt[z]; i++)
		for (int j = 0; j < 22; j++)
			tmp[i].sed[j] = (unsigned short)hostAzFlat[z][i].sed[j];

	cudaError_t err = cudaMalloc(&dAzFlat[z], sizeof(DevAzEntity) * hostAzTotalCnt[z]);
	if (err != cudaSuccess)
	{
		printf("UploadAzDevice A%d: cudaMalloc dAzFlat (%.2f GB) FAILED: %s\n", z,
			   sizeof(DevAzEntity) * hostAzTotalCnt[z] / 1e9, cudaGetErrorString(err));
		exit(1);
	}
	cudaMemcpy(dAzFlat[z], tmp, sizeof(DevAzEntity) * hostAzTotalCnt[z], cudaMemcpyHostToDevice);
	free(tmp);
	free(hostAzFlat[z]);
	hostAzFlat[z] = NULL; // host 排序缓冲使命结束

	err = cudaMalloc(&dAzBucketStart[z], sizeof(int) * MatchingNums_0_11);
	if (err != cudaSuccess)
	{
		printf("UploadAzDevice A%d: cudaMalloc bucketStart FAILED: %s\n", z, cudaGetErrorString(err));
		exit(1);
	}
	err = cudaMalloc(&dAzBucketSize[z], sizeof(int) * MatchingNums_0_11);
	if (err != cudaSuccess)
	{
		printf("UploadAzDevice A%d: cudaMalloc bucketSize FAILED: %s\n", z, cudaGetErrorString(err));
		exit(1);
	}
	cudaMemcpy(dAzBucketStart[z], hostAzBucketStart[z], sizeof(int) * MatchingNums_0_11, cudaMemcpyHostToDevice);
	cudaMemcpy(dAzBucketSize[z], hostAzBucketSize[z], sizeof(int) * MatchingNums_0_11, cudaMemcpyHostToDevice);
}

// ============================================================
// 搜索进度上报：每搜到 100 万个 SQS(16) 打印一次当前总数。
// 解计数器 d_outCnt 在 device 上被 kernel 原子递增；进度线程用
// cudaStreamNonBlocking 的小拷贝并发轮询——非阻塞流与 kernel 所在的
// 默认流无隐式同步，不会互相阻塞；上报线程在所有卡释放资源后才退出，
// 轮询期间指针恒有效，无竞态。
// ============================================================
unsigned long long *g_pollCnt[GPUNUMS] = {};
std::atomic<bool> g_searchRunning(false);

void ProgressReporter()
{
	cudaStream_t pollStream[GPUNUMS];
	for (int d = 0; d < GPUNUMS; d++)
	{
		cudaSetDevice(d);
		cudaStreamCreateWithFlags(&pollStream[d], cudaStreamNonBlocking);
	}
	const unsigned long long REPORT_STEP = 1000000ULL;
	unsigned long long reportedSteps = 0;
	while (g_searchRunning.load())
	{
		std::this_thread::sleep_for(std::chrono::seconds(1));
		if (!g_searchRunning.load())
			break;
		unsigned long long total = 0;
		for (int d = 0; d < GPUNUMS; d++)
		{
			if (!g_pollCnt[d])
				continue;
			unsigned long long v = 0;
			cudaSetDevice(d);
			cudaMemcpyAsync(&v, g_pollCnt[d], sizeof(unsigned long long),
							cudaMemcpyDeviceToHost, pollStream[d]);
			cudaStreamSynchronize(pollStream[d]);
			total += v;
		}
		if (total / REPORT_STEP > reportedSteps)
		{
			reportedSteps = total / REPORT_STEP;
			printf("[progress] SQS(16) found so far: %llu\n", total);
			fflush(stdout);
		}
	}
	for (int d = 0; d < GPUNUMS; d++)
	{
		cudaSetDevice(d);
		cudaStreamDestroy(pollStream[d]);
	}
}

// ============================================================
// RunSearch：多卡并行 search kernel，统计 SQS(16) 总数并把完整解写入文件
// 输出格式：每解 140 行，每行一个四元组（4 个 hex 字符），
//           可用 head -140 sqs16_solutions.txt | ./check 验证单个解
// ============================================================
unsigned long long RunSearch()
{
	unsigned long long totalCnt = 0;
	unsigned long long hostCnt[GPUNUMS] = {0};
	unsigned long long capturedCnt[GPUNUMS] = {0};

	FILE *fout = fopen("sqs16_solutions.txt", "w");
	if (!fout)
	{
		printf("ERROR: cannot open sqs16_solutions.txt for writing\n");
		exit(1);
	}

	// 进度上报线程：搜索期间每搜到 100 万个解打印一次当前总数
	g_searchRunning.store(true);
	std::thread reporter(ProgressReporter);

#pragma omp parallel num_threads(GPUNUMS)
	{
		int dev_id = omp_get_thread_num();
		cudaSetDevice(dev_id);

		cudaError_t cudaerr_run = cudaGetLastError();
		printf("CUDA Search GPU%d: \"%s\".\n", dev_id, cudaGetErrorString(cudaerr_run));

		auto st = chrono::steady_clock::now();

		int total_pos = n11 * n10;
		int chunk_size = (total_pos + GPUNUMS - 1) / GPUNUMS;
		int offset_x = chunk_size * dev_id;
		int end_x = min((int)(offset_x + chunk_size), total_pos) - 1;
#if TEST_POS_LIMIT > 0
		if (end_x > offset_x + TEST_POS_LIMIT - 1) end_x = offset_x + TEST_POS_LIMIT - 1;
#endif
		printf("GPU%d: search range [%d, %d] / %d\n", dev_id, offset_x, end_x, total_pos);

		if (offset_x <= end_x)
		{
			int current_n = end_x - offset_x + 1;
			const dim3 GRID_SIZE = 256;
			const dim3 BLOCK_SIZE = 256;
			int nThreads = GRID_SIZE.x * BLOCK_SIZE.x;
			int x_sz = (current_n + nThreads - 1) / nThreads;

			// 分配 per-thread state pool
			int poolPerThread = PER_THREAD_AISTATE_SIZE + PER_THREAD_SUFFIXCNT_SIZE + PER_THREAD_IDX_SIZE;
			size_t poolSize = (size_t)nThreads * poolPerThread * sizeof(int);
			int *d_threadPool;
			cudaerr_run = cudaMalloc(&d_threadPool, poolSize);
			if (cudaerr_run != cudaSuccess)
			{
				printf("GPU%d: cudaMalloc threadPool FAILED: %s\n", dev_id, cudaGetErrorString(cudaerr_run));
				exit(1);
			}
			cudaMemset(d_threadPool, 0, poolSize);

			// 每卡解存储缓冲：OUT_CAP 个解 × 140 个 ushort 四元组掩码（280 B/解）
			unsigned short *d_outBuf;
			unsigned long long *d_outCnt;
			cudaerr_run = cudaMalloc(&d_outBuf, sizeof(unsigned short) * 140 * OUT_CAP);
			if (cudaerr_run != cudaSuccess)
			{
				printf("GPU%d: cudaMalloc d_outBuf (%.2f GB) FAILED: %s\n", dev_id,
					   sizeof(unsigned short) * 140 * OUT_CAP / 1e9, cudaGetErrorString(cudaerr_run));
				exit(1);
			}
			cudaerr_run = cudaMalloc(&d_outCnt, sizeof(unsigned long long));
			if (cudaerr_run != cudaSuccess)
			{
				printf("GPU%d: cudaMalloc d_outCnt FAILED: %s\n", dev_id, cudaGetErrorString(cudaerr_run));
				exit(1);
			}
			cudaMemset(d_outCnt, 0, sizeof(unsigned long long));
			g_pollCnt[dev_id] = d_outCnt; // 注册给进度线程轮询

			// 构建设备端 azFlat/azBucketStart/azBucketSize 指针数组
			DevAzEntity *h_azFlat[16];
			int *h_azBucketStart[16];
			int *h_azBucketSize[16];
			for (int zz = 7; zz <= 13; zz++)
			{
				h_azFlat[zz] = dAzFlat[zz];
				h_azBucketStart[zz] = dAzBucketStart[zz];
				h_azBucketSize[zz] = dAzBucketSize[zz];
			}
			DevAzEntity **d_azFlat;
			int **d_azBucketStart;
			int **d_azBucketSize;
			cudaMalloc(&d_azFlat, sizeof(DevAzEntity *) * 16);
			cudaMalloc(&d_azBucketStart, sizeof(int *) * 16);
			cudaMalloc(&d_azBucketSize, sizeof(int *) * 16);
			cudaMemcpy(d_azFlat, h_azFlat, sizeof(DevAzEntity *) * 16, cudaMemcpyHostToDevice);
			cudaMemcpy(d_azBucketStart, h_azBucketStart, sizeof(int *) * 16, cudaMemcpyHostToDevice);
			cudaMemcpy(d_azBucketSize, h_azBucketSize, sizeof(int *) * 16, cudaMemcpyHostToDevice);

			SearchSQS16Kernel<<<GRID_SIZE, BLOCK_SIZE>>>(
				d_azFlat, d_azBucketStart, d_azBucketSize,
				d_threadPool,
				d_outBuf, d_outCnt,
				n11, n10, x_sz, d_sol0_9_size_saved, d_sol0_9_managed,
				full_mask, offset_x, end_x);

			cudaerr_run = cudaGetLastError();
			if (cudaerr_run != cudaSuccess)
				printf("Search kernel GPU%d failed: \"%s\".\n", dev_id, cudaGetErrorString(cudaerr_run));
			cudaDeviceSynchronize();

			// 拷回解计数；解数据分块拷回并写入文件（critical 串行写，拷回在 critical 外）
			unsigned long long cnt = 0;
			cudaMemcpy(&cnt, d_outCnt, sizeof(unsigned long long), cudaMemcpyDeviceToHost);
			hostCnt[dev_id] = cnt;
			unsigned long long captured = cnt < OUT_CAP ? cnt : OUT_CAP;
			capturedCnt[dev_id] = captured;

			const unsigned long long CHUNK = 1000000ULL; // 每块 100 万解（~280 MB host）
			unsigned short *hbuf = (unsigned short *)malloc(sizeof(unsigned short) * 140 * CHUNK);
			if (!hbuf)
			{
				printf("GPU%d: host malloc chunk buffer FAILED\n", dev_id);
				exit(1);
			}
			for (unsigned long long off = 0; off < captured; off += CHUNK)
			{
				unsigned long long n = captured - off < CHUNK ? captured - off : CHUNK;
				cudaMemcpy(hbuf, d_outBuf + off * 140, sizeof(unsigned short) * 140 * n, cudaMemcpyDeviceToHost);
#pragma omp critical(file_write)
				{
					for (unsigned long long sIdx = 0; sIdx < n; sIdx++)
					{
						const unsigned short *sol = hbuf + sIdx * 140;
						for (int b = 0; b < 140; b++)
						{
							int stv = sol[b];
							char line[5];
							int p = 0;
							while (stv)
							{
								int lv = stv & -stv;
								line[p++] = int2ch(log_2[lv]);
								stv ^= lv;
							}
							line[4] = '\n';
							fwrite(line, 1, 5, fout);
						}
					}
				}
			}
			free(hbuf);

			auto fi = chrono::steady_clock::now();
			printf("GPU%d search done in %lld ms, solutions=%llu (captured %llu to file)\n", dev_id,
				   (long long)chrono::duration_cast<std::chrono::milliseconds>(fi - st).count(),
				   hostCnt[dev_id], capturedCnt[dev_id]);

			cudaFree(d_threadPool);
			cudaFree(d_outBuf);
			cudaFree(d_outCnt);
			cudaFree(d_azFlat);
			cudaFree(d_azBucketStart);
			cudaFree(d_azBucketSize);
		}
	}

	// 搜索与资源释放全部结束：停掉进度线程（期间指针恒有效，无竞态）
	g_searchRunning.store(false);
	reporter.join();
	for (int d = 0; d < GPUNUMS; d++)
		g_pollCnt[d] = NULL;

	fclose(fout);

	for (int i = 0; i < GPUNUMS; i++)
		totalCnt += hostCnt[i];
	unsigned long long capturedTotal = 0;
	for (int i = 0; i < GPUNUMS; i++)
		capturedTotal += capturedCnt[i];
	if (capturedTotal < totalCnt)
		printf("WARNING: only %llu of %llu solutions stored (OUT_CAP=%llu per GPU exceeded; "
			   "raise OUT_CAP or run in ranges)\n",
			   capturedTotal, totalCnt, OUT_CAP);
	return totalCnt;
}

// ============================================================
// PreSolveForAi：预处理 A_z 候选并持久化
// ============================================================
void PreSolveForAi(int z)
{
	static bool isEntryFirst = false;
	if (!isEntryFirst)
	{
		PRE();

		matchings0_11Cnt = 0;
		memset(matching, -1, sizeof(matching));
		memset(ordMatchings0_11, -1, sizeof(ordMatchings0_11));
		search0_11Matching(0, 0);
		isEntryFirst = true;
		cout << "0-11 matching cnt: " << matchings0_11Cnt << endl;
	}

	len = 0;
	rep(i, 0, Num_15 - 1) if (Ai[15][i].state & (1 << z))
	{
		int val = Ai[15][i].state - (1 << z);
		int fir = lowbit(val);
		son_blocks[len].first = log_2[fir];
		val -= fir;
		son_blocks[len++].second = log_2[lowbit(val)];
	}

	PRE_SOLVE(z);

	// 预处理前四层 sed 块
	rep(i, 0, n11 - 1)
	{
		output_pair(Matchings13[i], 13, sedOf13[i]);
	}
	rep(i, 0, n10 - 1)
	{
		output_pair(Matchings12[i], 12, sedOf12[i]);
	}
	rep(i, 0, N_15 - 1)
		rep(j, 0, N_15 - 1)
			rep(k, 0, 59) if (tuple11[i][j][k].first != 0)
				output_pair(tuple11[i][j][k].second, 11, sedOf11[i][j][k]);
	rep(i, 0, N_15 - 1)
		rep(j, 0, N_15 - 1)
			rep(k, 0, 59) if (tuple10[i][j][k].first != 0)
				output_pair(tuple10[i][j][k].second, 10, sedOf10[i][j][k]);

	sort(sol0_9.begin(), sol0_9.end());

	// z = 7..14：传输只读表 + 建桶
	cudaMemoryTransfer_preSolve(z);

	if (z == 14)
	{
		// A14 预处理：只传输只读表，不建桶
		return;
	}

	// 在单 GPU0 上跑 Generate_A15，产出 AzPreEntity 数据
	AzPreEntity *flatBuf = (AzPreEntity *)malloc(sizeof(AzPreEntity) * (NumsA14 * 2));
	int totalCnt = 0;
	cudaPreSolveAz(0, z, flatBuf, &totalCnt);

	// CSR 化 + 上传到 managed 内存（多卡共享）
	BuildAzCSR(z, flatBuf, totalCnt);
	UploadAzDevice(z);
}

// Forward declarations for 0-6 tuples data (used in searchSQS16)
ull tuples0_6FullMask;

const int TUPLES0_6LIMIT = 10;
const int TUPLES0_6NUM = 35;
vector<pair<ull, ull>> tuple0_6states;
int tuples0_6[TUPLES0_6NUM][4], triples0_6[TUPLES0_6NUM][4], triplesBits2Ord[1 << 8];

// ============================================================
// GPU 搜索主流程
// ============================================================
void searchSQS16()
{
	// 计算 reorder
	for (int z = 13; z > 6; z--)
	{
		int tmpcnt = 0;
		for (int i = 0; i < N_16 - 2; i++)
			if (i != z && i != (z ^ 1))
			{
				reorder[z][i] = tmpcnt;
				invReorder[z][tmpcnt] = i;
				tmpcnt++;
			}
	}

	// 预处理 A7..A13 桶
	for (int z = 13; z >= 7; z--)
	{
		printf("Now presolve for A%d:\n", z);
		PreSolveForAi(z);
	}

	// 预处理 A14（只读表）
	PreSolveForAi(14);

	// sol0_9: managed，多卡共享
	cudaMallocManaged(&d_sol0_9_managed, sizeof(Sol) * sol0_9.size());
	cudaMemcpy(d_sol0_9_managed, &sol0_9[0], sizeof(Sol) * sol0_9.size(), cudaMemcpyHostToDevice);
	d_sol0_9_size_saved = sol0_9.size();

	// tuple0_6states: managed，多卡共享
	cudaMallocManaged(&d_tuple0_6states_managed, sizeof(pair<ull, ull>) * tuple0_6states.size());
	cudaMemcpy(d_tuple0_6states_managed, &tuple0_6states[0], sizeof(pair<ull, ull>) * tuple0_6states.size(), cudaMemcpyHostToDevice);
	d_t0_6sz_saved = tuple0_6states.size();

	// triplesBits2Ord + FullMask + tuples0_6 表 → managed 变量直接赋值（存解时展开 low_state 用）
	memcpy(d_triplesBits2Ord_dev, triplesBits2Ord, sizeof(int) * (1 << 8));
	d_tuples0_6FullMask_dev = tuples0_6FullMask;
	memcpy(d_tuples0_6_dev, tuples0_6, sizeof(int) * 35 * 4);

	printf("Starting GPU search on %d GPU(s)...\n", GPUNUMS);
	unsigned long long total = RunSearch();
	printf("\n========================================\n");
	printf("Total SQS(16) found: %llu\n", total);
	printf("Solutions written to sqs16_solutions.txt (140 lines each)\n");
	printf("========================================\n");
}

// ============================================================
// 生成 0-6 折半边界数据
// ============================================================
void search0_6Tuples(int dep, int las, ull state, ull triplesSelect)
{
	tuple0_6states.pb(mp(triplesSelect, state));
	if (dep == 10)
		return;
	for (int i = las + 1; i < cnt; i++)
	{
		int allBitsValue = (1 << tuples0_6[i][0]) + (1 << tuples0_6[i][1]) + (1 << tuples0_6[i][2]) + (1 << tuples0_6[i][3]);
		ull tmpValue = 0;
		for (int j = 0; j < 4; j++)
		{
			int triValue = allBitsValue ^ (1 << tuples0_6[i][j]);
			tmpValue |= 1ull << (ull)triplesBits2Ord[triValue];
		}
		if (triplesSelect & tmpValue)
			continue;
		search0_6Tuples(dep + 1, i, state | (1ull << (ull)i), triplesSelect | tmpValue);
	}
}

void generate0_6Tuples()
{
	cnt = 0;
	for (int i = 0; i < 7; i++)
		for (int j = i + 1; j < 7; j++)
			for (int k = j + 1; k < 7; k++)
			{
				triples0_6[cnt][0] = i;
				triples0_6[cnt][1] = j;
				triples0_6[cnt][2] = k;
				triplesBits2Ord[(1 << i) + (1 << j) + (1 << k)] = cnt;
				tuples0_6FullMask |= 1ull << (ull)cnt;
				cnt++;
			}

	cnt = 0;
	for (int i = 0; i < 7; i++)
		for (int j = i + 1; j < 7; j++)
			for (int k = j + 1; k < 7; k++)
				for (int l = k + 1; l < 7; l++)
				{
					tuples0_6[cnt][0] = i;
					tuples0_6[cnt][1] = j;
					tuples0_6[cnt][2] = k;
					tuples0_6[cnt++][3] = l;
				}
	search0_6Tuples(0, -1, 0, 0);
	sort(tuple0_6states.begin(), tuple0_6states.end());
	cout << "可能的0-6组成的四元组集合的数量是: " << tuple0_6states.size() << endl;
}

int main()
{
	setbuf(stdout, NULL);  // 禁用输出缓冲，便于实时查看进度
	freopen("NewS(2,3,15).txt", "r", stdin);
	// freopen("out.txt", "w", stdout);

	clock_t st, fi;
	st = clock();

	for (int t = 0; t < 1; t++)
	{
		for (int i = 0; i < Num_15; i++)
		{
			Ai[15][i] = tuple3{getch(), getch(), getch()};
			mask[Ai[15][i].state]++;
			maskAi[15][Ai[15][i].state] = true;
		}
	}
	cin.clear();

	// 拷贝 A15 到 device managed
	rep(i, 0, Num_15 - 1)
	{
		dA15[i] = Ai[15][i];
	}

	generate0_6Tuples();
	searchSQS16();

	fi = clock();
	printf("The total elapsed time is %f\n", double(fi - st) / CLOCKS_PER_SEC);

	fclose(stdin);
	// fclose(stdout);
	return 0;
}
