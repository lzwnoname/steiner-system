// count_sol09.cpp — 统计 z=13 形态下 search0_9 的 8-元组解总数与 s 键分布
// （所有 z 的结构规模相同，见 out.txt），用于估算 GPU managed/dAzFlat 显存需求
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <algorithm>
#include <vector>
#include <unordered_map>
#include <iostream>
using namespace std;
typedef unsigned long long ull;
typedef pair<int, int> Pii;

const int Num_15 = 35;
struct T3 { int a, b, c, st; };
T3 A15[Num_15];

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

template <typename T>
T lowbit(T x) { return x & -x; }

int log_2[1 << 21];
ull arcMask[16][16];
int mask[1 << 17];
int sed_map[16];
Pii son_blocks[7];

long long totalSols = 0;
unordered_map<ull, long long> sCount;
int a[8];
ull tup[120];

void dfs(int t, int i, ull s)
{
    if (i == 8) { totalSols++; sCount[s]++; return; }
    int las = i == 0 ? -1 : a[i - 1];
    for (int j = las + 1; j < t; j++)
        if ((tup[j] & s) == 0) { a[i] = j; dfs(t, i + 1, s + tup[j]); a[i] = -1; }
}

int main()
{
    freopen("../NewS(2,3,15).txt", "r", stdin);
    for (int i = 0; i < Num_15; i++)
    {
        int x = getch(), y = getch(), z = getch();
        A15[i] = {x, y, z, (1 << x) + (1 << y) + (1 << z)};
        mask[A15[i].st]++;
    }
    // arcMask
    ull c = 1;
    for (int j = 0; j < 12; j++)
        for (int k = j + 1; k < 12; k++)
        {
            if (k == j + 1 && (j & 1) == 0) continue;
            arcMask[k][j] = arcMask[j][k] = c;
            c += c;
        }
    for (int i = 2; i < (1 << 21); i++) log_2[i] = log_2[i >> 1] + 1;

    // z=13 的 son_blocks / sed_map
    int len = 0;
    for (int i = 0; i < Num_15; i++)
        if (A15[i].st & (1 << 13))
        {
            int val = A15[i].st - (1 << 13);
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
    // tuple0_9
    int t = 0;
    for (int i = 0; i < 8; i++)
        for (int j = i + 1; j < 9; j++)
            for (int k = j + 1; k < 10; k++)
                if (arcMask[i][j] > 0 && arcMask[i][k] > 0 && arcMask[j][k] > 0 && !mask[(1 << sed_map[i]) + (1 << sed_map[j]) + (1 << sed_map[k])])
                    tup[t++] = arcMask[i][j] + arcMask[i][k] + arcMask[j][k];
    printf("t (legal triples in 0-9) = %d\n", t);
    dfs(t, 0, 0);
    printf("total 8-tuple solutions = %lld  -> GPU managed Sol[] = %.2f GB (24 B each)\n",
           totalSols, totalSols * 24.0 / 1e9);
    long long maxPerS = 0;
    for (auto &kv : sCount) maxPerS = max(maxPerS, kv.second);
    printf("distinct s keys = %zu, avg per s = %.1f, max per s = %lld\n",
           sCount.size(), totalSols / (double)sCount.size(), maxPerS);
    printf("\nper-layer entities (CPU measured) = 35,695,773\n");
    printf("  dAzFlat per layer = %.2f GB, 7 layers = %.2f GB (device cudaMalloc)\n",
           35695773 * 100.0 / 1e9, 7 * 35695773 * 100.0 / 1e9);
    printf("  dans temp per layer = %.2f GB (NumsA14*2 = 71,191,546 entities)\n",
           71191546 * 100.0 / 1e9);
    return 0;
}
