#include <cstring>
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

class A {
public:
        A(int member = 0) : member(member) {}
        int member;
};

int main(void)
{
        A a;
        a = 2;

        char s[] = "12345";
        if(strlen(s) != 5) {
          bsg_fail();
        }

        bsg_finish();
}
