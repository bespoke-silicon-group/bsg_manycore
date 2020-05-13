from __init__ import *

parser = argparse.ArgumentParser(
    description="Argument parser for vanilla_parser"
    prog="vanilla_parser")
add_args(parser)
args = parser.parse_args()

main(args)
