// test_tree_size.cpp
// 基于 searchAi.cpp 的 CPU 逻辑，实测单个 A_14 候选触发的 ConcatAi(13) 搜索树规模，
// 评估 GPU 版 ConcatAiIter 看门狗 WDOG_LIMIT = 100000 是否会截断真实搜索。
// 统计口径与 GPU 的 local_iters 对齐：ConcatAi 每取一个桶候选（check 调用一次）计 1。
#include <stdio.h>
#include <stdlib.h>
#include <iostream>
#include <algorithm>
#include <string.h>
#include <vector>
#include <unordered_map>
#include <time.h>
using namespace std;
typedef unsigned long long ull;
typedef pair<int, int> Pii;

const int N_16 = 16, N_15 = 15;
const int Num_16 = 140, Num_15 = 35;

struct tuple3
{
    int a, b, c, state;
    tuple3() {}
    tuple3(int a, int b, int c) : a(a), b(b), c(c) { state = (1 << a) + (1 << b) + (1 << c); }
    bool operator<(const tuple3 &x) const
    {
        return a == x.a ? (b == x.b ? (c < x.c) : (b < x.b)) : a < x.a;
    }
} Ai[N_16][Num_15];

int getch()
{
    while (true)
    {
        char ch;
        cin >> ch;
        if (ch >= '0' && ch <= '9') return ch - '0';
        if (ch >= 'A' && ch <= 'Z') return ch - 'A' + 10;
    }
}

template <typename T>
T lowbit(T x) { return x & -x; }

const int maxn = 200000;
const int maxnum0_9 = 6e6;
int matching[N_16];
ull arcMask[N_16][N_16];
int n10, n11;
ull Matchings12[maxn], Matchings13[maxn];
int matching13[maxn][2], matching12[maxn][2];
int used[N_16];
pair<ull, ull> tuple11[16][16][105];
pair<ull, ull> tuple10[16][16][105];
ull tuple0_9[120];
int element0_9[120][3];
Pii reverse_map[4][1 << 18];
vector<pair<ull, ull>> sol0_9[maxnum0_9];
unordered_map<ull, int> id_map;
int cnt;
int a[9];
int mask[1 << N_16 + 1];
bool maskAi[N_16][1 << N_16 + 1];
int sed_map[N_16];
int log_2[1 << 21];
int len;
Pii son_blocks[7];
ull c, full_mask;
int t;

void search0_9(int t_, int i, ull s)
{
    if (i == 8)
    {
        ull high_bit = 0, low_bit = 0;
        if (!id_map.count(s)) id_map[s] = cnt++;
        int id = id_map[s];
        for (int j = 0; j < 8; j++)
            if (a[j] < (t_ >> 1)) low_bit |= 1ull << a[j];
            else high_bit |= 1ull << (a[j] - (t_ >> 1));
        sol0_9[id].push_back(make_pair(high_bit, low_bit));
        return;
    }
    int las = i == 0 ? -1 : a[i - 1];
    for (int j = las + 1; j < t_; j++)
        if ((tuple0_9[j] & s) == 0)
        {
            a[i] = j;
            search0_9(t_, i + 1, s + tuple0_9[j]);
            a[i] = -1;
        }
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
    do { j++; } while (j < 12 && matching[j] != -1);
    for (int k = j + 1; k < 12; k++)
    {
        if (k == j + 1 && ((j & 1) == 0)) continue;
        if (matching[k] == -1 && !mask[(1 << sed_map[k]) + (1 << sed_map[j]) + v])
        {
            matching[j] = k; matching[k] = j;
            searchTable(i + 1, s + arcMask[j][k], g);
            matching[j] = matching[k] = -1;
        }
    }
}

int sol;

void search4rows(int x, int i, ull s_all, ull s, pair<ull, ull> tup[105])
{
    if (i == 4) { tup[sol++] = make_pair(s_all, s); return; }
    int j = 0;
    while (j < 10 && used[j]) j++;
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

inline void PRE()
{
    c = 1; full_mask = 0;
    for (int j = 0; j < 12; j++)
        for (int k = j + 1; k < 12; k++)
        {
            if (k == j + 1 && (j & 1) == 0) continue;
            arcMask[k][j] = arcMask[j][k] = c;
            ull idc = c;
            int idx = 0;
            if (idc >= (1ull << 48ull)) { idc >>= 48ull; idx = 3; }
            else if (idc >= (1ull << 32ull)) { idc >>= 32ull; idx = 2; }
            else if (idc >= (1ull << 16ull)) { idc >>= 16ull; idx = 1; }
            reverse_map[idx][idc] = make_pair(j, k);
            full_mask |= c;
            c += c;
        }
    for (int i = 2; i < (1 << 21); i++) log_2[i] = log_2[i >> 1] + 1;
}

void output_pair(ull s, int las, tuple3 sed[])
{
    while (s)
    {
        ull x = lowbit(s);
        Pii &retPair = (x < (1ull << 16)) ? reverse_map[0][x] : (x < (1ull << 32) ? reverse_map[1][x >> 16] : (x < (1ull << 48) ? reverse_map[2][x >> 32] : reverse_map[3][x >> 48]));
        int tmp[3] = {sed_map[retPair.first], sed_map[retPair.second], sed_map[las]};
        sort(tmp, tmp + 3);
        sed[len++] = tuple3(tmp[0], tmp[1], tmp[2]);
        s -= x;
    }
}

void output_triple(ull s, int t_, bool high, tuple3 sed[])
{
    int offset = high ? t_ / 2 : 0;
    while (s)
    {
        ull x = lowbit(s);
        int id = x < (1ull << 21) ? log_2[x] : log_2[x >> 21] + 21;
        int tmp[3] = {sed_map[element0_9[id + offset][0]], sed_map[element0_9[id + offset][1]], sed_map[element0_9[id + offset][2]]};
        sort(tmp, tmp + 3);
        sed[len++] = tuple3(tmp[0], tmp[1], tmp[2]);
        s -= x;
    }
}

void PRE_SOLVE(int z)
{
    sed_map[14] = 15;
    for (int i = 0; i < len; i++)
    {
        sed_map[i << 1] = son_blocks[i].first;
        sed_map[i << 1 | 1] = son_blocks[i].second;
    }
    memset(matching, -1, sizeof(matching));
    n10 = n11 = 0;
    searchTable(0, 0, 11);
    searchTable(0, 0, 10);
    memset(tuple11, 0, sizeof(tuple11));
    memset(tuple10, 0, sizeof(tuple10));
    for (int i = 0; i < 10; i++)
        for (int j = i + 1; j < 10; j++)
        {
            used[i] = used[j] = true;
            sol = 0; search4rows(11, 0, 0, 0, tuple11[i][j]);
            sol = 0; search4rows(10, 0, 0, 0, tuple10[i][j]);
            used[i] = used[j] = false;
        }
    t = 0;
    for (int i = 0; i < 8; i++)
        for (int j = i + 1; j < 9; j++)
            for (int k = j + 1; k < 10; k++)
                if (arcMask[i][j] > 0 && arcMask[i][k] > 0 && arcMask[j][k] > 0 && !mask[(1 << sed_map[i]) + (1 << sed_map[j]) + (1 << sed_map[k])])
                {
                    tuple0_9[t] = arcMask[i][j] + arcMask[i][k] + arcMask[j][k];
                    element0_9[t][0] = i; element0_9[t][1] = j; element0_9[t][2] = k;
                    t++;
                }
    id_map.clear();
    for (int i = 0; i < maxnum0_9; i++) { sol0_9[i].clear(); sol0_9[i].shrink_to_fit(); }
    cnt = 0;
    search0_9(t, 0, 0);
}

inline void Generate_seeds(ull s13, ull s12, ull s11, ull s10, pair<ull, ull> e, tuple3 sed[])
{
    len = 7;
    for (int i = 0; i < len; i++)
        sed[i] = tuple3(son_blocks[i].first, son_blocks[i].second, 15);
    output_pair(s13, 13, sed);
    output_pair(s12, 12, sed);
    output_pair(s11, 11, sed);
    output_pair(s10, 10, sed);
    output_triple(e.second, t, false, sed);
    output_triple(e.first, t, true, sed);
    sort(sed, sed + len);
    for (int i = 0; i < len; i++)
        sed[i].state = (1 << sed[i].a) + (1 << sed[i].b) + (1 << sed[i].c);
}

const int MatchingNums_0_11 = 10395;
const int Hash0_11Num = 3e6;
int matchings0_11[MatchingNums_0_11][N_16];
int ordMatchings0_11[Hash0_11Num];
int matchings0_11Cnt;

void search0_11Matching(int dep, ull m)
{
    if (dep == 6)
    {
        for (int i = 0; i < 12; i++) matchings0_11[matchings0_11Cnt][i] = matching[i];
        ordMatchings0_11[m] = matchings0_11Cnt;
        matchings0_11Cnt++;
        return;
    }
    int j = -1;
    do { j++; } while (j < 12 && matching[j] != -1);
    for (int i = j + 1; i < 12; i++)
        if (matching[i] == -1)
        {
            matching[j] = i; matching[i] = j;
            search0_11Matching(dep + 1, m * 12 + i);
            matching[i] = matching[j] = -1;
        }
}

struct AzPreEntity
{
    int AzNum;
    int sed[24];
};
vector<AzPreEntity> preSolveAz[N_16][MatchingNums_0_11];
int reorder[N_16][N_16];

// ==== 统计：与 GPU local_iters 对齐的迭代计数 ====
ull g_iters = 0;       // ConcatAi 每取一个候选 +1（= GPU check_linear 调用次数）
ull g_solutions = 0;   // z=6 边界二分命中数（每个算一个 SQS）
ull g_boundary = 0;    // 到达 z=6 的次数

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
    }
    len = 0;
    for (int i = 0; i < Num_15; i++)
        if (Ai[15][i].state & (1 << z))
        {
            int val = Ai[15][i].state - (1 << z);
            int fir = lowbit(val);
            son_blocks[len].first = log_2[fir];
            val -= fir;
            son_blocks[len++].second = log_2[lowbit(val)];
        }
    PRE_SOLVE(z);
    if (z == 14) return;
    int AzCnt = 0;
    for (int i = 0; i < n11; i++)
        for (int j = 0; j < n10; j++)
        {
            if ((Matchings13[i] & Matchings12[j]) == 0)
            {
                ull s = Matchings13[i] | Matchings12[j];
                int aa = matching13[i][0], bb = matching12[j][0];
                if (aa > bb) swap(aa, bb);
                int cc = matching13[i][1], dd = matching12[j][1];
                if (cc > dd) swap(cc, dd);
                for (int k = 0; k < 60; k++)
                    if (tuple11[aa][bb][k].first != 0 && (s & tuple11[aa][bb][k].first) == 0)
                    {
                        s |= tuple11[aa][bb][k].first;
                        for (int l = 0; l < 60; l++)
                            if (tuple10[cc][dd][l].first != 0 && (s & tuple10[cc][dd][l].first) == 0)
                            {
                                s |= tuple10[cc][dd][l].first;
                                ull query_s = full_mask ^ s;
                                if (!id_map.count(query_s)) { s -= tuple10[cc][dd][l].first; continue; }
                                for (auto &e : sol0_9[id_map[query_s]])
                                {
                                    Generate_seeds(Matchings13[i], Matchings12[j], tuple11[aa][bb][k].second,
                                                   tuple10[cc][dd][l].second, e, Ai[z]);
                                    AzPreEntity Az;
                                    Az.AzNum = AzCnt;
                                    int tmpMatching[12] = {0};
                                    int sedCnt = 0;
                                    for (int iSed = 0; iSed < Num_15; iSed++)
                                    {
                                        if ((Ai[z][iSed].state & (1 << 14)) && !(Ai[z][iSed].state & (1 << 15)))
                                        {
                                            int val = Ai[z][iSed].state - (1 << 14);
                                            int firstBit = lowbit(val);
                                            int secondBit = lowbit(val - firstBit);
                                            tmpMatching[reorder[z][log_2[firstBit]]] = reorder[z][log_2[secondBit]];
                                        }
                                        if ((Ai[z][iSed].state & (1 << 14)) || (Ai[z][iSed].state & (1 << 15)))
                                            continue;
                                        Az.sed[sedCnt++] = Ai[z][iSed].state;
                                    }
                                    ull m1 = 0;
                                    for (int ii = 0; ii < 12; ii++)
                                        if (tmpMatching[ii] > ii)
                                            m1 = m1 * 12 + tmpMatching[ii];
                                    preSolveAz[z][ordMatchings0_11[m1]].push_back(Az);
                                    AzCnt++;
                                }
                                s -= tuple10[cc][dd][l].first;
                            }
                        s -= tuple11[aa][bb][k].first;
                    }
            }
        }
    printf("A%d presolved: %d entities\n", z, AzCnt);
    fflush(stdout);
}

ull tuples0_6FullMask;
vector<pair<ull, ull>> tuple0_6states;
int tuples0_6[35][4], triples0_6[35][4], triplesBits2Ord[1 << 8];
ull m1Values[N_16];

tuple3 extract2tuple3(int val)
{
    int a = lowbit(val), b = lowbit(val ^ a), c2 = lowbit(val ^ a ^ b);
    return tuple3(log_2[a], log_2[b], log_2[c2]);
}

inline bool check(AzPreEntity &item, int size, int z)
{
    int highBitsMask = ((1 << N_16) - 1) ^ ((1 << z + 1) - 1);
    for (int i = 0; i < size; i++)
    {
        int highVal = item.sed[i] & highBitsMask;
        if (highVal)
        {
            int s = item.sed[i];
            while (highVal)
            {
                int r = lowbit(highVal);
                if (!maskAi[log_2[r]][s ^ r ^ (1 << z)]) return false;
                highVal ^= r;
            }
        }
        else if (mask[item.sed[i]]) return false;
    }
    return true;
}

void ConcatAi(int z)
{
    if (z == 6)
    {
        static bool tmpMask[1 << N_16];
        memset(tmpMask, 0, sizeof(tmpMask));
        int cntB = 0;
        ull tuples0_6Mask = 0;
        for (int i = 15; i > z; i--)
            for (int j = 0; j < Num_15; j++)
            {
                if (Ai[i][j].state <= (1 << 6) + (1 << 5) + (1 << 4))
                    tuples0_6Mask |= 1ull << (ull)triplesBits2Ord[Ai[i][j].state];
                ull tmp_all = (ull)Ai[i][j].state | (1ull << (ull)i);
                if (tmpMask[tmp_all]) continue;
                cntB++;
                tmpMask[tmp_all] = true;
            }
        tuples0_6Mask ^= tuples0_6FullMask;
        g_boundary++;
        int l = 0, r = tuple0_6states.size() - 1, ans = tuple0_6states.size();
        while (l <= r)
        {
            int mid = (l + r) >> 1;
            if (tuple0_6states[mid].first >= tuples0_6Mask) { r = mid - 1; ans = mid; }
            else l = mid + 1;
        }
        while (ans < (int)tuple0_6states.size() && tuple0_6states[ans].first == tuples0_6Mask)
        {
            g_solutions++;
            ans++;
        }
        return;
    }

    int len_ = 13;
    for (int i = 0; i < len_; i++)
    {
        mask[Ai[z][i].state]++;
        maskAi[z][Ai[z][i].state] = true;
    }
    int matching0_11Ord = ordMatchings0_11[m1Values[z]];
    for (auto &item : preSolveAz[z][matching0_11Ord])
    {
        g_iters++; // 与 GPU 的 ++local_iters 对齐（每取一个候选）
        if (!check(item, Num_15 - len_, z)) continue;
        for (int i = len_; i < Num_15; i++)
        {
            Ai[z][i] = extract2tuple3(item.sed[i - len_]);
            mask[Ai[z][i].state]++;
            maskAi[z][Ai[z][i].state] = true;
        }
        ConcatAi(z - 1);
        for (int i = len_; i < Num_15; i++)
        {
            mask[Ai[z][i].state]--;
            maskAi[z][Ai[z][i].state] = false;
        }
    }
    for (int i = 0; i < len_; i++)
    {
        mask[Ai[z][i].state]--;
        maskAi[z][Ai[z][i].state] = false;
    }
}

inline void GenerateSQS16()
{
    for (int z = 13; z >= 7; z--)
    {
        int len_ = 0;
        int tmpMatching[12] = {0};
        Ai[z][len_++] = tuple3(z ^ 1, 14, 15);
        for (int i = 0; i < Num_15; i++)
        {
            if ((Ai[15][i].state & (1 << z)) && !(Ai[15][i].state & (1 << 14)))
            {
                int val = Ai[15][i].state - (1 << z);
                int tmp = lowbit(val);
                val -= tmp;
                Ai[z][len_++] = tuple3(log_2[tmp], log_2[lowbit(val)], 15);
            }
            if ((Ai[14][i].state & (1 << z)) && !(Ai[14][i].state & (1 << 15)))
            {
                int val = Ai[14][i].state - (1 << z);
                int tmp = lowbit(val);
                val -= tmp;
                Ai[z][len_++] = tuple3(log_2[tmp], log_2[lowbit(val)], 14);
                tmpMatching[reorder[z][Ai[z][len_ - 1].a]] = reorder[z][Ai[z][len_ - 1].b];
            }
        }
        ull m1 = 0;
        for (int i = 0; i < 12; i++)
            if (tmpMatching[i] > i)
                m1 = m1 * 12 + tmpMatching[i];
        m1Values[z] = m1;
    }
    ConcatAi(13);
}

void search0_6Tuples(int dep, int las, ull state, ull triplesSelect)
{
    tuple0_6states.push_back(make_pair(triplesSelect, state));
    if (dep == 10) return;
    for (int i = las + 1; i < cnt; i++)
    {
        int allBitsValue = (1 << tuples0_6[i][0]) + (1 << tuples0_6[i][1]) + (1 << tuples0_6[i][2]) + (1 << tuples0_6[i][3]);
        ull tmpValue = 0;
        for (int j = 0; j < 4; j++)
        {
            int triValue = allBitsValue ^ (1 << tuples0_6[i][j]);
            tmpValue |= 1ull << (ull)triplesBits2Ord[triValue];
        }
        if (triplesSelect & tmpValue) continue;
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
                    tuples0_6[cnt][0] = i; tuples0_6[cnt][1] = j;
                    tuples0_6[cnt][2] = k; tuples0_6[cnt++][3] = l;
                }
    search0_6Tuples(0, -1, 0, 0);
    sort(tuple0_6states.begin(), tuple0_6states.end());
}

int main(int argc, char **argv)
{
    int nA14 = (argc > 1) ? atoi(argv[1]) : 200;
    freopen("../NewS(2,3,15).txt", "r", stdin);
    for (int i = 0; i < Num_15; i++)
    {
        Ai[15][i] = tuple3(getch(), getch(), getch());
        mask[Ai[15][i].state]++;
        maskAi[15][Ai[15][i].state] = true;
    }
    generate0_6Tuples();

    for (int z = 13; z > 6; z--)
    {
        int tmpcnt = 0;
        for (int i = 0; i < N_16 - 2; i++)
            if (i != z && i != (z ^ 1)) reorder[z][i] = tmpcnt++;
    }

    clock_t st = clock();
    for (int z = 13; z >= 7; z--) PreSolveForAi(z);
    PreSolveForAi(14);
    printf("presolve done in %.1f s\n", double(clock() - st) / CLOCKS_PER_SEC);
    fflush(stdout);

    // 枚举前 nA14 个 A_14 候选（与 GPU 相同的 (i,j,k,l,e) 顺序），统计每个的 ConcatAi 树规模
    ull maxIters = 0; ull sumIters = 0; int nTried = 0;
    st = clock();
    for (int i = 0; i < n11 && nTried < nA14; i++)
        for (int j = 0; j < n10 && nTried < nA14; j++)
        {
            if ((Matchings13[i] & Matchings12[j]) == 0)
            {
                ull s = Matchings13[i] | Matchings12[j];
                int aa = matching13[i][0], bb = matching12[j][0];
                if (aa > bb) swap(aa, bb);
                int cc = matching13[i][1], dd = matching12[j][1];
                if (cc > dd) swap(cc, dd);
                for (int k = 0; k < 60 && nTried < nA14; k++)
                    if (tuple11[aa][bb][k].first != 0 && (s & tuple11[aa][bb][k].first) == 0)
                    {
                        s |= tuple11[aa][bb][k].first;
                        for (int l = 0; l < 60 && nTried < nA14; l++)
                            if (tuple10[cc][dd][l].first != 0 && (s & tuple10[cc][dd][l].first) == 0)
                            {
                                s |= tuple10[cc][dd][l].first;
                                ull query_s = full_mask ^ s;
                                if (id_map.count(query_s))
                                    for (auto &e : sol0_9[id_map[query_s]])
                                    {
                                        if (nTried >= nA14) break;
                                        Generate_seeds(Matchings13[i], Matchings12[j], tuple11[aa][bb][k].second,
                                                       tuple10[cc][dd][l].second, e, Ai[14]);
                                        for (int ii = 0; ii < Num_15; ii++)
                                        {
                                            mask[Ai[14][ii].state]++;
                                            maskAi[14][Ai[14][ii].state] = true;
                                        }
                                        g_iters = 0; g_solutions = 0; g_boundary = 0;
                                        GenerateSQS16();
                                        for (int ii = 0; ii < Num_15; ii++)
                                        {
                                            mask[Ai[14][ii].state]--;
                                            maskAi[14][Ai[14][ii].state] = false;
                                        }
                                        nTried++;
                                        if (g_iters > maxIters) maxIters = g_iters;
                                        sumIters += g_iters;
                                        if (g_iters > 100000)
                                            printf("  A14 #%d: iters=%llu (> WDOG 100000 !!!), boundary=%llu, sols=%llu\n",
                                                   nTried, g_iters, g_boundary, g_solutions);
                                    }
                                s -= tuple10[cc][dd][l].first;
                            }
                        s -= tuple11[aa][bb][k].first;
                    }
            }
        }

    printf("\n==== %d A14 candidates tested in %.1f s ====\n", nTried, double(clock() - st) / CLOCKS_PER_SEC);
    printf("ConcatAi iters per A14: max=%llu avg=%llu (WDOG_LIMIT=100000)\n", maxIters, nTried ? sumIters / nTried : 0);
    return 0;
}
