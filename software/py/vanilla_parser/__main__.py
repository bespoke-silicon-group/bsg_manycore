import argparse
import common
from __init__ import *

msg = """
Argument parser for vanilla_parser
"""

parser = argparse.ArgumentParser(
    description=msg,
    prog="vanilla_parser",
    conflict_handler='error')

common.add_args(parser)

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

common.check_exists_and_run(
    [args.trace, args.stats], blood_graph.main, args)
common.check_exists_and_run(
    [args.trace], pc_histogram.main, args)
common.check_exists_and_run(
    [args.stats], stats_parser.main, args)
common.check_exists_and_run(
    [args.vcache_trace, args.vcache_stats], vcache_stall_graph.main, args)
