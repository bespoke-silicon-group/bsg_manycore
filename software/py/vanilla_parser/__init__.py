import argparse
import blood_graph
import stats_parser
import pc_histogram
import trace_parser
import vcache_stall_graph

def add_args(parser):
    parser.add_argument("--trace", default="vanilla_operation_trace.csv", type=str,
                        help="Vanilla operation log file")
    parser.add_argument("--stats", default="vanilla_stats.csv", type=str,
                        help="Vanilla stats log file")
    parser.add_argument("--log", default="vanilla.log", type=str,
                        help="Vanilla log file")
    parser.add_argument("--tile", default=False, type=str,
                        help="Vanilla log file")

def main(args):
    pass
