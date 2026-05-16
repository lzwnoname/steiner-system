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
#include <bitset>
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


unordered_map<ull, int> matching_num;
int matching_cnt;

struct tuple3{
    int a, b, c;
	bool operator <(const tuple3& x) const
	{ return a == x.a ? (b == x.b ? (c < x.c) : (b < x.b)) : a < x.a; }
};

int CNT = 0;

int used[N_16];

bitset<220> presave_A14_Z[10395][10395];
tuple3 element0_11[220];
int ele_map_num[1 << N_16];

void search0_11_matching(int i, ull s) {
	if (i == 6) {
        matching_num[s] = matching_cnt++;
		return;
	}
	
	int j = 0; while (j < 12 && used[j]) j++;
	used[j] = true;
	for (int k = j + 1; k < 12; k++)
		if (!used[k]) {
			used[k] = true;
			search0_11_matching(i + 1, s * 10 + j);
			used[k] = false;
		}	
	used[j] = false; 
}

int main() 
{
	search0_11_matching(0, 0);
    cout << matching_cnt;

	int ord = 0;
	rep (i, 0, 11)
		rep (j, i + 1, 11)
			rep (k, j + 1, 11) {
				ele_map_num[(1 << i) + (1 << j) + (1 << k)] = ord;
				element0_11[ord++] = {i, j, k};
			}
	return 0;
}