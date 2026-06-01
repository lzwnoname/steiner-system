// 验证输入的 140 个四元组是否构成 SQS(16)
//
// 输入格式：参照 NewS(2,3,15).txt 的风格——每个 block 是 4 个连续的 hex 字符
// （'0'-'9' 表示元素 0-9，'A'-'F' 表示元素 10-15），block 之间用任意空白
// （空格、Tab、换行）分隔。
//
// 用法：
//     ./check                      # 从标准输入读
//     ./check input.txt            # 从文件读
//
// 退出码：0 = 合法 SQS(16)；1 = 不合法（stderr 给出原因）

#include <stdio.h>
#include <iostream>
#include <vector>
#include <array>
#include <set>
#include <algorithm>
using namespace std;

const int N = 16;                     // 元素总数
const int EXPECTED_BLOCKS = 140;      // SQS(16) 的 block 数 = C(16,3)/C(4,3) = 140
const int EXPECTED_TRIPLES = 560;     // C(16,3) = 560

static inline bool isHexChar(char c) {
    return (c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z');
}

static inline int ch2int(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'A' && c <= 'Z') return c - 'A' + 10;
    if (c >= 'a' && c <= 'z') return c - 'a' + 10;
    return -1;
}

int main(int argc, char** argv) {
    if (argc > 1) {
        if (!freopen(argv[1], "r", stdin)) {
            fprintf(stderr, "ERROR: 无法打开文件 %s\n", argv[1]);
            return 1;
        }
    }

    vector<array<int, 4>> blocks;
    char ch;

    // 解析 block：每 4 个 hex 字符一组
    while (cin >> ch) {                       // cin >> 自动跳过空白
        if (!isHexChar(ch)) {
            fprintf(stderr, "ERROR: 遇到非法字符 '%c'（block #%zu）\n",
                ch, blocks.size() + 1);
            return 1;
        }
        int a[4];
        a[0] = ch2int(ch);
        for (int i = 1; i < 4; i++) {
            if (!(cin >> ch) || !isHexChar(ch)) {
                fprintf(stderr, "ERROR: block #%zu 不完整（仅读到 %d 个字符）\n",
                    blocks.size() + 1, i);
                return 1;
            }
            a[i] = ch2int(ch);
        }
        // 校验元素范围与互不相同
        for (int i = 0; i < 4; i++) {
            if (a[i] < 0 || a[i] >= N) {
                fprintf(stderr, "ERROR: block #%zu 含越界元素 %d（要求 ∈ [0,%d)）\n",
                    blocks.size() + 1, a[i], N);
                return 1;
            }
            for (int j = i + 1; j < 4; j++) {
                if (a[i] == a[j]) {
                    fprintf(stderr, "ERROR: block #%zu 含重复元素 %d\n",
                        blocks.size() + 1, a[i]);
                    return 1;
                }
            }
        }
        sort(a, a + 4);
        blocks.push_back({ a[0], a[1], a[2], a[3] });
    }

    // 1) 数量检查
    if ((int)blocks.size() != EXPECTED_BLOCKS) {
        fprintf(stderr, "ERROR: 期望 %d 个 block，实际读到 %zu 个\n",
            EXPECTED_BLOCKS, blocks.size());
        return 1;
    }

    // 2) block 互不重复
    set<array<int, 4>> blockSet(blocks.begin(), blocks.end());
    if ((int)blockSet.size() != EXPECTED_BLOCKS) {
        fprintf(stderr, "ERROR: 存在重复 block（去重后仅 %zu 个不同 block）\n",
            blockSet.size());
        // 列出前若干个重复
        set<array<int, 4>> seen;
        int dupShown = 0;
        for (auto& b : blocks) {
            if (seen.count(b)) {
                if (++dupShown <= 5)
                    fprintf(stderr, "  重复 block: {%d, %d, %d, %d}\n",
                        b[0], b[1], b[2], b[3]);
            } else seen.insert(b);
        }
        return 1;
    }

    // 3) 每个 3-子集恰出现一次：按 state = (1<<a)|(1<<b)|(1<<c) 计数
    static int tripleMark[1 << N];        // 64K * int = 256KB, 全局零初始化
    for (auto& blk : blocks) {
        for (int omit = 0; omit < 4; omit++) {
            int state = 0;
            for (int i = 0; i < 4; i++)
                if (i != omit) state |= (1 << blk[i]);
            tripleMark[state]++;
        }
    }

    int missing = 0, dup = 0;
    int totalTriples = 0;                 // 实际有 3 个 bit 的 state 总数
    for (int s = 0; s < (1 << N); s++) {
        if (__builtin_popcount(s) != 3) continue;
        totalTriples++;
        if (tripleMark[s] == 0) {
            if (++missing <= 10) {
                int e[3], k = 0;
                for (int b = 0; b < N; b++) if (s & (1 << b)) e[k++] = b;
                fprintf(stderr, "  缺失三元组: {%d, %d, %d}\n", e[0], e[1], e[2]);
            }
        } else if (tripleMark[s] > 1) {
            if (++dup <= 10) {
                int e[3], k = 0;
                for (int b = 0; b < N; b++) if (s & (1 << b)) e[k++] = b;
                fprintf(stderr, "  重复三元组: {%d, %d, %d} 在 %d 个 block 中出现\n",
                    e[0], e[1], e[2], tripleMark[s]);
            }
        }
    }

    if (totalTriples != EXPECTED_TRIPLES) {
        fprintf(stderr, "INTERNAL ERROR: 3-子集枚举数 %d ≠ %d\n",
            totalTriples, EXPECTED_TRIPLES);
        return 1;
    }

    if (missing > 0 || dup > 0) {
        fprintf(stderr, "ERROR: %d 个三元组缺失，%d 个三元组在多个 block 中重复出现\n",
            missing, dup);
        fprintf(stderr, "       => 输入不是合法的 SQS(16)\n");
        return 1;
    }

    // 全部通过
    printf("OK: 输入是合法的 SQS(16)。\n");
    printf("    block 数 = %d，覆盖全部 %d 个 3-子集，每个恰出现一次。\n",
        EXPECTED_BLOCKS, EXPECTED_TRIPLES);
    return 0;
}
