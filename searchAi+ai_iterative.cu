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
// 考虑搜索合法的(A16, A15) pair
#define rep(i, a, b) for (int i = (a); i <= (b); ++i)
#define per(i, a, b) for (int i = (a); i >= (b); --i)
#define pb push_back
#define mp make_pair
#define all(x) x.begin(), x.end()
#define GPUNUMS 4

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

struct Sol
{
	ull s;
	pair<ull, ull> sol;

	bool operator<(const Sol &x)
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
		sol0_9.pb((Sol){s, mp(high_bit, low_bit)});
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
																			pair<ull, ull> e, int dsed[])
{

	int len = 0; // 初始化len，填前7个
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

	// 找到A15, 对A15进行处理
	//  sort(d_sed, d_sed + d_len);
}

ull c, full_mask;

int t;

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
	full_mask |= c;											// 算出所有二元组都存在时的二进制数
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

	t = 0;
	for (int i = 0; i < 8; i++)
		for (int j = i + 1; j < 9; j++)
			for (int k = j + 1; k < 10; k++)
				if (arcMask[i][j] > 0 && arcMask[i][k] > 0 && arcMask[j][k] > 0 && !mask[(1 << sed_map[i]) + (1 << sed_map[j]) + (1 << sed_map[k])])
				{
					tuple0_9[t] = arcMask[i][j] + arcMask[i][k] + arcMask[j][k];
					element0_9[t][0] = i;
					element0_9[t][1] = j;
					element0_9[t][2] = k;
					t++;
				}

	printf("The value of t is %d\n", t);
	id_map.clear();
	sol0_9.clear();
	sol0_9.shrink_to_fit();
	cnt = 0;
	search0_9(t, 0, 0);
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
	bool operator<(AzPreEntity x)
	{ // 为二分做准备
		return mOrd < x.mOrd;
	}
};
int reorder[N_16][N_16], invReorder[N_16][N_16];

tuple3 sedOf13[3400][Num_15], sedOf12[3400][Num_15], sedOf11[N_16][N_16][70][Num_15], sedOf10[N_16][N_16][70][Num_15];
__device__ __managed__ tuple3 dsedOf13[3400][Num_15], dsedOf12[3400][Num_15], dsedOf11[N_16][N_16][70][Num_15], dsedOf10[N_16][N_16][70][Num_15];

__device__ inline void dswap(int &a, int &b)
{
	a ^= b;
	b ^= a;
	a ^= b;
}

__device__ __managed__ int dreorder[N_16], dOrdMatchings0_11[Hash0_11Num];

__device__ inline void PreSaveForConcat(AzPreEntity *dpreSolveAz, int *d_CNT, int *Az)
{
	ull m1 = 0;
	AzPreEntity saveContent;
	int sedCnt = 0;
	for (int iSed = 0; iSed < Num_15; iSed++)
	{
		if ((Az[iSed] & (1 << 14)) &&
				!(Az[iSed] & (1 << 15)))
		{ // 判断是否是和A14的共同结构
			int val = Az[iSed] - (1 << 14);
			val -= lowbit(val);
			int index = log_2[val];
			m1 = m1 * 12 + dreorder[index];
		}

		if ((Az[iSed] & (1 << 14)) ||
				(Az[iSed] & (1 << 15)))
			continue;
		saveContent.sed[sedCnt++] = Az[iSed]; // 将剩下的tuple存到哈希表里
	}
	int tmp = atomicAdd(d_CNT, 1);
	saveContent.mOrd = dOrdMatchings0_11[m1];
	dpreSolveAz[tmp] = saveContent;
}

__global__ void Generate_A15(AzPreEntity *dpreSolveAz, int *d_CNT, int dn11, int dn10,
														 int x_sz, int d_solLength, Sol *d_sol0_9, ull full_mask,
														 int offset_x, int end_x)
{
	// 将核函数改造成将整个枚举过程加入
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
					ull query_s = full_mask ^ s; // 得到目标二进制
					while (l <= r)
					{ // 二分出答案位置
						int mid = (l + r) >> 1;
						if (d_sol0_9[mid].s >= query_s)
						{
							r = mid - 1;
							ans = mid;
						}
						else
							l = mid + 1;
					}
					// 注意可能有连续的一段答案
					while (ans < d_solLength && d_sol0_9[ans].s == query_s)
					{
						Generate_seeds(dsedOf13[i],
													 dsedOf12[j],
													 dsedOf11[a][b][k],
													 dsedOf10[c][d][m],
													 d_sol0_9[ans].sol, Az); // 将生成的Ai放到数组dans中

						// 根据dans进行预处理保存
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

void cudaMemoryTransfer_preSolve(int z)
{
	// 拷贝 element0_9
	cudaMemcpy(d_element0_9, element0_9, sizeof(int) * 120 * 3, cudaMemcpyHostToDevice);
	// 拷贝mask sed_map
	cudaMemcpy(d_sed_map, sed_map, sizeof(int) * 16, cudaMemcpyHostToDevice);
	// 拷贝 log2
	cudaMemcpy(d_log_2, log_2, sizeof(int) * (1 << 21), cudaMemcpyHostToDevice);
	// 拷贝d_t
	cudaMemcpy(&d_t, &t, sizeof(int), cudaMemcpyHostToDevice);
	// 拷贝d_son_blocks
	cudaMemcpy(d_son_blocks, son_blocks, sizeof(Pii) * 7, cudaMemcpyHostToDevice);
	// 拷贝 dMatching dtuple dmatching
	cudaMemcpy(dMatchings13, Matchings13, sizeof(ull) * n11, cudaMemcpyHostToDevice);
	cudaMemcpy(dMatchings12, Matchings12, sizeof(ull) * n10, cudaMemcpyHostToDevice);
	cudaMemcpy(dtuple11, tuple11, sizeof(tuple11), cudaMemcpyHostToDevice);
	cudaMemcpy(dtuple10, tuple10, sizeof(tuple10), cudaMemcpyHostToDevice);
	cudaMemcpy(dmatching13, matching13, sizeof(matching13), cudaMemcpyHostToDevice);
	cudaMemcpy(dmatching12, matching12, sizeof(matching12), cudaMemcpyHostToDevice);
	// 拷贝 d_sed
	cudaMemcpy(dsedOf13, sedOf13, sizeof(sedOf13), cudaMemcpyHostToDevice);
	cudaMemcpy(dsedOf12, sedOf12, sizeof(sedOf12), cudaMemcpyHostToDevice);
	cudaMemcpy(dsedOf11, sedOf11, sizeof(sedOf11), cudaMemcpyHostToDevice);
	cudaMemcpy(dsedOf10, sedOf10, sizeof(sedOf10), cudaMemcpyHostToDevice);
	// 拷贝 reorder[z]
	cudaMemcpy(dreorder, reorder[z], sizeof(int) * N_16, cudaMemcpyHostToDevice);
	// 拷贝 ordMatchings0_11
	cudaMemcpy(dOrdMatchings0_11, ordMatchings0_11, sizeof(ordMatchings0_11), cudaMemcpyHostToDevice);

	// 每张卡上都放置数据副本
	cudaMemAdvise(d_element0_9, sizeof(int) * 120 * 3, cudaMemAdviseSetReadMostly, cudaCpuDeviceId);
	cudaMemAdvise(d_sed_map, sizeof(int) * 16, cudaMemAdviseSetReadMostly, cudaCpuDeviceId);
	cudaMemAdvise(d_log_2, sizeof(int) * (1 << 21), cudaMemAdviseSetReadMostly, cudaCpuDeviceId);
	cudaMemAdvise(d_son_blocks, sizeof(Pii) * 7, cudaMemAdviseSetReadMostly, cudaCpuDeviceId);

	cudaMemAdvise(dMatchings13, sizeof(ull) * n11, cudaMemAdviseSetReadMostly, cudaCpuDeviceId);
	cudaMemAdvise(dMatchings12, sizeof(ull) * n10, cudaMemAdviseSetReadMostly, cudaCpuDeviceId);
	cudaMemAdvise(dtuple11, sizeof(dtuple11), cudaMemAdviseSetReadMostly, cudaCpuDeviceId);
	cudaMemAdvise(dtuple10, sizeof(dtuple10), cudaMemAdviseSetReadMostly, cudaCpuDeviceId);
	cudaMemAdvise(dmatching13, sizeof(dmatching13), cudaMemAdviseSetReadMostly, cudaCpuDeviceId);
	cudaMemAdvise(dmatching12, sizeof(dmatching12), cudaMemAdviseSetReadMostly, cudaCpuDeviceId);

	cudaMemAdvise(dsedOf13, sizeof(dsedOf13), cudaMemAdviseSetReadMostly, cudaCpuDeviceId);
	cudaMemAdvise(dsedOf12, sizeof(dsedOf12), cudaMemAdviseSetReadMostly, cudaCpuDeviceId);
	cudaMemAdvise(dsedOf11, sizeof(dsedOf11), cudaMemAdviseSetReadMostly, cudaCpuDeviceId);
	cudaMemAdvise(dsedOf10, sizeof(dsedOf10), cudaMemAdviseSetReadMostly, cudaCpuDeviceId);

	cudaMemAdvise(dreorder, sizeof(dreorder), cudaMemAdviseSetReadMostly, cudaCpuDeviceId);
	cudaMemAdvise(dOrdMatchings0_11, sizeof(dOrdMatchings0_11), cudaMemAdviseSetReadMostly, cudaCpuDeviceId);

	cudaError_t cudaerr = cudaGetLastError();
	printf("CUDA Error1: \"%s\".\n", cudaGetErrorString(cudaerr));
}

void cudaSearchingAi(int z, AzPreEntity *ans)
{
	cudaDeviceProp prop;
	cudaGetDeviceProperties(&prop, 0);
	printf("最大线程块数量: %d\n", prop.maxBlocksPerMultiProcessor);
	printf("每个线程块的最大线程数量: %d\n", prop.maxThreadsPerBlock);
	printf("每个线程块的维度限制: (%d, %d, %d)\n", prop.maxThreadsDim[0], prop.maxThreadsDim[1], prop.maxThreadsDim[2]);
	printf("每个多处理器的最大线程数量: %d\n", prop.maxThreadsPerMultiProcessor);

	int total_cnt = 0;

	int hostCnt[4] = {0};
#pragma omp parallel num_threads(GPUNUMS)
	{
		// 拷贝d_sol(在多张卡之间搬运困难)
		int dev_id = omp_get_thread_num();
		cudaSetDevice(dev_id);

		cudaError_t cudaerr_run = cudaGetLastError();
		printf("CUDA Error2: \"%s\".\n",
					 cudaGetErrorString(cudaerr_run));

		auto st = chrono::steady_clock::now();
		// 确定线程分配的任务数
		int chunk_size = (n11 * n10 + GPUNUMS - 1) / GPUNUMS;
		int offset_x = chunk_size * dev_id;
		int end_x = min(offset_x + chunk_size, n11 * n10) - 1;

		if (offset_x <= end_x)
		{
			int current_n = end_x - offset_x + 1;
			const dim3 GRID_SIZE = 1024;
			const dim3 BLOCK_SIZE = 1024;
			int x_sz = (current_n + 1024 * 1024 - 1) / (1024 * 1024);

			int *d_CNT;
			AzPreEntity *dans;
			Sol *d_sol0_9;

			// 给每张卡上需要的变量转移内存
			cudaMalloc(&d_sol0_9, sizeof(Sol) * sol0_9.size());
			cudaMemcpy(d_sol0_9, &sol0_9[0], sizeof(Sol) * sol0_9.size(), cudaMemcpyHostToDevice);
			cudaMalloc(&dans, sizeof(AzPreEntity) * NumsA14 / 2);
			cudaMalloc(&d_CNT, sizeof(int));
			cudaMemset(d_CNT, 0, sizeof(int));

			Generate_A15<<<GRID_SIZE, BLOCK_SIZE>>>(dans, d_CNT, n11, n10, x_sz, sol0_9.size(), d_sol0_9, full_mask,
																							offset_x, end_x);

			cudaerr_run = cudaGetLastError();
			if (cudaerr_run != cudaSuccess)
				printf("kernel failed with error \"%s\".\n",
							 cudaGetErrorString(cudaerr_run));
			cudaDeviceSynchronize();

			auto fi = chrono::steady_clock::now();
			printf("The total elapsed time of thread %d is ", dev_id);
			cout << chrono::duration_cast<std::chrono::milliseconds>(fi - st).count() << endl;

			cudaMemcpy(&hostCnt[dev_id], d_CNT, sizeof(int), cudaMemcpyDeviceToHost);

#pragma omp barrier
#pragma omp single
			for (int i = 0; i < GPUNUMS; i++)
			{
				cudaMemcpy(&ans[total_cnt * Num_15], dans, sizeof(AzPreEntity) * hostCnt[i], cudaMemcpyDeviceToHost);
				total_cnt += hostCnt[i];
			}

			// 释放申请的内存
			cudaFree(d_sol0_9);
			cudaFree(d_CNT);
			cudaFree(dans);
		}
	}

	printf("The CNT is: %d\n", total_cnt);
}

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

	// 预处理前面四层生成的block保存为sed
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

	// 对预处理三元组数组排序 cuda时采用二分搜索
	sort(sol0_9.begin(), sol0_9.end());

	if (z == 14) // 14不需要预处理下面的内容
		return;

	// 用于存放答案的数组，此时申请内存
	AzPreEntity *ans;
	ans = (AzPreEntity *)malloc(sizeof(AzPreEntity) * NumsA14 * Num_15);

	cudaMemoryTransfer_preSolve(z);
	cudaSearchingAi(z, ans);

	free(ans);
}

__device__ __managed__ int AiInSearch[N_16][Num_15], maskInSearch[1 << N_16];

// 把后缀 item.sed[i] 解码成 tuple3 的 device 版本（CPU 中 extract2tuple3 的 GPU 镜像）
__device__ inline tuple3 d_extract2tuple3(int val)
{
	int a = dlowbit(val);
	int b = dlowbit(val ^ a);
	int c = dlowbit(val ^ a ^ b);
	return tuple3(d_log_2[a], d_log_2[b], d_log_2[c]);
}

// 参数化版的 check（CPU check 的 GPU 镜像）：mask / maskAi 改成由调用方传入指针，
// 这样每个 GPU 线程可以维护自己的 mask、maskAi，避免多线程共用 __managed__ 全局造成冲突。
__device__ inline bool check_param(AzPreEntity &item, int size, int z,
								   int *pMask, bool (*pMaskAi)[1 << N_16])
{
	int highBitsMask = ((1 << N_16) - 1) ^ ((1 << (z + 1)) - 1);
	for (int i = 0; i < size; i++)
	{
		int sed = item.sed[i];
		int highVal = sed & highBitsMask;
		if (highVal)
		{
			while (highVal)
			{
				int r = dlowbit(highVal);
				if (!pMaskAi[d_log_2[r]][sed ^ r ^ (1 << z)])
				{
					return false;
				}
				highVal ^= r;
			}
		}
		else if (pMask[sed])
		{
			return false;
		}
	}
	return true;
}

// ============================================================================
// ConcatAi 的栈式迭代实现（对应 CPU 版 searchAi.cpp:457-566）
//
// 递归层 z = start_z, start_z-1, ..., 7（边界 z==6 不再递归，内联在 z==7 帧里）。
// 因此固定深度 = 7，用 idx[7] 模拟调用栈即可，完全不需要动态栈结构。
//
// 每层语义保持与 CPU 版一致：
//   1) 入栈层 z 时，将 Ai[z][0..12] 这 13 个前缀 block 标记进 mask/maskAi。
//   2) 顺序枚举 d_cands[depth][0..d_nCand[depth]-1]：
//        a) check_param 不通过 → 跳到下一个候选；
//        b) 通过 → 把 item.sed[0..21] 解码到 Ai[z][13..34] 并标记，然后下钻；
//        c) 下钻返回后撤销 b) 的标记，继续枚举。
//   3) 该层枚举完毕：撤销 1) 的前缀标记，弹回上一层。
//   4) 边界 z==6：不再下钻，直接做 tuples0_6Mask 计算 + 二分 tuple0_6states，
//      命中数累加进 d_resultCnt（对应 CPU 的 DEBUGVARIABLE）。
//
// 入参（约定）：
//   start_z       : 13
//   d_cands[d]    : 深度 d (即 z = start_z - d) 上、已经按 m1Values[z] 过滤好的候选数组
//                   （CPU 端 preSolveAz[z][ordMatchings0_11[m1Values[z]]] 的扁平化版本）
//   d_nCand[d]    : 上述数组长度
//   pAi           : 每线程私有的 Ai[N_16][Num_15]；要求调用前 Ai[z][0..12]（z=7..13）
//                   以及 Ai[14]、Ai[15] 已经填好
//   pMask         : 每线程私有的 mask[1<<N_16]
//   pMaskAi       : 每线程私有的 maskAi[N_16][1<<N_16]
//                   要求调用前 Ai[15]、Ai[14]、以及 Ai[z][0..12] 的前缀都已计入
//   d_tuple0_6states / d_t0_6sz / d_triplesBits2Ord / d_tuples0_6FullMask :
//                   z==6 边界用到的只读全局数据（多线程共享）
//   d_resultCnt   : 命中 SQS(16) 的全局原子计数器
// ============================================================================
__device__ void ConcatAiIter(
	int start_z,
	AzPreEntity *const *d_cands,
	const int *d_nCand,
	tuple3 (*pAi)[Num_15],
	int *pMask,
	bool (*pMaskAi)[1 << N_16],
	const pair<ull, ull> *d_tuple0_6states,
	int d_t0_6sz,
	const int *d_triplesBits2Ord,
	ull d_tuples0_6FullMask,
	unsigned long long *d_resultCnt)
{
	const int LEN = 13;        // 每层 Ai[z] 的前缀长度（GenerateSQS16 已填好）
	const int MAX_DEPTH = 7;   // z = 13..7 → depth d = 0..6

	int idx[MAX_DEPTH];
	int d = 0;
	int z = start_z;

	// ---- 初始：层 start_z 的前缀标记 ----
	for (int i = 0; i < LEN; i++)
	{
		int s = pAi[z][i].state;
		pMask[s]++;
		pMaskAi[z][s] = true;
	}
	idx[0] = 0;

	while (d >= 0)
	{
		z = start_z - d;

		// ---------- 该层候选枚举完，回溯到上一层 ----------
		if (idx[d] >= d_nCand[d])
		{
			// 撤销当前层的前缀标记
			for (int i = 0; i < LEN; i++)
			{
				int s = pAi[z][i].state;
				pMask[s]--;
				pMaskAi[z][s] = false;
			}
			d--;
			if (d < 0)
				break;

			// 撤销在父层"下钻前压入"的那条 item 的后缀标记
			int pz = start_z - d;
			for (int i = LEN; i < Num_15; i++)
			{
				int s = pAi[pz][i].state;
				pMask[s]--;
				pMaskAi[pz][s] = false;
			}
			continue;
		}

		// ---------- 试下一个候选 ----------
		AzPreEntity &item = d_cands[d][idx[d]];
		idx[d]++;

		if (!check_param(item, Num_15 - LEN, z, pMask, pMaskAi))
			continue;

		// 把 item 解码到 Ai[z][13..34] 并打标
		for (int i = LEN; i < Num_15; i++)
		{
			pAi[z][i] = d_extract2tuple3(item.sed[i - LEN]);
			int s = pAi[z][i].state;
			pMask[s]++;
			pMaskAi[z][s] = true;
		}

		if (z - 1 == 6)
		{
			// ====================== 边界：CPU 版 z==6 分支 ======================
			ull tuples0_6Mask = 0;
			ull ans_state[Num_16];
			int blkCnt = 0;

			// 收集 i=15..7 各层的 4-block，并对 (state | (1<<i)) 去重（线性，最多 ~140 项）
			for (int ii = N_16 - 1; ii > 6; ii--)
			{
				for (int j = 0; j < Num_15; j++)
				{
					int st = pAi[ii][j].state;
					if (st <= (1 << 6) + (1 << 5) + (1 << 4))
					{
						tuples0_6Mask |= 1ull << (ull)d_triplesBits2Ord[st];
					}
					ull tmp_all = (ull)st | (1ull << (ull)ii);

					bool seen = false;
					for (int k = 0; k < blkCnt; k++)
					{
						if (ans_state[k] == tmp_all)
						{
							seen = true;
							break;
						}
					}
					if (seen)
						continue;
					ans_state[blkCnt++] = tmp_all;
				}
			}

			tuples0_6Mask ^= d_tuples0_6FullMask;

			// 二分 tuple0_6states，找首个 first >= tuples0_6Mask 的位置
			int lo = 0, hi = d_t0_6sz - 1, ans = 0;
			while (lo <= hi)
			{
				int mid = (lo + hi) >> 1;
				if (d_tuple0_6states[mid].first >= tuples0_6Mask)
				{
					hi = mid - 1;
					ans = mid;
				}
				else
				{
					lo = mid + 1;
				}
			}

			// 累加 SQS(16) 命中数（对应 CPU 的 DEBUGVARIABLE）
			while (ans < d_t0_6sz && d_tuple0_6states[ans].first == tuples0_6Mask)
			{
				atomicAdd(d_resultCnt, 1ULL);
				ans++;
			}

			// 不下钻，直接撤销刚才压入的 item 后缀，留在当前层继续枚举
			for (int i = LEN; i < Num_15; i++)
			{
				int s = pAi[z][i].state;
				pMask[s]--;
				pMaskAi[z][s] = false;
			}
		}
		else
		{
			// ---------- 下钻：进入下一层并压入下一层的前缀 ----------
			d++;
			int nz = z - 1;
			for (int i = 0; i < LEN; i++)
			{
				int s = pAi[nz][i].state;
				pMask[s]++;
				pMaskAi[nz][s] = true;
			}
			idx[d] = 0;
			// 注意：当前层的 item 后缀标记保持，等到下一层 idx[d+1] 耗尽回溯时统一撤销
		}
	}
}

// 旧的空 stub 保留接口签名以便外部 kernel 适配，内部直接转发到 ConcatAiIter
__device__ void concatAi(int start_z, AzPreEntity *dPreSolveAz) {
	// 占位：实际调用请使用 ConcatAiIter，并按上面的注释准备好
	// d_cands / d_nCand / 每线程的 pAi/pMask/pMaskAi 等参数。
}

__global__ void generateSQS16(AzPreEntity *dPreSolveAz, int dn11, int dn10,
															int x_sz, int d_solLength, Sol *d_sol0_9, ull full_mask,
															int offset_x, int end_x)
{
	// 将核函数改造成将整个枚举过程加入
	int pos_idx = blockIdx.x * blockDim.x + threadIdx.x;
	int pos_start_idx = pos_idx * x_sz + offset_x;
	int pos_end_idx = dMin2(offset_x + (pos_idx + 1) * x_sz - 1, end_x);

	rep(pos, pos_start_idx, pos_end_idx)
	{
		int i = pos / dn10, j = pos % dn10;
		if ((Matchings13[i] & Matchings12[j]) == 0)
		{
			ull s = Matchings13[i] | Matchings12[j];
			int a = matching13[i][0];
			int b = matching12[j][0];
			if (a > b)
				swap(a, b);
			int c = matching13[i][1];
			int d = matching12[j][1];
			if (c > d)
				swap(c, d);
			for (int k = 0; k < 60; k++)
				if (tuple11[a][b][k].first != 0 && (s & tuple11[a][b][k].first) == 0)
				{
					s |= tuple11[a][b][k].first;
					for (int l = 0; l < 60; l++)
						if (tuple10[c][d][l].first != 0 && (s & tuple10[c][d][l].first) == 0)
						{
							s |= tuple10[c][d][l].first;
							if ((s & full_mask) != s)
								assert("Wrong1!");

							ull query_s = full_mask ^ s;
							if (!id_map.count(query_s))
							{
								s -= tuple10[c][d][l].first;
								continue;
							}

							for (auto e : sol0_9[id_map[query_s]])
							{
								Generate_seeds(Matchings13[i], Matchings12[j], tuple11[a][b][k].second,
															 tuple10[c][d][l].second, e, Ai[14]);
								// 此时固定Ai[15]和Ai[14]开始递归拼接Az，注意首先处理mask
								for (int i = 0; i < Num_15; i++)
								{
									mask[Ai[14][i].state]++;
									maskAi[14][Ai[14][i].state] = true;
								}
								// cout << "Printing 14:" << endl;
								// for (int i = 0 ; i < Num_15 ; i++)
								//     cout << Ai[14][i].a << ' ' << Ai[14][i].b << ' ' << Ai[14][i].c << endl;
								GenerateSQS16();
								for (int i = 0; i < Num_15; i++)
								{
									mask[Ai[14][i].state]--;
									maskAi[14][Ai[14][i].state] = false;
								}
							}
							s -= tuple10[c][d][l].first;
						}
					s -= tuple11[a][b][k].first;
				}
		}
	}
}

ull tuples0_6FullMask;

const int TUPLES0_6LIMIT = 10;
const int TUPLES0_6NUM = 35;
vector<pair<ull, ull>> tuple0_6states;
int tuples0_6[TUPLES0_6NUM][4], triples0_6[TUPLES0_6NUM][4], triplesBits2Ord[1 << 8];

ull m1Values[N_16];

tuple3 extract2tuple3(int val)
{
	int a = lowbit(val);
	int b = lowbit(val ^ a);
	int c = lowbit(val ^ a ^ b);
	return tuple3{log_2[a], log_2[b], log_2[c]};
}

void searchSQS16()
{
	int tmpcnt = 0;
	for (int i = 0; i < N_16 - 2; i++)
		if (i != z && i != (z ^ 1))
		{
			reorder[z][i] = tmpcnt;
			invReorder[z][tmpcnt] = i;
		}

	for (int z = 13; z >= 7; z--)
	{
		printf("Now presolve for A%d:\n", z);
		PreSolveForAi(z);
	}

	// 生成A14的预处理
	PreSolveForAi(14);

	// 基于A15开始生成A14,然后开始拼接Az,这里的生成和拼接都用GPU来做
	ull total_cnt = 0;
	ull hostCnt[4] = {0};
#pragma omp parallel num_threads(GPUNUMS)
	{
		// 拷贝d_sol(在多张卡之间搬运困难)
		int dev_id = omp_get_thread_num();
		cudaSetDevice(dev_id);

		cudaError_t cudaerr_run = cudaGetLastError();
		printf("CUDA Error2: \"%s\".\n",
					 cudaGetErrorString(cudaerr_run));

		auto st = chrono::steady_clock::now();
		// 确定线程分配的任务数
		int chunk_size = (n11 * n10 + GPUNUMS - 1) / GPUNUMS;
		int offset_x = chunk_size * dev_id;
		int end_x = min(offset_x + chunk_size, n11 * n10) - 1;

		if (offset_x <= end_x)
		{
			int current_n = end_x - offset_x + 1;
			const dim3 GRID_SIZE = 1024;
			const dim3 BLOCK_SIZE = 1024;
			int x_sz = (current_n + 1024 * 1024 - 1) / (1024 * 1024);

			int *d_CNT;
			AzPreEntity *dans;
			Sol *d_sol0_9;

			// 给每张卡上需要的变量转移内存
			cudaMalloc(&d_sol0_9, sizeof(Sol) * sol0_9.size());
			cudaMemcpy(d_sol0_9, &sol0_9[0], sizeof(Sol) * sol0_9.size(), cudaMemcpyHostToDevice);
			cudaMalloc(&dans, sizeof(AzPreEntity) * NumsA14 / 2);
			cudaMalloc(&d_CNT, sizeof(int));
			cudaMemset(d_CNT, 0, sizeof(int));

			GenerateSQS16<<<GRID_SIZE, BLOCK_SIZE>>>(dans, d_CNT, n11, n10, x_sz, sol0_9.size(), d_sol0_9, full_mask,
																							offset_x, end_x);

			cudaerr_run = cudaGetLastError();
			if (cudaerr_run != cudaSuccess)
				printf("kernel failed with error \"%s\".\n",
							 cudaGetErrorString(cudaerr_run));
			cudaDeviceSynchronize();

			auto fi = chrono::steady_clock::now();
			printf("The total elapsed time of thread %d is ", dev_id);
			cout << chrono::duration_cast<std::chrono::milliseconds>(fi - st).count() << endl;

			cudaMemcpy(&hostCnt[dev_id], d_CNT, sizeof(int), cudaMemcpyDeviceToHost);

#pragma omp barrier
#pragma omp single
			for (int i = 0; i < GPUNUMS; i++)
			{
				cudaMemcpy(&ans[total_cnt * Num_15], dans, sizeof(AzPreEntity) * hostCnt[i], cudaMemcpyDeviceToHost);
				total_cnt += hostCnt[i];
			}

			// 释放申请的内存
			cudaFree(d_sol0_9);
			cudaFree(d_CNT);
			cudaFree(dans);
		}
	}

	printf("The CNT is: %d\n", total_cnt);
}

void search0_6Tuples(int dep, int las, ull state, ull triplesSelect)
{
	tuple0_6states.pb(mp(triplesSelect, state));
	if (dep == 10)
		return;
	for (int i = las + 1; i < cnt; i++)
	{
		bool flag = true;
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
	// 以下所有steiner system以及子结构、孙子结构均要求内部按字典序排序
	freopen("NewS(2,3,15).txt", "r", stdin);
	// freopen("A14.txt", "w", stdout);

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

	CNT = 0;
	generate0_6Tuples();
	searchSQS16();

	fclose(stdin);
	// fclose(stdout);
	return 0;
}