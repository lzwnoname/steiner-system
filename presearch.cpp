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
} blocks_15[Num_15], sed[Num_15];

int CNT = 0;

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
pair<ull, ull> tuple11[11][11][105];
pair<ull, ull> tuple10[11][11][105];

ull tuple0_9[120];
int element0_9[120][3];
unordered_map<ull, pair<int, int> > reverse_map;

ull lowbit(ull x)
{ return x & -x; }

vector<pair<ull, ull> > sol0_9[maxnum0_9];
unordered_map<ull, int> id_map;

int cnt, tot;

int a[9];

bool b15_mask[1 << N_16];
int sed_map[N_16];

void search0_9(int t, int i, ull s){
	if (i == 8) {
        ull high_bit = 0, low_bit = 0;
        if (!id_map.count(s))
            id_map[s] = cnt++;
        for (int j = 0 ; j < 8 ; j++)
            if (a[j] < (t >> 1))
                low_bit |= 1ull << a[j];
            else high_bit |= 1ull << (a[j] - (t >> 1));
		++tot;
        sol0_9[id_map[s]].pb(mp(high_bit, low_bit));
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
		if (matching[k] == -1 && !b15_mask[(1 << sed_map[k]) + (1 << sed_map[j]) + v]) {
			matching[j] = k;
			matching[k] = j;
			searchTable(i + 1, s + arcMask[j][k], g);
			matching[j] = matching[k] = -1;
		}
	}
}

int sol;

void search4rows(int x, int i, ull s_all, ull s, pair<ull, ull> tup[105]) {
	if (i == 4) {
		tup[sol++] = mp(s_all, s); return;
	}
	
	int j = 0; while (j < 10 && used[j]) j++;
	used[j] = true;
	for (int k = j + 1; k < 10; k++)
		if (!used[k] && !(k == j + 1 && (j & 1) == 0)
            && !b15_mask[(1 << sed_map[k]) + (1 << sed_map[j]) + (1 << sed_map[x])]){
			used[k] = true;
			search4rows(x, i + 1, s_all + arcMask[j][k] + arcMask[j][x] + arcMask[k][x], s + arcMask[j][k], tup);
			used[k] = false;
		}
	used[j] = false; 
}

int log_2[1 << 21];
int len;

void output_pair(ull s, int las)
{
    while (s) {
        ull x = lowbit(s);
		if (!reverse_map.count(x))
			assert("Wrong2!");
		int tmp[3] = {sed_map[reverse_map[x].first], sed_map[reverse_map[x].second], sed_map[las]};
		sort(tmp, tmp + 3);
        sed[len++] = {tmp[0], tmp[1], tmp[2]};
        s -= x;
    }
}

void output_triple(ull s, int t, bool high)
{
    int offset = high ? t / 2 : 0;
    while (s) {
        ull x = lowbit(s);
		if (x >= (1ull << (t >> 1ull)))
			assert("Wrong!");
		int id = x < (1ull << 21) ? log_2[x] : log_2[x >> 21ull] + 21;
		int tmp[3] = {sed_map[element0_9[id + offset][0]], sed_map[element0_9[id + offset][1]],
                    sed_map[element0_9[id + offset][2]]};
        sort(tmp, tmp + 3);
        sed[len++] = {tmp[0], tmp[1], tmp[2]};
        s -= x;
    }
}

pair<int, int> son_blocks[7];

unordered_map<ull, int> matching_num;
int matching_cnt;

void search0_11_matching(int i, ull s) {
	if (i == 6) {
		// cout << s << endl;
        matching_num[s] = matching_cnt++;
		return;
	}
	
	int j = 0; while (j < 12 && used[j]) j++;
	used[j] = true;
	for (int k = j + 1; k < 12; k++)
		if (!used[k]) {
			used[k] = true;
			search0_11_matching(i + 1, s * 12 + k);
			used[k] = false;
		}	
	used[j] = false; 
}

// bitset<220> presave_A14_Z[10395][10395];
tuple3 element0_11[220];
int ele_map_num[1 << N_16];

ull c = 1, full_mask = 0;

int t;

void PRE() {
	
	rep (i, 0, len - 1) {//15 映射成 15
            sed_map[i << 1] = son_blocks[i].first;
            sed_map[i << 1 | 1] = son_blocks[i].second;
			// cout << son_blocks[i].first << ' ' << son_blocks[i].second << endl;
        }

	for (int j = 0; j < 12; j++)
		for (int k = j + 1; k < 12; k++) {
			if (k == j + 1 && (j & 1) == 0) continue;
			arcMask[j][k] = c;
            reverse_map[c] = mp(j, k);
            full_mask |= c;
			c += c;
		}
    
    for (int i = 2 ; i < (1 << 21) ; i++)
        log_2[i] = log_2[i >> 1] + 1;

	memset(matching, -1, sizeof(matching));
	
	n10 = n11 = 0;
	searchTable(0, 0, 11);
    searchTable(0, 0, 10);
    printf("n11 = %d, n10 = %d\n", n11, n10);

    for (int i = 0; i < 10; i++) 
		for (int j = i + 1; j < 10; j++) {
			used[i] = used[j] = true;
			sol = 0; search4rows(11, 0, 0, 0, tuple11[i][j]);
			sol = 0; search4rows(10, 0, 0, 0, tuple10[i][j]);
			used[i] = used[j] = false;
		}

    for (int i = 0; i < 8; i++)
		for (int j = i + 1; j < 9; j++)
			for (int k = j + 1; k < 10; k++)
				if (arcMask[i][j] > 0 && arcMask[i][k] > 0 && arcMask[j][k] > 0
                    && !b15_mask[(1 << sed_map[i]) + (1 << sed_map[j]) + (1 << sed_map[k])])
                {
					tuple0_9[t] = arcMask[i][j] + arcMask[i][k] + arcMask[j][k];
                    element0_9[t][0] = i; element0_9[t][1] = j; element0_9[t][2] = k;
                    t++;
                }

    printf("The value of t is %d\n", t);
    search0_9(t, 0, 0);
    printf("The number of different legal s in [0-9] is %d\n", cnt);
}

int main() 
{
	freopen("S(2,3,15).txt", "r", stdin);
    for (int t = 0 ; t < 1 ; t++) {
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
			b15_mask[v] = true;
		}
		sort(b15_mask, b15_mask + Num_15);
	}
    cin.clear();

    rep (i, 0, Num_15 - 1)
        if (blocks_15[i].c == 13)
            son_blocks[len++] = mp(blocks_15[i].a, blocks_15[i].b);
		else if (blocks_15[i].b == 13)
			son_blocks[len++] = mp(blocks_15[i].a, blocks_15[i].c);
	
	PRE();
	
	int ord = 0; //预处理0-11的三元组并编号
	rep (i, 0, 11)
		rep (j, i + 1, 11)
			rep (k, j + 1, 11) {
				ele_map_num[(1 << i) + (1 << j) + (1 << k)] = ord;
				element0_11[ord++] = {i, j, k};
			}
	
	search0_11_matching(0, 0); //搜索0-11的匹配

	ull ans = 0;
    // freopen("A14_0.txt", "w", stdout);
	set<Pii> tmp; //调试输出预处理表的平均长度用
	// set<ull> tmp;
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
				for (int k = 0; k < 60 ; k++)
					if (tuple11[a][b][k].first != 0 && (s & tuple11[a][b][k].first) == 0){
						s |= tuple11[a][b][k].first;
						for (int l = 0; l < 60 ; l++)
							if (tuple10[c][d][l].first != 0 && (s & tuple10[c][d][l].first) == 0){
								s |= tuple10[c][d][l].first;
								if ((s & full_mask) != s)
									assert("Wrong1!");
                                ull query_s = full_mask ^ s;
								if (!id_map.count(query_s)) {
									s -= tuple10[c][d][l].first;
									continue;
								}
                                for (auto e : sol0_9[id_map[query_s]]) {
                                    len = 7; //初始化len，已经填好前7个
									rep (i, 0, len - 1)
										sed[i] = {son_blocks[i].first, son_blocks[i].second, 15}; //前7个固定

                                    ull s13 = Matchings13[i], s12 = Matchings12[j];                                   
                                    output_pair(s13, 13);
                                    output_pair(s12, 12);

                                    ull s11 = tuple11[a][b][k].second, s10 = tuple10[c][d][l].second;
                                    output_pair(s11, 11);
                                    output_pair(s10, 10);

                                    ull high_bit = e.first, low_bit = e.second;
                                    output_triple(low_bit, t, false);
                                    output_triple(high_bit, t, true);

                                    //找到A14, 对A14进行处理, 找到m和m'并存储
                                    sort(sed, sed + len);
									ans++;
									ull m1 = 0, m2 = 0;
                                    rep (i, 0, Num_15 - 1)
										if (sed[i].c == 12)
											m1 = m1 * 12 + sed[i].b;
										else if (sed[i].c == 14)
											m2 = m2 * 12 + sed[i].b;
									// tmp.insert(m1);
									int m1_ord = matching_num[m1], m2_ord = matching_num[m2];
									if (!tmp.count(mp(m1_ord, m2_ord)))
										tmp.insert(mp(m1_ord, m2_ord));
                                }
								s -= tuple10[c][d][l].first;
							}
						s -= tuple11[a][b][k].first;
					}
			}
	printf("The legal numbers of m1 and m2 is %d\n", tmp.size());
	cout << ans << endl;
	cout<<"END"<<endl;
    fclose(stdin);
    fclose(stdout);
	return 0;
}