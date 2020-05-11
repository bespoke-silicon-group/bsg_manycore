from __init__ import *

parser = argparse.ArgumentParser(description="Argument parser for vanilla_parser")
parser.add_argument("--trace", default="vanilla_operation_trace.csv", type=str,
                    help="Vanilla operation log file")
parser.add_argument("--stats", default="vanilla_stats.csv", type=str,
                    help="Vanilla stats log file")
parser.add_argument("--log", default="vanilla.log", type=str,
                    help="Vanilla log file")
parser.add_argument("--cycle", default="@", type=str,
                    help="Cycle window of bloodgraph as start_cycle@end_cycle.")
parser.add_argument("--abstract", default=False, action='store_true',
                    help="Type of bloodgraph - abstract / detailed")
parser.add_argument("--generate-key", default=False, action='store_true',
                    help="Generate a key image with blood graph")
parser.add_argument("--no-blood-graph", default=False, action='store_true',
                    help="Skip blood graph generation")

args = parser.parse_args()
