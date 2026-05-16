.cpp编译：g++ -O3 searchAi.cpp -o searchAi
.cu编译：nvcc -m64 -Xcompiler -fopenmp -Xptxas -O3,-v **.cu -o **
nohup ./可执行文件 > /dev/null 2>&1 &