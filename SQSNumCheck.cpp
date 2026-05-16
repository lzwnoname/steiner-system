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


struct tuple4{
    int a, b, c, d;
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

int main() 
{
	freopen("SQS16_sample.txt", "r", stdin);
    int x = 6;
    int cnt = 0;
    for (int i = 0 ; i < 140 ; i++) {
        blocks_15[i] = (tuple4){getch(), getch(), getch(), getch()};
        if (blocks_15[i].a <= x && blocks_15[i].b <= x && blocks_15[i].c <= x && blocks_15[i].d <= x)
            cnt++;
    }
    cin.clear();

    cout << cnt << endl;

    fclose(stdin);
	return 0;
}