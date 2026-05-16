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
const int maxnum0_9 = 2e7;

int matching[N_16]; 
ull arcMask[N_16][N_16]; 
int n10, n11;

int m;
ull Matchings12[maxn], Matchings13[maxn];
int matching13[maxn][2]; 
int matching12[maxn][2];

int used[N_16];
pair<ull, ull> tuple11[16][16][105];
pair<ull, ull> tuple10[16][16][105];

ull tuple0_9[120];
int element0_9[120][3];

Pii reverse_map[4][1 << 16];
unordered_map<ull, int> id_map;

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

void search0_9(int t, int i, ull s){
	if (i == 8) {
        ull high_bit = 0, low_bit = 0;
        if (!id_map.count(s))
            id_map[s] = cnt++;
        for (int j = 0 ; j < 8 ; j++)
            if (a[j] < (t >> 1))
                low_bit |= 1ull << a[j];
            else high_bit |= 1ull << (a[j] - (t >> 1));
        sol0_9.pb((Sol){s, mp(high_bit, low_bit)});
        ++tot;
		return;
	}
	int las = i == 0 ? -1 : a[i - 1];
	for (int j = las + 1; j < t; j++)
		if ((tuple0_9[j] & s) == 0){
			a[i] = j;
			search0_9(t, i + 1, s + tuple0_9[j]);
			a[i] = -1;
		}
}

int sol_num;

void search4rows(int x, int i, ull s_all, ull s, pair<ull, ull> tup[105]) {
	if (i == 4) {
		tup[sol_num++] = mp(s_all, s); return;
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
		if (g == 11) {
			matching13[n11][0] = matching[11];
			matching13[n11][1] = matching[10];
			Matchings13[n11++] = s;	
		} else {
			matching12[n10][0] = matching[11];
			matching12[n10][1] = matching[10];
			Matchings12[n10++] = s;
		}
		return;
	}
	int j = -1, v = g == 11 ? (1 << sed_map[13]) : (1 << sed_map[12]);
	do {j++;} while (j < 12 && matching[j] != -1);
	for (int k = j + 1; k < 12; k++){
		if (k == j + 1 && ((j & 1) == 0)) continue;
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

int d_sed_map[N_16];
Pii d_reverse_map[4][1 << N_16];
int t;

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

void output_triple(ull s, int t, bool high, tuple3 d_sed[], int &d_len)
{
    int offset = high ? t / 2 : 0;
    while (s) {
        ull x = lowbit(s);
		if (x >= (1ull << (t >> 1ull)))
			assert("Wrong!");
		int id = x < (1ull << 21) ? log_2[x] : log_2[x >> 21ull] + 21;
		int tmp[3] = {d_sed_map[element0_9[id + offset][0]], d_sed_map[element0_9[id + offset][1]],
                    d_sed_map[element0_9[id + offset][2]]};
        d_sed[d_len++] = {Min3(tmp[0], tmp[1], tmp[2])
			, tmp[0] + tmp[1] + tmp[2] - Min3(tmp[0], tmp[1], tmp[2]) - Max3(tmp[0], tmp[1], tmp[2])
			, Max3(tmp[0], tmp[1], tmp[2])};
        s -= x;
    }
}


inline void Generate_seeds(tuple3 sedOf13[], tuple3 sedOf12[], tuple3 sedOf11[], tuple3 sedOf10[],
		pair<ull, ull> e, tuple3 sed[]) {

    int len = 7; //初始化len，已经填好前7个
    rep (i, 0, len - 1)
        sed[i] = {son_blocks[i].first, son_blocks[i].second, 15}; //前7个固定
	
	rep (i, 0, 5) sed[len++] = sedOf13[i];
	rep (i, 0, 5) sed[len++] = sedOf12[i];
	rep (i, 0, 4) sed[len++] = sedOf11[i];
	rep (i, 0, 4) sed[len++] = sedOf10[i];

    ull high_bit = e.first, low_bit = e.second;
    output_triple(low_bit, t, false, sed, len);
    output_triple(high_bit, t, true, sed, len);

    //找到A15, 对A15进行处理
    // sort(d_sed, d_sed + d_len);
}

ull c, full_mask;

inline void PRE() {
	c = 1, full_mask = 0;
	// reverse_map.clear();
	for (int j = 0; j < 12; j++)
		for (int k = j + 1; k < 12; k++) {
			if (k == j + 1 && (j & 1) == 0) continue;
			arcMask[j][k] = c;
            ull save_c = c;
            int id;
            if (c < (1ull << 16ull))
                save_c = c, id = 0;
            else if (c < (1ull << 32ull))
                save_c = c >> 16ull, id = 1;
            else if (c < (1ull << 48ull))
                save_c = c >> 32ull, id = 2;
            else save_c = c >> 48ull, id = 3;
            reverse_map[id][save_c] = mp(j, k);
            full_mask |= c;
			c += c;
		}
    
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
		for (int j = i + 1; j < 10; j++) {
			used[i] = used[j] = true;
			sol_num = 0; search4rows(11, 0, 0, 0, tuple11[i][j]);
			sol_num = 0; search4rows(10, 0, 0, 0, tuple10[i][j]);
			used[i] = used[j] = false;
		}

	t = 0;
    for (int i = 0; i < 8; i++)
		for (int j = i + 1; j < 9; j++)
			for (int k = j + 1; k < 10; k++)
				if (arcMask[i][j] > 0 && arcMask[i][k] > 0 && arcMask[j][k] > 0
                    && !mask[(1 << sed_map[i]) + (1 << sed_map[j]) + (1 << sed_map[k])][0])
                {
					tuple0_9[t] = arcMask[i][j] + arcMask[i][k] + arcMask[j][k];
                    element0_9[t][0] = i; element0_9[t][1] = j; element0_9[t][2] = k;
                    t++;
                }

    printf("The value of t is %d\n", t);
    id_map.clear();
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


bool compatiable13_12[3400][3400],
	compatiable13_12_11[3400][3400][70],
	compatiable13_12_10[3400][3400][70];


tuple3 sedOf13[3400][Num_15], sedOf12[3400][Num_15], sedOf11[N_16][N_16][70][Num_15], sedOf10[N_16][N_16][70][Num_15];

void Generate_A15(int n11, int n10,
	int solLength, vector<Sol>& sol0_9, ull full_mask) {
	cout << "start searching" << endl;
	int tot = 0;
	rep (i, 0, n11 - 1) {
		rep (j, 0, n10 - 1)
			if (compatiable13_12[i][j]) {
				int a = matching13[i][0];
				int b = matching12[j][0];
				if (a > b) swap(a, b);
				int c = matching13[i][1];
				int d = matching12[j][1];
				if (c > d) swap(c, d);
				tot++;
				rep (k, 0, 59)
					if (compatiable13_12_11[i][j][k]) {
						rep (m, 0, 59) 
							if (compatiable13_12_10[i][j][m] && (tuple11[a][b][k].first & tuple10[c][d][m].first) == 0) {
								int l = 0, r = solLength - 1, ans = r;
								ull s = Matchings13[i] | Matchings12[j] | tuple11[a][b][k].first | tuple10[c][d][m].first;
								s = full_mask ^ s;
								while (l <= r) {
									int mid = (l + r) >> 1;
									if (sol0_9[mid].s >= s) {
										r = mid - 1;
										ans = mid;
									} else l = mid + 1;
								}
								// printf("%d %d %llu %llu\n", ans, i, d_sol0_9[ans].s, d_query_s[i].s);
								// printf("%llu %llu\n", sol0_9[ans].s, s);
								while (ans < solLength && sol0_9[ans].s == s) {
									CNT++;
									// cout << "success" << ' ' << s << endl;
									Generate_seeds(sedOf13[i],
										sedOf12[j],
										sedOf11[a][b][k],
										sedOf10[c][d][m],
										sol0_9[ans].sol, sed);
									ans++;
								}
							}
				}
			}
	}
	cout << "进入判断总数为：" << tot << endl;
}

int main()
{
    //以下所有steiner system以及子结构、孙子结构均要求内部按字典序排序
	freopen("S(2,3,15).txt", "r", stdin);
	// freopen("A14.txt", "w", stdout);

	clock_t st, fi;

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

	// 预处理兼容数组搞出来
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

	st = clock();

    Generate_A15(n11, n10, sol0_9.size(), sol0_9, full_mask);


	fi = clock();
	printf("The total elapsed time is %f\n", double(fi - st) / CLOCKS_PER_SEC);
	printf("%d\n", CNT);

    fclose(stdin);
    fclose(stdout);
	return 0;
}