#include "util.h"

int main()
{
    int a[5] = {'h','e','l','l','o'};
    int b[5] = {'h','e','l','l','o'};

    // Standard exit procedure
    // "verify" is defined in util.h
    return verify(5, a, b);
}

