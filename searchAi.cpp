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
// 考虑搜索合法的(A16, A15) pair
#define rep(i, a, b) for (int i = (a); i <= (b); ++i)
#define per(i, a, b) for (int i = (a); i >= (b); --i)
#define pb push_back
#define mp make_pair
#define all(x) x.begin(), x.end()

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

    tuple3() : a(0), b(0), c(0), state(0) {}

    tuple3(int a, int b, int c)
    {
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

ll CNT = 0;

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
const int maxnum0_9 = 6e6;

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
Pii reverse_map[4][1 << 18];

template <typename T>
T lowbit(T x)
{
    return x & -x;
}

using VecUllPair = vector<pair<ull, ull>>;

VecUllPair sol0_9[maxnum0_9];
unordered_map<ull, int> id_map;

int cnt;

int a[9];

int mask[1 << N_16 + 1];
bool maskAi[N_16][1 << N_16 + 1];
int sed_map[N_16];

void search0_9(int t, int i, ull s)
{
    if (i == 8)
    {
        ull high_bit = 0, low_bit = 0;
        if (!id_map.count(s))
            id_map[s] = cnt++;
        int id = id_map[s];
        for (int j = 0; j < 8; j++)
            if (a[j] < (t >> 1))
                low_bit |= 1ull << a[j];
            else
                high_bit |= 1ull << (a[j] - (t >> 1));
        // cout << (*sol0_9)[id].size() << endl;
        sol0_9[id].pb(mp(high_bit, low_bit));
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

int sol;

void search4rows(int x, int i, ull s_all, ull s, pair<ull, ull> tup[105])
{
    if (i == 4)
    {
        tup[sol++] = mp(s_all, s);
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
            search4rows(x, i + 1,
                        s_all + arcMask[j][k] + arcMask[j][x] + arcMask[k][x],
                        s + arcMask[j][k], tup);
            used[k] = false;
        }
    used[j] = false;
}

int log_2[1 << 21];
int len;

Pii &reverseMapBit2Pair(ull x)
{
    if (x < (1ull << 16ull))
        return reverse_map[0][x];
    else if (x < (1ull << 32ull))
        return reverse_map[1][x >> 16ull];
    else if (x < (1ull << 48ull))
        return reverse_map[2][x >> 32ull];
    else
        return reverse_map[3][x >> 48ull];
}

void output_pair(ull s, int las, tuple3 sed[])
{
    while (s)
    {
        ull x = lowbit(s);
        Pii &retPair = reverseMapBit2Pair(x);
        int tmp[3] = {sed_map[retPair.first], sed_map[retPair.second], sed_map[las]};
        sort(tmp, tmp + 3);
        sed[len++] = tuple3{tmp[0], tmp[1], tmp[2]};
        s -= x;
    }
}

void output_triple(ull s, int t, bool high, tuple3 sed[])
{
    int offset = high ? t / 2 : 0;
    while (s)
    {
        ull x = lowbit(s);
        if (x >= (1ull << (t >> 1ull)))
            assert("Wrong!");
        int id = x < (1ull << 21ull) ? log_2[x] : log_2[x >> 21ull] + 21;
        int tmp[3] = {sed_map[element0_9[id + offset][0]],
                      sed_map[element0_9[id + offset][1]], sed_map[element0_9[id + offset][2]]};
        sort(tmp, tmp + 3);
        sed[len++] = tuple3{tmp[0], tmp[1], tmp[2]};
        s -= x;
    }
}

Pii son_blocks[7];

ull c, full_mask;

int t;

inline void PRE()
{
    c = 1, full_mask = 0;
    for (int j = 0; j < 12; j++)
        for (int k = j + 1; k < 12; k++)
        {
            if (k == j + 1 && (j & 1) == 0)
                continue;
            arcMask[k][j] = arcMask[j][k] = c;
            ull idc = c;
            int idx = 0;
            if (idc >= (1ull << 48ull))
                idc >>= 48ull, idx = 3;
            else if (idc >= (1ull << 32ull))
                idc >>= 32ull, idx = 2;
            else if (idc >= (1ull << 16ull))
                idc >>= 16ull, idx = 1;
            reverse_map[idx][idc] = mp(j, k);
            full_mask |= c;
            c += c;
        }

    for (int i = 2; i < (1 << 21); i++)
        log_2[i] = log_2[i >> 1] + 1;
}

void PRE_SOLVE(int z)
{

    sed_map[14] = 15; // 将扣掉的15映射成14
    printf("对于A%d, 子结构如下：\n", z);
    rep(i, 0, len - 1)
    {
        sed_map[i << 1] = son_blocks[i].first;
        sed_map[i << 1 | 1] = son_blocks[i].second;
        cout << son_blocks[i].first << ' ' << son_blocks[i].second << endl;
    }

    memset(matching, -1, sizeof(matching));
    memset(matching12, -1, sizeof(matching12));
    memset(matching13, -1, sizeof(matching13));

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
            sol = 0;
            search4rows(11, 0, 0, 0, tuple11[i][j]);
            sol = 0;
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
    rep(i, 0, maxnum0_9 - 1)
    {
        sol0_9[i].clear();
        sol0_9[i].shrink_to_fit();
    }
    cnt = 0;
    search0_9(t, 0, 0);
    printf("The number of different legal s in [0-9] is %d\n", cnt);
}

inline void Generate_seeds(ull s13, ull s12, ull s11, ull s10, pair<ull, ull> e, tuple3 sed[])
{
    len = 7; // 初始化len，已经填好前7个
    rep(i, 0, len - 1)
        sed[i] = tuple3{son_blocks[i].first, son_blocks[i].second, 15}; // 前7个固定

    output_pair(s13, 13, sed);
    output_pair(s12, 12, sed);

    output_pair(s11, 11, sed);
    output_pair(s10, 10, sed);

    ull high_bit = e.first, low_bit = e.second;
    output_triple(low_bit, t, false, sed);
    output_triple(high_bit, t, true, sed);

    // 对生成的sed的state属性进行设置
    //  for (int i = 0 ; i < Num_15 ; i++)
    //  cout << sed[i].a << ' ' << sed[i].b << ' ' << sed[i].c << endl;
    sort(sed, sed + len);
    for (int i = 0; i < len; i++)
        sed[i].state = (1 << sed[i].a) + (1 << sed[i].b) + (1 << sed[i].c);
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
        return;
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
    int AzNum;
    int sed[24];
};
vector<AzPreEntity> preSolveAz[N_16][MatchingNums_0_11];
int reorder[N_16][N_16], invReorder[N_16][N_16];

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
                if (!maskAi[log_2[r]][item.sed[i] ^ r ^ (1 << z)])
                {
                    return false;
                }
                highVal ^= r;
            }
        }
        else if (mask[item.sed[i]])
        {
            return false;
        }
    }
    return true;
}

ull tuples0_6FullMask;

const int TUPLES0_6LIMIT = 10;
const int TUPLES0_6NUM = 35;
vector<pair<ull, ull>> tuple0_6states;
int tuples0_6[TUPLES0_6NUM][4], triples0_6[TUPLES0_6NUM][4], triplesBits2Ord[1 << 8];

ull m1Values[N_16];

int DEBUGVARIABLE = 0;

tuple3 extract2tuple3(int val)
{
    int a = lowbit(val);
    int b = lowbit(val ^ a);
    int c = lowbit(val ^ a ^ b);
    return tuple3{log_2[a], log_2[b], log_2[c]};
}

void ConcatAi(int z)
{ // 递归拼接Az
    if (z == 6)
    { // 递归到边界：0 直接返回， x 做折半拼接，此时还剩下6个block需要拼接
        bool tmpMask[1 << N_16] = {0};
        int cnt = 0;
        ull tuples0_6Mask = 0; // 计算目前0_6的三元组一共占位了多少
        ull ans_state[Num_16];
        for (int i = 15; i > z; i--)
        {
            for (int j = 0; j < Num_15; j++)
            {
                assert(__builtin_popcount(Ai[i][j].state) == 3);
                assert((Ai[i][j].state & (1 << i)) == 0);

                if (Ai[i][j].state <= (1 << 6) + (1 << 5) + (1 << 4))
                    tuples0_6Mask |= 1ull << (ull)triplesBits2Ord[Ai[i][j].state];
                ull tmp_all = (ull)Ai[i][j].state | (1ull << (ull)i);
                assert(__builtin_popcount(tmp_all) == 4);
                if (tmpMask[tmp_all])
                    continue;
                ans_state[cnt] = tmp_all;
                cnt++;
                tmpMask[tmp_all] = true;
            }
        }
        // 对剩下仅含0-6的block进行拼接, 二分搜索这一半
        tuples0_6Mask ^= tuples0_6FullMask;
        cout << "The tuples0_6Mask is " << tuples0_6Mask << endl;
        int l = 0, r = tuple0_6states.size() - 1, ans = 0;
        while (l <= r)
        {
            int mid = (l + r) >> 1;
            if (tuple0_6states[mid].first >= tuples0_6Mask)
            {
                r = mid - 1;
                ans = mid;
            }
            else
                l = mid + 1;
        }
        cout << "The block have " << cnt << " with ans = " << ans << endl;
        while (ans < tuple0_6states.size() && tuple0_6states[ans].first == tuples0_6Mask)
        {
            DEBUGVARIABLE++;
            if (DEBUGVARIABLE == 20)
                exit(0);
            printf("The %dth SQS(16):\n", DEBUGVARIABLE);
            for (int i = 0; i < cnt; i++)
            {
                ull v = ans_state[i];
                while (v)
                {
                    ull low_v = lowbit(v);
                    cout << int2ch(log_2[low_v]) << " ";
                    v ^= low_v;
                }
                cout << endl;
            }
            ull v = tuple0_6states[ans].second;
            assert(__builtin_popcount(v) == 140 - cnt);
            while (v)
            {
                ull low_v = lowbit(v);
                int idx = (low_v >= (1ull << 18ull)) ? log_2[low_v >> 18ull] + 18 : log_2[low_v];
                for (int j = 0; j < 4; j++)
                    cout << tuples0_6[idx][j] << " ";
                cout << endl;
                v ^= low_v;
            }
            ans++;
        }
        return;
    }

    int len = 13;
    // 处理目前已经有的Az部分的mask
    for (int i = 0; i < len; i++)
    {
        mask[Ai[z][i].state]++;
        maskAi[z][Ai[z][i].state] = true;
    }

    int matching0_11Ord = ordMatchings0_11[m1Values[z]];
    for (auto &item : preSolveAz[z][matching0_11Ord])
    { // 开始拼接剩余部分, 处理mask
        // 检查是否与之前拼接的发生了三元组重复
        if (!check(item, Num_15 - len, z))
            continue;
        for (int i = len; i < Num_15; i++)
        {
            Ai[z][i] = extract2tuple3(item.sed[i - len]);
            mask[Ai[z][i].state]++;
            maskAi[z][Ai[z][i].state] = true;
        }
        ConcatAi(z - 1);
        for (int i = len; i < Num_15; i++)
        {
            mask[Ai[z][i].state]--;
            maskAi[z][Ai[z][i].state] = false;
        }
    }

    // 撤销目前已经有的Az部分的mask
    for (int i = 0; i < len; i++)
    {
        mask[Ai[z][i].state]--;
        maskAi[z][Ai[z][i].state] = false;
    }
}

inline void GenerateSQS16()
{
    cout << "The A14 is:" << endl;
    for (int i = 0; i < Num_15; i++)
    {
        cout << int2ch(Ai[14][i].a) << int2ch(Ai[14][i].b) << int2ch(Ai[14][i].c) << " ";
    }
    cout << endl;

    for (int z = 13; z >= 7; z--)
    {
        int len = 0;
        int tmpMatching[12] = {0};
        Ai[z][len++] = tuple3{z ^ 1, 14, 15};
        for (int i = 0; i < Num_15; i++)
        { // 处理A15和A14与Az的公共部分
            if ((Ai[15][i].state & (1 << z)) && !(Ai[15][i].state & (1 << 14)))
            {
                int val = Ai[15][i].state - (1 << z);
                int tmp = lowbit(val);
                val -= tmp;
                Ai[z][len++] = tuple3{log_2[tmp], log_2[lowbit(val)], 15};
                // cout << "For" << z << ": " << Ai[z][len - 1].a << ' ' << Ai[z][len - 1].b << ' ' << Ai[z][len - 1].c << endl;
            }

            if ((Ai[14][i].state & (1 << z)) && !(Ai[14][i].state & (1 << 15)))
            {
                int val = Ai[14][i].state - (1 << z);
                int tmp = lowbit(val);
                val -= tmp;
                Ai[z][len++] = tuple3{log_2[tmp], log_2[lowbit(val)], 14};
                assert(Ai[z][len - 1].a != (z ^ 1));
                assert(Ai[z][len - 1].b != (z ^ 1));
                tmpMatching[reorder[z][Ai[z][len - 1].a]] = reorder[z][Ai[z][len - 1].b]; // 这一部分只依赖于参数z，因此可以预处理，就不需要整个放入显卡
                // cout << "For" << z << ": " << Ai[z][len - 1].a << ' ' << Ai[z][len - 1].b << ' ' << Ai[z][len - 1].c << endl;
            }
        }
        ull m1 = 0;
        for (int i = 0; i < 12; i++)
        {
            if (tmpMatching[i] > i)
            {
                m1 = m1 * 12 + tmpMatching[i];
            }
            // cout << i << ": " << tmpMatching[i] << endl;
        }
        m1Values[z] = m1;
        cout << m1 << endl;
        assert(ordMatchings0_11[m1] != -1);
        cout << z << " already have " << len << " items." << ", with m1_ord=" << ordMatchings0_11[m1]
             << ", with entity number=" << preSolveAz[z][ordMatchings0_11[m1]].size() << endl;
    }

    ConcatAi(13);
    // exit(0);
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

    if (z == 14) // 14不需要预处理内容
        return;

    int AzCnt = 0; // 给Az进行编号

    for (int i = 0; i < n11; i++)
    {
        for (int j = 0; j < n10; j++)
        {
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
                                                   tuple10[c][d][l].second, e, Ai[z]);
                                    // 开始计算A14,z并将其作为关键字保存到哈希表
                                    // 我们对0-11匹配进行如下Hash：仅考虑matching[i]>i，对i从小到大将matching[i]串起来
                                    AzPreEntity Az;
                                    Az.AzNum = AzCnt;
                                    int tmpMatching[12] = {0};
                                    int sedCnt = 0;
                                    for (int iSed = 0; iSed < Num_15; iSed++)
                                    {
                                        if ((Ai[z][iSed].state & (1 << 14)) &&
                                            !(Ai[z][iSed].state & (1 << 15)))
                                        { // 判断是否是和A14的共同结构
                                            int val = Ai[z][iSed].state - (1 << 14);
                                            int firstBit = lowbit(val);
                                            int secondBit = lowbit(val - firstBit);
                                            assert(log_2[firstBit] != (z ^ 1));
                                            assert(log_2[secondBit] != (z ^ 1));
                                            tmpMatching[reorder[z][log_2[firstBit]]] = reorder[z][log_2[secondBit]];
                                        }

                                        if ((Ai[z][iSed].state & (1 << 14)) ||
                                            (Ai[z][iSed].state & (1 << 15)))
                                            continue;

                                        Az.sed[sedCnt++] = Ai[z][iSed].state; // 将剩下的tuple存到哈希表里
                                    }
                                    assert(sedCnt == 22);
                                    ull m1 = 0;
                                    for (int i = 0; i < 12; i++)
                                        if (tmpMatching[i] > i)
                                            m1 = m1 * 12 + tmpMatching[i];
                                    preSolveAz[z][ordMatchings0_11[m1]].pb(Az);
                                    AzCnt++;
                                }
                                s -= tuple10[c][d][l].first;
                            }
                        s -= tuple11[a][b][k].first;
                    }
            }
        }
    }

    printf("The total number of A%d is %d\n", z, AzCnt);
}

void solveForAi()
{
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

    // 先基于A15的依赖预处理好A7-A13
    // DEBUG z >= 11
    for (int z = 13; z >= 7; z--)
    {
        printf("Now presolve for A%d:\n", z);
        PreSolveForAi(z);
    }

    // 生成A14的预处理
    PreSolveForAi(14);
    // 基于A15开始生成A14，然后开始拼接Az
    for (int i = 0; i < n11; i++)
    {
        for (int j = 0; j < n10; j++)
        {
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
    freopen("out.txt", "w", stdout);

    clock_t st, fi;
    st = clock();

    for (int t = 0; t < 1; t++)
    {
        for (int i = 0; i < Num_15; i++)
        {
            Ai[15][i] = tuple3{getch(), getch(), getch()};
            int v = (1 << Ai[15][i].a) | (1 << Ai[15][i].b) | (1 << Ai[15][i].c);
            mask[v]++;
            maskAi[15][v] = true;
        }
    }
    cin.clear();

    CNT = 0;
    generate0_6Tuples();
    solveForAi();

    printf("The preprocessing of classfing A14 is done, the number of possible A14 is %lld.\n", CNT);

    fi = clock();
    printf("The total elapsed time is %f", double(fi - st) / CLOCKS_PER_SEC);

    fclose(stdin);
    fclose(stdout);
    return 0;
}