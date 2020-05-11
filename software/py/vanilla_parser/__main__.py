from __init__ import *

parser = argparse.ArgumentParser(description="Argument parser for vanilla_parser")
parser.add_argument("--trace", default="vanilla_operation_trace.csv", type=str,
                    help="Vanilla operation log file")
parser.add_argument("--stats", default="vanilla_stats.csv", type=str,
                    help="Vanilla stats log file")
parser.add_argument("--log", default="vanilla.log", type=str,
                    help="Vanilla log file")

args = parser.parse_args()
