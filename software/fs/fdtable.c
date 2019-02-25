#include <errno.h>
#include "fs.h"
#include "fdtable.h"

static lfs_t fdtable[MAX_FDS] = {NULL};
