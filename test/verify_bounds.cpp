// verify_bounds.cpp — 独立验证 searchAi.cpp / searchAi.cu 的容量与正确性疑点：
//  1. search4rows 填充 tuple11/tuple10 的最大解数（CPU/GPU 遍历上限 60 是否安全）
//  2. n11/n10 是否 <= 3400（GPU sedOf13[3400] 容量）
//  3. m1 哈希（12 元素 perfect matching 的 base-12 编码）是否单射
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <algorithm>
#include <vector>
#include <iostream>
using namespace std;
typedef unsigned long long ull;
typedef pair<int, int> Pii;

const int N_16 = 16, N_15 = 15;
const int Num_15 = 35;

struct tuple3
{
    int a, b, c, state;
    tuple3() {}
    tuple3(int a, int b, int c) : a(a), b(b), c(c) { state = (1 << a) + (1 << b) + (1 << c); }
} Ai[N_16][Num_15];

template <typename T>
T lowbit(T x) { return x & -x; }

int getch()
{
    while (true)
    {
        char ch;
        if (!(cin >> ch)) return -1;
        if (ch >= '0' && ch <= '9') return ch - '0';
        if (ch >= 'A' && ch <= 'Z') return ch - 'A' + 10;
    }
}

int log_2[1 << 21];
ull arcMask[N_16][N_16];
int matching[N_16];
int mask[1 << 17];
int used[N_16];
int sed_map[N_16];
Pii son_blocks[7];
int len;

pair<ull, ull> tuple11[16][16][105];
pair<ull, ull> tuple10[16][16][105];
int sol_num;

void search4rows(int x, int i, ull s_all, ull s, pair<ull, ull> tup[105])
{
    if (i == 4) { tup[sol_num++] = make_pair(s_all, s); return; }
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

int n10, n11;

void searchTable(int i, ull s, int g)
{
    if (i == 6)
    {
        if (g == 11) n11++;
        else n10++;
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

int ordMatchings0_11[3000000];
int matchings0_11Cnt;
bool m1_injective = true;

void search0_11Matching(int dep, ull m)
{
    if (dep == 6)
    {
        if (ordMatchings0_11[m] != -1) m1_injective = false;
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

int main()
{
    freopen("../NewS(2,3,15).txt", "r", stdin);
    for (int i = 0; i < Num_15; i++)
    {
        int a = getch(), b = getch(), c = getch();
        Ai[15][i] = tuple3(a, b, c);
        mask[Ai[15][i].state]++;
    }

    memset(ordMatchings0_11, -1, sizeof(ordMatchings0_11));
    memset(matching, -1, sizeof(matching));
    matchings0_11Cnt = 0;
    search0_11Matching(0, 0);
    printf("[check 3] 12-elem perfect matchings = %d, m1 hash injective: %s\n",
           matchings0_11Cnt, m1_injective ? "YES" : "NO!!!");

    ull c = 1;
    for (int j = 0; j < 12; j++)
        for (int k = j + 1; k < 12; k++)
        {
            if (k == j + 1 && (j & 1) == 0) continue;
            arcMask[k][j] = arcMask[j][k] = c;
            c += c;
        }
    log_2[1] = 0;
    for (int i = 2; i < (1 << 21); i++) log_2[i] = log_2[i >> 1] + 1;

    printf("\n[check 1/2] per-z presolve bounds (sedOf capacity 3400, tuple k-loop limit 60):\n");
    for (int z = 13; z >= 7; z--)
    {
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

        int maxSol11 = 0, maxSol10 = 0, cntAbove60 = 0;
        for (int i = 0; i < 10; i++)
            for (int j = i + 1; j < 10; j++)
            {
                used[i] = used[j] = true;
                sol_num = 0; search4rows(11, 0, 0, 0, tuple11[i][j]);
                if (sol_num > maxSol11) maxSol11 = sol_num;
                if (sol_num > 60) cntAbove60++;
                sol_num = 0; search4rows(10, 0, 0, 0, tuple10[i][j]);
                if (sol_num > maxSol10) maxSol10 = sol_num;
                if (sol_num > 60) cntAbove60++;
                used[i] = used[j] = false;
            }
        printf("  z=%2d: n11=%4d n10=%4d (cap 3400: %s) | max tuple11 sols=%2d, max tuple10 sols=%2d | entries>60: %d\n",
               z, n11, n10, (n11 <= 3400 && n10 <= 3400) ? "OK" : "OVERFLOW!",
               maxSol11, maxSol10, cntAbove60);
    }
    printf("\nAll checks done.\n");
    return 0;
}
