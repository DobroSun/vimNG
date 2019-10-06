
all:
	g++ -fPIC -c -Wall main.cpp
	ld -shared main.o -o main_vim.so
