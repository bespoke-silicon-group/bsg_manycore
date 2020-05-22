from os import path

def add_args(parser):
    parser.add_argument("--trace", default="vanilla_operation_trace.csv", type=str,
                        help="Vanilla operation log file")
    parser.add_argument("--stats", default="vanilla_stats.csv", type=str,
                        help="Vanilla stats log file")
    parser.add_argument("--log", default="vanilla.log", type=str,
                        help="Vanilla log file")
    parser.add_argument("--vcache-trace", default="vcache_operation_trace.csv", type=str,
                        help="Vanilla operation log file")
    parser.add_argument("--vcache-stats", default=None, type=str,
                        help="Vanilla stats log file")
    parser.add_argument("--tile", default=False, type=str,
                        help="Also generate per tile stats")
    parser.add_argument("--tile-group", default=False, type=str,
                        help="Also generate per tile group stats")
    parser.add_argument("--abstract", default=False, action='store_true',
                        help="Type of graphs - abstract / detailed")
    parser.add_argument("--generate-key", default=False, action='store_true',
                        help="Generate a key image with graphs")
    parser.add_argument("--cycle", default="@", type=str,
                        help="Cycle window of bloodgraph/stallgraph as start_cycle@end_cycle.")

def check_exists_and_run(filelist, func, *args):
    """
    Checks if files in filelist exists and executes the func
    """
    for f in filelist:
        if f is None or not path.isfile(f):
            print("Skipping {} as some of {} is missing...".format(
                  func.__module__, filelist))
            return

    print("Running {}...".format(func.__module__))
    func(*args)
