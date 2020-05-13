from __init__ import *

parser = argparse.ArgumentParser(
    description="Argument parser for vanilla_parser",
    prog="vanilla_parser",
    conflict_handler='error')

# Load command line options of all parser submodules
blood_graph.add_args(
    parser.add_argument_group('blood_graph'))
stats_parser.add_args(
    parser.add_argument_group('stats_parser'))
pc_histogram.add_args(
    parser.add_argument_group('pc_histogram'))
vcache_stall_graph.add_args(
    parser.add_argument_group('vcache_stall_graph'))

# Overwrite common option with that of __init__.add_args()
add_args(parser)

# Parse arguments
args = parser.parse_args()

main(args)
