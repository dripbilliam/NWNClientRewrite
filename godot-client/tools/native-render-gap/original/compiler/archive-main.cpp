#include <cstdio>
extern "C" int cross_tu_fold(int value);
int main(int argc, char **) {
	volatile int input = argc;
	const int result = cross_tu_fold(input);
	std::printf("%d\n", result);
	return result == argc * 3 + 7 ? 0 : 1;
}
