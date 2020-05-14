from __init__ import *
import common_args

parser = argparse.ArgumentParser(
    description="Argument parser for vanilla_parser",
    prog="vanilla_parser",
    conflict_handler='error')

common_args.add_args(parser)

# Load command line options of all parser submodules
blood_graph.add_args(
    parser.add_argument_group('Blood graph specific options'))
stats_parser.add_args(
    parser.add_argument_group('Stats parser specific options'))
pc_histogram.add_args(
    parser.add_argument_group('PC histogram specific options'))
vcache_stall_graph.add_args(
    parser.add_argument_group('Vcache stall graph specific options'))

# Parse arguments
args = parser.parse_args()

main(args)
