#include<stdio.h>
#include<stdlib.h>
#include<iostream>
#include<algorithm>
#include<string>
#include<string.h>
#include<cmath>
#include<vector>
#include<set>
#include<assert.h>
#include<unordered_map>
#include<queue>
#include<bitset>
#include<time.h>
#include <thrust/sort.h> //sort库
#include <chrono>
//考虑搜索合法的(A16, A15) pair
#define rep(i,a,b) for(int i=(a);i<=(b);++i)
#define per(i,a,b) for(int i=(a);i>=(b);--i)
#define pb push_back
#define mp make_pair
#define all(x) x.begin(),x.end()

using namespace std;
typedef long long ll;
typedef unsigned long long ull;
typedef pair<int,int> Pii;

const int N_16 = 16;
const int N_15 = 15;
const int Num_16 = N_16 * (N_16 - 1) * (N_16 - 2) / 6 / 4;
const int Num_15 = N_15 * (N_15 - 1) / 2 / 3;
const int T_15 = 80;


struct tuple3{
    int a, b, c;
	bool operator <(const tuple3& x) const
	{ return a == x.a ? (b == x.b ? (c < x.c) : (b < x.b)) : a < x.a; }
} blocks_15[Num_15], sed[Num_15], A14[Num_15];

ll CNT = 0;

int getch() {
	while(true){
		char ch; cin >> ch;
		if (ch >= '0' && ch <= '9') return ch - '0';
		if (ch >= 'A' && ch <= 'Z') return ch - 'A' + 10;
	}
}

int ch2int(char ch){	
	if (ch >= '0' && ch <= '9') return ch - '0';
	else return ch - 'A' + 10;
}

char int2ch(int x) {
	return x < 10 ? x + '0' : x - 10 + 'A';
}

const int maxn = 200000;
const int maxnum0_9 = 6e6;

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

__device__ inline ull dlowbit(ull x)
{ return x & -x; }

inline ull lowbit(ull x)
{ return x & -x; }

int cnt, tot;

int a[9];

bool mask[1 << N_16][2];
int sed_map[N_16];

struct Sol {
    ull s;
    pair<ull, ull> sol;

    bool operator<(const Sol& x) {
        return s < x.s;
    }
};

vector<Sol> sol0_9;

//字典树数组
// int trieTo[maxnum0_9 * 8][32];
// pair<ull, ull> trieInfo[maxnum0_9 * 8];

void search0_9(int t, int i, ull s){ //搜索最后一段的8个三元组
	if (i == 8) {
        ull high_bit = 0, low_bit = 0; //可选三元组数量超过64位，分段分成两个ull存储
        for (int j = 0 ; j < 8 ; j++)
            if (a[j] < (t >> 1))
                low_bit |= 1ull << a[j];
            else high_bit |= 1ull << (a[j] - (t >> 1));
        sol0_9.pb((Sol){s, mp(high_bit, low_bit)}); //存储所有可能的解
		// TODO: 存储方式改成字典树
        ++tot;
		return;
	}
	int las = i == 0 ? -1 : a[i - 1];
	for (int j = las + 1; j < t; j++)
		if ((tuple0_9[j] & s) == 0) { //要求出现的二元组不交
			a[i] = j;
			search0_9(t, i + 1, s + tuple0_9[j]);
			a[i] = -1;
		}
}

int sol_num;

void search4rows(int x, int i, ull s_all, ull s, pair<ull, ull> tup[105]) {

	if (i == 4) {
		tup[sol_num++] = mp(s_all, s); return;
		//s_all变量记录整个Section中出现的二元组而s仅记录(a,b,c)中的a,b二元组
	}
	
	int j = 0; while (j < 10 && used[j]) j++;
	used[j] = true;
	for (int k = j + 1; k < 10; k++)
		if (!used[k] && !(k == j + 1 && (j & 1) == 0)
            && !mask[(1 << sed_map[k]) + (1 << sed_map[j]) + (1 << sed_map[x])][0]){
			used[k] = true;
			search4rows(x, i + 1, s_all + arcMask[j][k] + arcMask[j][x] + arcMask[k][x], s + arcMask[j][k], tup);
			used[k] = false;
		}
	used[j] = false; 
}

void searchTable(int i, ull s, int g){ 
	if (i == 6) {
		if (g == 11) { //当g=11时意味着在搜索Section13, g=10意味着意味着在搜索Section12
			matching13[n11][0] = matching[11];
			matching13[n11][1] = matching[10]; //需要记录10和11这两个数字在这两个Section中匹配了谁
			Matchings13[n11++] = s;	
		} else {
			matching12[n10][0] = matching[11];
			matching12[n10][1] = matching[10];
			Matchings12[n10++] = s;
		}
		return;
	}
	int j = -1, v = g == 11 ? (1 << sed_map[13]) : (1 << sed_map[12]);
	do {j++;} while (j < 12 && matching[j] != -1); //找到第一个未匹配的数字
	for (int k = j + 1; k < 12; k++){
		if (k == j + 1 && ((j & 1) == 0)) continue; //跳过Section14里的二元组
		if (matching[k] == -1 && !mask[(1 << sed_map[k]) + (1 << sed_map[j]) + v][0]) {
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

pair<int, int> son_blocks[7];

inline int Val2PairId(ull& save_c, ull& c) {
    if (c < (1ull << 16ull)) {
        save_c = c;
        return 0;
    } else if (c < (1ull << 32ull)) {
        save_c = c >> 16ull;
        return 1;
    } else if (c < (1ull << 48ull)) {
        save_c = c >> 32ull;
        return 2;
    } else {
        save_c = c >> 48ull;
        return 3;
    }
}

__device__ __managed__ int d_sed_map[N_16];
__device__ __managed__ Pii d_reverse_map[4][1 << N_16];

__device__ inline int dMax2(int a, int b) {
	return a > b ? a : b;
}

__device__ inline int dMin2(int a, int b) {
	return a > b ? b : a;
}

__device__ inline int dMax3(int a, int b, int c) {
	return dMax2(a, dMax2(b, c));
}

__device__ inline int dMin3(int a, int b, int c) {
	return dMin2(a, dMin2(b, c));
}

inline int Min3(int a, int b, int c) {
	return min(a, min(b, c));
}

inline int Max3(int a, int b, int c) {
	return max(a, max(b, c));
}

void output_pair(ull s, int las, tuple3 sed[])
{
	int len = 0;
    while (s) {
        ull x = lowbit(s), save_c = 0;
        int id = Val2PairId(save_c, x);
		int tmp[3] = {sed_map[reverse_map[id][save_c].first]
            , sed_map[reverse_map[id][save_c].second]
            , sed_map[las]};
        sed[len++] = {Min3(tmp[0], tmp[1], tmp[2])
			, tmp[0] + tmp[1] + tmp[2] - Min3(tmp[0], tmp[1], tmp[2]) - Max3(tmp[0], tmp[1], tmp[2])
			, Max3(tmp[0], tmp[1], tmp[2])};
        s -= x;
    }
}

__device__ __managed__ int d_element0_9[120][3];
__device__ __managed__ int d_log_2[1 << 21];

__device__ void output_triple(ull s, int t, bool high, tuple3 d_sed[], int &d_len)
{
    int offset = high ? t / 2 : 0;
    while (s) {
        ull x = dlowbit(s);
		if (x >= (1ull << (t >> 1ull)))
			assert("Wrong!");
		int id = x < (1ull << 21) ? d_log_2[x] : d_log_2[x >> 21ull] + 21;
		int tmp[3] = {d_sed_map[d_element0_9[id + offset][0]], d_sed_map[d_element0_9[id + offset][1]],
                    d_sed_map[d_element0_9[id + offset][2]]};
        d_sed[d_len++] = {dMin3(tmp[0], tmp[1], tmp[2])
			, tmp[0] + tmp[1] + tmp[2] - dMin3(tmp[0], tmp[1], tmp[2]) - dMax3(tmp[0], tmp[1], tmp[2])
			, dMax3(tmp[0], tmp[1], tmp[2])};
        s -= x;
    }
}

__device__ __managed__ int d_t;

__device__ __managed__ Pii d_son_blocks[Num_16];

__device__ inline void Generate_seeds(tuple3 sedOf13[], tuple3 sedOf12[], tuple3 sedOf11[], tuple3 sedOf10[],
		pair<ull, ull> e, tuple3 d_sed[]) {

    int len = 7; //初始化len，已经填好前7个
    rep (i, 0, len - 1)
        d_sed[i] = {d_son_blocks[i].first, d_son_blocks[i].second, 15}; //前7个固定
	
	rep (i, 0, 5) d_sed[len++] = sedOf13[i];
	rep (i, 0, 5) d_sed[len++] = sedOf12[i];
	rep (i, 0, 4) d_sed[len++] = sedOf11[i];
	rep (i, 0, 4) d_sed[len++] = sedOf10[i];

    ull high_bit = e.first, low_bit = e.second;
    output_triple(low_bit, d_t, false, d_sed, len);
    output_triple(high_bit, d_t, true, d_sed, len);

    //找到A15, 对A15进行处理
    // sort(d_sed, d_sed + d_len);
}

ull c, full_mask;

int t;

inline void Pair2Bit(int j, int k, ull& c, ull& full_mask) {
	arcMask[j][k] = c; //给每个无序二元组设定二进制bit压位
	ull save_c = c;
	int id;
	if (c < (1ull << 16ull)) //根据二进制位反推得到哈希表下标，这里对64位分成4段
		save_c = c, id = 0;
	else if (c < (1ull << 32ull))
		save_c = c >> 16ull, id = 1;
	else if (c < (1ull << 48ull))
		save_c = c >> 32ull, id = 2;
	else save_c = c >> 48ull, id = 3;
	reverse_map[id][save_c] = mp(j, k); //反向记录每个二进制位对应的二元组
	full_mask |= c; //算出所有二元组都存在时的二进制数
	c += c;
}

inline void PRE() {
	c = 1, full_mask = 0;
	//为了后续字典树的插入方便，我们在这里要求10和11的配对二进制位放在高位
	for (int j = 0; j < 10; j++) {
		for (int k = j + 1; k < 10; k++) {
			if (k == j + 1 && (j & 1) == 0) continue; //无需考虑Section14中的二元组
			Pair2Bit(j, k, c, full_mask);
		}
	}

	for (int j = 0; j < 10; j++) {
		for (int k = 10; k < 12; k++) {
			if (k == j + 1 && (j & 1) == 0) continue; //无需考虑Section14中的二元组
			Pair2Bit(j, k, c, full_mask);
		}
	}
	// 10和11配对不需要存储
	// for (int j = 10; j < 12; j++) {
	// 	for (int k = 10; k < 12; k++) {
	// 		if (k == j + 1 && (j & 1) == 0) continue; //无需考虑Section14中的二元组
	// 		Pair2Bit(j, k, c, full_mask);
	// 	}
	// }
    
    for (int i = 2 ; i < (1 << 21) ; i++)
        log_2[i] = log_2[i >> 1] + 1;
}

inline void PRE_SOLVE() {
	
	rep (i, 0, len - 1) {//15 映射成 15
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
		for (int j = i + 1; j < 10; j++) { //枚举所有可能在Section13、Section12中出现的与11、10的匹配
			used[i] = used[j] = true;
			sol_num = 0; search4rows(11, 0, 0, 0, tuple11[i][j]);
			sol_num = 0; search4rows(10, 0, 0, 0, tuple10[i][j]);
			used[i] = used[j] = false;
		}

	t = 0;
    for (int i = 0; i < 8; i++) //预处理出最后一段中可能出现的三元组
		for (int j = i + 1; j < 9; j++)
			for (int k = j + 1; k < 10; k++)
				if (arcMask[i][j] > 0 && arcMask[i][k] > 0 && arcMask[j][k] > 0
                    && !mask[(1 << sed_map[i]) + (1 << sed_map[j]) + (1 << sed_map[k])][0])
                { //mask不需要太理会,用于保证某些三元组不在STS中出现
					tuple0_9[t] = arcMask[i][j] + arcMask[i][k] + arcMask[j][k]; //tuple存储出现的二元组的二进制状态
                    element0_9[t][0] = i; element0_9[t][1] = j; element0_9[t][2] = k;
                    t++;
                }

    printf("The value of t is %d\n", t);
	sol0_9.clear();
	sol0_9.shrink_to_fit();
    // rep (i, 0, maxnum0_9 - 1) {
    //     sol0_9[i].clear();
    //     sol0_9[i].shrink_to_fit();
    // }
	cnt = 0;
    search0_9(t, 0, 0);
    printf("The number of different legal s in [0-9] is %d\n", cnt);
}

__device__ __managed__ int d_CNT = 0;

bool compatiable13_12[3400][3400],
	compatiable13_12_11[3400][3400][70],
	compatiable13_12_10[3400][3400][70];

__device__ __managed__ bool dcompatiable13_12[3400][3400],
	dcompatiable13_12_11[3400][3400][70],
	dcompatiable13_12_10[3400][3400][70];

tuple3 sedOf13[3400][Num_15], sedOf12[3400][Num_15], sedOf11[N_16][N_16][70][Num_15], sedOf10[N_16][N_16][70][Num_15];
__device__ __managed__ tuple3 dsedOf13[3400][Num_15], dsedOf12[3400][Num_15], dsedOf11[N_16][N_16][70][Num_15], dsedOf10[N_16][N_16][70][Num_15];

__device__ inline void dswap(int& a, int& b) {
	a ^= b;
	b ^= a;
	a ^= b;
}

__global__ void Generate_A15(int dn11, int dn10,
	int x_sz, int y_sz, int d_solLength, Sol *d_sol0_9, ull full_mask) {
	// 将核函数改造成将整个枚举过程加入
	int i_s = blockIdx.x * blockDim.x + threadIdx.x;
	int j_s = blockIdx.y * blockDim.y + threadIdx.y;
	tuple3 d_sed[35]; ///Num_15 = 35
	rep (i, i_s * x_sz, dMin2((i_s + 1) * x_sz - 1, dn11)) {
		rep (j, j_s * y_sz, dMin2((j_s + 1) * y_sz - 1, dn10))
			if (dcompatiable13_12[i][j]) {
				int a = dmatching13[i][0];
				int b = dmatching12[j][0];
				if (a > b) dswap(a, b);
				int c = dmatching13[i][1];
				int d = dmatching12[j][1];
				if (c > d) dswap(c, d);
				rep (k, 0, 59)
					if (dcompatiable13_12_11[i][j][k]) {
						rep (m, 0, 59) 
							if (dcompatiable13_12_10[i][j][m] &&
									(dtuple11[a][b][k].first & dtuple10[c][d][m].first) == 0) {
								// printf("%d %d %d %d %d %d %d %d\n", i, j, k, m, a, b, c, d);
								int l = 0, r = d_solLength - 1, ans = r;
								ull s = dMatchings13[i] | dMatchings12[j] |
									dtuple11[a][b][k].first | dtuple10[c][d][m].first;
								s = full_mask ^ s;
								while (l <= r) {
									int mid = (l + r) >> 1;
									if (d_sol0_9[mid].s >= s) {
										r = mid - 1;
										ans = mid;
									} else l = mid + 1;
								}
								// printf("%llu %llu\n", d_sol0_9[ans].s, s);
								while (ans < d_solLength && d_sol0_9[ans].s == s) {
									atomicAdd(&d_CNT, 1);
									// printf("success\n");
									Generate_seeds(dsedOf13[i],
										dsedOf12[j],
										dsedOf11[a][b][k],
										dsedOf10[c][d][m],
										d_sol0_9[ans].sol, d_sed);
									ans++;
								}
							}
				}
			}
	}
}

int main()
{
	cudaDeviceProp prop;
	cudaGetDeviceProperties(&prop, 0);
	printf("Device %d: %s\n", 0, prop.name);
	printf("最大线程块数量: %d\n", prop.maxBlocksPerMultiProcessor);
	printf("每个线程块的最大线程数量: %d\n", prop.maxThreadsPerBlock);
	printf("每个线程块的维度限制: (%d, %d, %d)\n", prop.maxThreadsDim[0], prop.maxThreadsDim[1], prop.maxThreadsDim[2]);
	printf("每个多处理器的最大线程数量: %d\n", prop.maxThreadsPerMultiProcessor);

    //以下所有steiner system以及子结构、孙子结构均要求内部按字典序排序
	freopen("S(2,3,15).txt", "r", stdin);
	// freopen("A14.txt", "w", stdout);

    for (int T = 0 ; T < 1 ; T++) {
		int x = 0; //x映射成12

		for (int i = 0 ; i < Num_15 ; i++) {
			blocks_15[i] = (tuple3){getch(), getch(), getch()};
			if (blocks_15[i].c == 14 && blocks_15[i].b == 13) x = blocks_15[i].a;
		}
		
		if (x == 12) continue;

		int s[N_16]; //s数组代表映射
		rep (i, 0, N_16 - 1) s[i] = i;
		swap(s[x], s[12]);

		for (int i = 0 ; i < Num_15 ; i++) {
			//使其有序
			int tmp[3] = {s[blocks_15[i].a], s[blocks_15[i].b], s[blocks_15[i].c]};
			sort(tmp, tmp + 3);
			blocks_15[i] = {tmp[0], tmp[1], tmp[2]};

			int v = (1 << blocks_15[i].a) | (1 << blocks_15[i].b) | (1 << blocks_15[i].c);
			mask[v][0] = true;
		}
		sort(blocks_15, blocks_15 + Num_15);
	}
    cin.clear();

	PRE();

    len = 0;
    rep (i, 0, Num_15 - 1)
        if (blocks_15[i].c == 13)
            son_blocks[len++] = mp(blocks_15[i].a, blocks_15[i].b);
		else if (blocks_15[i].b == 13)
			son_blocks[len++] = mp(blocks_15[i].a, blocks_15[i].c);
	
	PRE_SOLVE();

	CNT = 0;

	// 预处理cuda中枚举时需要判断的兼容性数组
	for (int i = 0; i < n11; i++)
		for (int j = 0; j < n10; j++)
			if ((Matchings13[i] & Matchings12[j]) == 0){
				ull s = Matchings13[i] | Matchings12[j];
				int a = matching13[i][0];
				int b = matching12[j][0];
				if (a > b) swap(a, b);
				int c = matching13[i][1];
				int d = matching12[j][1];
				if (c > d) swap(c, d);
				compatiable13_12[i][j] = true;
				for (int k = 0; k < 60 ; k++)
					if (tuple11[a][b][k].first != 0 && (s & tuple11[a][b][k].first) == 0){
						compatiable13_12_11[i][j][k] = true;
					}
				for (int l = 0; l < 60 ; l++)
					if (tuple10[c][d][l].first != 0 && (s & tuple10[c][d][l].first) == 0){
						compatiable13_12_10[i][j][l] = true;
					}
			}
	
	rep (i, 0, n11 - 1) {
		output_pair(Matchings13[i], 13, sedOf13[i]);
	}

	rep (i, 0, n10 - 1) {
		output_pair(Matchings12[i], 12, sedOf12[i]);
	}

	rep (i, 0, N_15 - 1)
		rep (j, 0, N_15 - 1)
			rep (k, 0, 59)
				if (tuple11[i][j][k].first != 0)
					output_pair(tuple11[i][j][k].second, 11, sedOf11[i][j][k]);

	rep (i, 0, N_15 - 1)
		rep (j, 0, N_15 - 1)
			rep (k, 0, 59)
				if (tuple10[i][j][k].first != 0)
					output_pair(tuple10[i][j][k].second, 10, sedOf10[i][j][k]);
	
	// 对预处理三元组数组排序
    sort(sol0_9.begin(), sol0_9.end());
    // 拷贝 element0_9
	cudaMemcpy(d_element0_9, element0_9, sizeof(int) * 120 * 3, cudaMemcpyHostToDevice);

	//拷贝mask sed_map
	// cudaMemcpy(d_mask_initial, mask, sizeof(bool) * (1 << 16), cudaMemcpyHostToDevice);
    cudaMemcpy(d_sed_map, sed_map, sizeof(int) * 16, cudaMemcpyHostToDevice);

	//拷贝 log2
	cudaMemcpy(d_log_2, log_2, sizeof(int) * (1 << 21), cudaMemcpyHostToDevice);

	//拷贝 d_son_blocks
	cudaMemcpy(d_son_blocks, son_blocks, sizeof(pair<int, int>) * 7, cudaMemcpyHostToDevice);

	//拷贝 预处理的兼容数组compatiable
	cudaMemcpy(dcompatiable13_12, compatiable13_12, sizeof(compatiable13_12), cudaMemcpyHostToDevice);
	cudaMemcpy(dcompatiable13_12_11, compatiable13_12_11, sizeof(compatiable13_12_11), cudaMemcpyHostToDevice);
	cudaMemcpy(dcompatiable13_12_10, compatiable13_12_10, sizeof(compatiable13_12_10), cudaMemcpyHostToDevice);

	//拷贝d_sol
	Sol *d_sol0_9;
	cudaMalloc(&d_sol0_9, sizeof(Sol) * sol0_9.size());
	cudaMemcpy(d_sol0_9, &sol0_9[0], sizeof(Sol) * sol0_9.size(), cudaMemcpyHostToDevice);
	cudaError_t cudaerr = cudaGetLastError();
	printf("CUDA Error1: \"%s\".\n",
               cudaGetErrorString(cudaerr));

	//拷贝d_t
	cudaMemcpy(&d_t, &t, sizeof(int), cudaMemcpyHostToDevice);

	//拷贝d_son_blocks
	cudaMemcpy(d_son_blocks, &son_blocks[0], sizeof(Pii), cudaMemcpyHostToDevice);

	//拷贝 dMatching dtuple dmatching
	cudaMemcpy(dMatchings13, Matchings13, sizeof(ull) * n11, cudaMemcpyHostToDevice);
	cudaMemcpy(dMatchings12, Matchings12, sizeof(ull) * n10, cudaMemcpyHostToDevice);
	cudaMemcpy(dtuple11, tuple11, sizeof(tuple11), cudaMemcpyHostToDevice);
	cudaMemcpy(dtuple10, tuple10, sizeof(tuple10), cudaMemcpyHostToDevice);
	cudaMemcpy(dmatching13, matching13, sizeof(matching13), cudaMemcpyHostToDevice);
	cudaMemcpy(dmatching12, matching12, sizeof(matching12), cudaMemcpyHostToDevice);

	//拷贝 d_sed
	cudaMemcpy(dsedOf13, sedOf13, sizeof(sedOf13), cudaMemcpyHostToDevice);
	cudaMemcpy(dsedOf12, sedOf12, sizeof(sedOf12), cudaMemcpyHostToDevice);
	cudaMemcpy(dsedOf11, sedOf11, sizeof(sedOf11), cudaMemcpyHostToDevice);
	cudaMemcpy(dsedOf10, sedOf10, sizeof(sedOf10), cudaMemcpyHostToDevice);

	cudaerr = cudaGetLastError();
	printf("CUDA Error2: \"%s\".\n",
               cudaGetErrorString(cudaerr));

	//确定线程分配的任务数
    const dim3 GRID_SIZE(32, 32);
    const dim3 BLOCK_SIZE(32, 32);

	auto st = chrono::steady_clock::now();

	int x_sz = (n11 + 1023) / 1024, y_sz = (n10 + 1023) / 1024;

	cout << x_sz << ' ' << y_sz << ' ' << sol0_9.size() << endl;

    Generate_A15<<<GRID_SIZE, BLOCK_SIZE>>>(n11, n10, x_sz, y_sz, sol0_9.size(), d_sol0_9, full_mask);

	cudaerr = cudaGetLastError();
    if (cudaerr != cudaSuccess)
        printf("kernel failed with error \"%s\".\n",
               cudaGetErrorString(cudaerr));
	cudaDeviceSynchronize();

	auto fi = chrono::steady_clock::now();
	printf("The total elapsed time is ");
	cout << chrono::duration_cast<chrono::milliseconds>(fi - st).count() << endl;

	cudaMemcpy(&CNT, &d_CNT, sizeof(int), cudaMemcpyDeviceToHost);

	printf("The CNT is: %d\n", CNT);

    fclose(stdin);
    fclose(stdout);
	return 0;
}