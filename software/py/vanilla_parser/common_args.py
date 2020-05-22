import argparse

def add_args(parser):
    parser.add_argument("--trace", default="vanilla_operation_trace.csv", type=str,
                        help="Vanilla operation log file")
    parser.add_argument("--stats", default="vanilla_stats.csv", type=str,
                        help="Vanilla stats log file")
    parser.add_argument("--log", default="vanilla.log", type=str,
                        help="Vanilla log file")
    parser.add_argument("--tile", default=False, type=str,
                        help="Also generate per tile stats")
    parser.add_argument("--tile-group", default=False, type=str,
                        help="Also generate per tile group stats")
    parser.add_argument("--abstract", default=False, action='store_true',
                        help="Type of graphs - abstract / detailed")
    parser.add_argument("--generate-key", default=False, action='store_true',
                        help="Generate a key image with graphs")
