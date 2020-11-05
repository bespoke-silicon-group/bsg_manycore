#
#   vanilla_stats_parser.py
#
#   vanilla core stats extractor
# 
#   input: vanilla_stats.csv
#   output: stats/manycore_stats.log
#   output: stats/tile/tile_<x>_<y>_stats.log for all tiles 
#   output: stats/tile_group/tile_group_<tg_id>_stats.log for all tile groups
#
#   @author Borna Dustin
#
#   How to use:
#   python3 vanilla_stats_parser.py 
#                       --tile (optional) --tile_group (optional)
#                        --input {vanilla_stats.csv}
#
#   ex) python3 --input vanilla_stats_parser.py --tile --tile_group --input vanilla_stats.csv
#
#   {tile}            Generate separate stats file for each tile default = False
#   {tile_group}      Generate separate stats file for each tile group default = False
#   {input}           Vanilla stats input file     default = vanilla_stats.csv

import sys
import argparse
import functools
import os
import re
import csv
import numpy as np

# Pandas must be at least version 1.0.0 and tabulate must be installed
# This is not uncommon, but do this check to provide a better error message
import pandas as pd
import tabulate
try:
    pd.DataFrame.to_markdown
except:
    raise RuntimeError("Pandas version is not sufficient. Upgrade pandas to > 1.0.0")

from enum import Enum
from collections import Counter
from . import common


# CudaStatTag class 
# Is instantiated by a packet tag value that is recieved from a 
# bsg_cuda_print_stat(tag) insruction
# Breaks down the tag into (type, y, x, tg_id, tag>
# type of tag could be start, end, stat
# x,y are coordinates of the tile that triggered the print_stat instruciton
# tg_id is the tile group id of the tile that triggered the print_stat instruction
# Formatting for bsg_cuda_print_stat instructions
# Section                 stat type  -   y cord   -   x cord   -    tile group id   -        tag
# of bits                <----2----> -   <--6-->  -   <--6-->  -   <------14----->  -   <-----4----->
# Stat type value: {"Kernel Start":0, "Kernel End": 1, "Tag Start":2, "Tag End":3}

# The CudaStatTag class encapsulates the tag argument used by bsg_cuda_print_stat_*
# commands inside of bsg_manycore/software/bsg_manycore_lib/bsg_manycore.h.
# There are four commands:

#  bsg_cuda_print_stat_kernel_start() - Annotates the start of the kernel being profiled
#  bsg_cuda_print_stat_kernel_end()   - Annotates the end of the kernel being profiled
#  bsg_cuda_print_stat_start(tag)     - Annotates the start of a tagged section of the kernel being profiled
#  bsg_cuda_print_stat_end(tag)       - Annotates the end of a tagged section of the kernel being profiled

# Calls to bsg_cuda_print_stat_start(tag) and bsg_cuda_print_stat_kernel_start()
# must be called first be paired with a matching call to
# bsg_cuda_print_stat_end(tag) and bsg_cuda_print_stat_kernel_end().
class CudaStatTag:
    # These values are used by the manycore library in bsg_print_stat instructions
    # they are added to the tag value to determine the tile group that triggered the stat
    # and also the type of stat (stand-alone stat, start, or end)
    # the value of these paramters should match their counterpart inside 
    # bsg_manycore/software/bsg_manycore_lib/bsg_manycore.h
    _TAG_WIDTH   = 4
    _TAG_INDEX   = 0
    _TAG_MASK   = ((1 << _TAG_WIDTH) - 1)
    _TG_ID_WIDTH = 14
    _TG_ID_INDEX = _TAG_WIDTH + _TAG_INDEX
    _TG_ID_MASK = ((1 << _TG_ID_WIDTH) - 1)
    _X_WIDTH     = 6
    _X_MASK     = ((1 << _X_WIDTH) - 1)
    _X_INDEX     = _TG_ID_WIDTH + _TG_ID_INDEX
    _Y_WIDTH     = 6
    _Y_INDEX     = _X_WIDTH + _X_INDEX
    _Y_MASK     = ((1 << _Y_WIDTH) - 1)
    _TYPE_WIDTH  = 2
    _TYPE_INDEX  = _Y_WIDTH + _Y_INDEX
    _TYPE_MASK   = ((1 << _TYPE_WIDTH) - 1)

    class StatType(Enum):
        START = 0
        END = 1
        KERNEL_START   = 2
        KERNEL_END     = 3

    def __init__(self, tag):
        """ Initialize a CudaStatTag object """
        self.__s = tag;
        self.__type = self.StatType((self.__s >> self._TYPE_INDEX) & self._TYPE_MASK)

    @property
    def tag(self):
        """ Get the tag associated with this object """
        return ((self.__s >> self._TAG_INDEX) & self._TAG_MASK)

    @property
    def getTag(self):
        """ Get the tag associated with this object """
        if(self.__type == self.StatType.KERNEL_START or
           self.__type == self.StatType.KERNEL_END):
            return "Kernel"
        return ((self.__s >> self._TAG_INDEX) & self._TAG_MASK)

    @property 
    def tg_id(self):
        """ Get the Tile-Group ID associated with this object """
        return ((self.__s >> self._TG_ID_INDEX) & self._TG_ID_MASK)

    @property 
    def getTileGroupID(self):
        """ Get the Tile-Group ID associated with this object """
        return ((self.__s >> self._TG_ID_INDEX) & self._TG_ID_MASK)

    @property 
    def x(self):
        """ Get the X Coordinate associated with this object """
        return ((self.__s >> self._X_INDEX) & self._X_MASK)

    @property 
    def y(self):
        """ Get the Y Coordinate associated with this object """
        return ((self.__s >> self._Y_INDEX) & self._Y_MASK)

    @property 
    def getAction(self):
        """ Get the Action that this object defines"""
        return "Start" if self.__type in {self.StatType.KERNEL_START, self.StatType.START} else "End"

    @property 
    def statType(self):
        """ Get the StatType that this object defines"""
        return self.__type

    @property 
    def isStart(self):
        """ Return true if this object corresponds to a call to
        bsg_cuda_print_stat_start """
        return (self.__type == self.StatType.START)

    @property 
    def isEnd(self):
        """ Return true if this object corresponds to a call to
        bsg_cuda_print_stat_end """
        return (self.__type == self.StatType.END)

    @property 
    def isKernelStart(self):
        """ Return true if this object corresponds to a call to
        bsg_cuda_print_stat_kernel_start """
        return (self.__type == self.StatType.KERNEL_START)

    @property 
    def isKernelEnd(self):
        """ Return true if this object corresponds to a call to
        bsg_cuda_print_stat_kernel_end """
        return (self.__type == self.StatType.KERNEL_END)

# Create the ManycoreCoordinate class, a surprisingly useful wrapper
# for a tuple. Access the y and x fields using var.y and var.x
from collections import namedtuple
ManycoreCoordinate = namedtuple('ManycoreCoordinate', ['y', 'x'])

# The challenge in the victim cache parser is order of
# iterations. Simply described:
# 
# Each time a tile executes a start/end call with a
# particular, it is an iteration of that tag.
#
# 0. Tiles iterate and can call start/end multiple times
# 1. Cals to start/end define an iteration order for that tile
# 2. Packets from a single tile arrive at the host in tile iteration order
# 3. Packets from multiple tiles arrive interleaved
# 4. The tile iteration number at the host is not necessarily monotonic
#    (That is - the tiles are not necessarily executing the same iteration)
# 
# An iteration-consistent order must be reconstructed
# so that start/end calls do not count operations
# outside of the window defined by their tag.
# 
# The following lines enumerate an iteration order for
# start/end calls from each tile.
class CacheStatsParser:

    # The field_is_* stall methods return true if a field from the CSV
    # is of the type requested. Use these for filtering operations
    @classmethod
    def field_is_stall(cls, op):
        return op.startswith("stall_")

    @classmethod
    def field_is_dma(cls, op):
        return op.startswith("dma_")

    @classmethod
    def field_is_miss(cls, op):
        return op.startswith("miss_")

    @classmethod
    def field_is_mgmt(cls, op):
        return (op.startswith("instr_tag")
                or (op.startswith("instr_a")
                    and not cls.field_is_amo(op)))

    @classmethod
    def field_is_load(cls, op):
        return op.startswith("instr_ld")

    @classmethod
    def field_is_store(cls, op):
        return op.startswith("instr_s")

    @classmethod
    def field_is_amo(cls, op):
        return op.startswith("instr_amo")

    @classmethod
    def field_is_event_counter(cls, op):
        return (cls.field_is_dma(op) or op == "total_dma"
                or cls.field_is_miss(op) or op == "total_miss")

    @classmethod
    def field_is_cycle_counter(cls, op):
        return (cls.field_is_stall(op) or op == "total_stalls"
                or cls.field_is_load(op) or op == "total_loads"
                or cls.field_is_store(op) or op == "total_stores"
                or cls.field_is_amo(op) or op == "total_atomics"
                or cls.field_is_mgmt(op) or op == "total_mgmt"
                or op == "global_ctr")

    # Parse the raw tag column into Tag, Action, and Tile Coordinate columns
    @classmethod
    def parse_raw_tag(cls, df):
        # Parse raw_tag data using CudaStatTag
        cst = df.raw_tag.map(CudaStatTag)

        p = pd.DataFrame()
        # Update the table with information parsed from CudaStatTag
        p["Tile Group ID"] = cst.map(lambda e: e.getTileGroupID)
        p["Tag"] = cst.map(lambda e: e.getTag)
        p["Action"] = cst.map(lambda e: e.getAction)
        p["Tile Coordinate (Y,X)"] = cst.map(lambda e: ManycoreCoordinate(e.y, e.x))

        return p

    # Get device-level characteristics: dim, origin
    @classmethod
    def parse_dev_characteristics(cls, df):
        dim = ManycoreCoordinate(
            df["Tile Coordinate (Y,X)"].map(lambda l: l.y).max() + 1,
            df["Tile Coordinate (Y,X)"].map(lambda l: l.x).max() + 1)

        origin = ManycoreCoordinate(
            df["Tile Coordinate (Y,X)"].map(lambda l: l.y).min(),
            df["Tile Coordinate (Y,X)"].map(lambda l: l.x).min())

        return (dim, origin)

    # Use the vcache column (which contains indexes, embedded in
    # strings) into ManycoreCoordinate objects, and return them as a
    # new column
    @classmethod
    def parse_cache_coordinates(cls, df, dim, origin):
        cache_names = df.vcache.unique()
        ncaches = len(cache_names)
        if(not ncaches == (dim.x * 2)):
            raise RuntimeError("Number of caches in the cache stats file must "
                               "be two times the X-Dimension of the manycore. "
                               f"Got {ncaches}.")

        # The CSV contains a string representing the cache's
        # path in the hierarchy, not the (Y,X) location, so we
        # map the string to a (Y,X) coordinate and create a
        # new column in the table.
        cache_ys = [0] * (ncaches//2) + [dim[0]] * (ncaches//2)
        cache_xs = [*range(ncaches//2), *range(ncaches//2)]
        cache_coords = zip(cache_ys, cache_xs)
        cache_coord_map = {c:i for c, i in zip(cache_names,cache_coords)}
        return df.vcache.map(cache_coord_map)

    # Infer labels each line in the dataframe with the iteration
    # number for that tile and tag.
    #
    # The way this is done is by hierarchical grouping in
    # Pandas. We can think of each tile's iterations as a
    # group of lines in the csv file, and we need to label
    # each line with it's iteration. 
    @classmethod
    def parse_label_iterations(cls, df):
        # We create a hierarchy with the following
        # levels (top to bottom):
        hierarchy = ["Action", "Tag", "Tile Coordinate (Y,X)", "Cache Coordinate (Y,X)"]

        # At the bottom, the "Cache Coordinate (Y,X)" group
        # will have n entries, where n is the number of times
        # that action was called, with that tag, by the
        # particular tile.
        #
        # Enumerating the n rows, produces a Tile-Tag
        # Iteration number for each row.
                
        # We group the data hierarchically, as described above
        groups = df.groupby(hierarchy)

        # Then we enumerate the iterations using cumcount().
        iterations = groups.cumcount()

        return iterations
        
    def __init__(self, vcache_input_file):
        d = pd.read_csv(vcache_input_file)

        # Fail if the metadata is not in the header.
        meta = ["vcache", "tag"]
        if(not all(f in d.columns.values for f in meta)):
            raise RuntimeError("Metadata fields not in header of CSV")

        # Rename from tag, to raw_tag to avoid confusion. "tag" in
        # this context is the unparsed data from the packet.
        d = d.rename(columns={"tag": "raw_tag"})

        # Rename columns with totals to avoid confusion
        d = d.rename(columns={"instr_ld": "total_loads",
                              "instr_st": "total_stores",
                              "instr_atomic": "total_atomics"
                          })

        # Compute Stall, Mgmt, DMA, and Miss totals. These are not
        # computed in Verilog, but Stores, Atomics, and load
        # operations are.

        # Parse out the operations we care about
        header = d.columns.values
        self._mgmt = [f for f in header if self.field_is_mgmt(f)]

        self._stalls = [f for f in header if self.field_is_stall(f)]

        self._misses = [f for f in header if self.field_is_miss(f)]
        self._dmas = [f for f in header if self.field_is_dma(f)]

        d['total_stalls'] = d[self._stalls].sum(axis="columns")
        d['total_mgmt'] = d[self._mgmt].sum(axis="columns")
        d['total_miss'] = d[self._misses].sum(axis="columns")
        d['total_dma'] = d[self._dmas].sum(axis="columns")


        # Parse raw tag data into Action, Tag, and Tile Coordinate (Y,X), 
        # and Tile Group Columns
        d = pd.concat([d, self.parse_raw_tag(d)], axis='columns')

        # Parse the device dimension and origin from Tile Coordinate (Y,X)
        (dim, origin) = self.parse_dev_characteristics(d)

        # Use the vcache column (which contains indexes, embedded in
        # strings) into ManycoreCoordinate objects, and put them in a
        # new column
        d["Cache Coordinate (Y,X)"] = self.parse_cache_coordinates(d, dim, origin)

        # Create a column with the Tile-Tag iterations (see comment)
        # All of the magic happens here.
        d["Tile-Tag Iteration"] = self.parse_label_iterations(d)

        # Drop the columns that no longer contain useful data.
        d = d.drop(["raw_tag", "vcache", "time"], axis="columns")

        # Parse the aggregate stats (for the device)
        self.agg = AggregateCacheStats(d)
        # Parse the aggregate stats (for each group)
        self.group = GroupCacheStats(d)

        # Finally, save d and parse the Tag, Bank, and Group data
        self._origin = origin
        self._dim = dim
        self.d = d.copy();

# Cache Stats is the parent class for CacheTagStats, CacheBankStats,
# It contains reusable functionality, but doesn't actually do any
# parsing or computation.
class CacheStats:
    def __init__(self, name, df):
        self._name = name
        self._df = df.copy()
    
        header = df.columns.values

        # Classify operations in the header
        self._loads = [f for f in header if CacheStatsParser.field_is_load(f)]
        self._stores = [f for f in header if CacheStatsParser.field_is_store(f)]
        self._atomics = [f for f in header if CacheStatsParser.field_is_amo(f)]
        self._mgmt = [f for f in header if CacheStatsParser.field_is_mgmt(f)]

        self._stalls = [f for f in header if CacheStatsParser.field_is_stall(f)]

        self._misses = [f for f in header if CacheStatsParser.field_is_miss(f)]
        self._dmas = [f for f in header if CacheStatsParser.field_is_dma(f)]

        self._ops = [*self._mgmt, *self._atomics, *self._stores, *self._loads]

        # Create a dictionary mapping operation to operation type
        # global_ctr is just a cycle counter
        self._op_type_map = dict({*[(l,"Load") for l in [*self._loads, "total_loads"]],
                                  *[(s,"Store") for s in [*self._stores, "total_stores"]],
                                  *[(t,"Management") for t in [*self._mgmt, "total_mgmt"]],
                                  *[(a,"Atomic") for a in [*self._atomics, "total_atomics"]],
                                  *[(s,"Stall") for s in [*self._stalls, "total_stalls"]],
                                  *[(m,"Miss") for m in [*self._misses, "total_miss"]],
                                  *[(d,"DMA") for d in [*self._dmas, "total_dma"]],
                                  ("global_ctr", "Cycles")
                              })

    # Find mismatched calls to start/end
    #
    # Returns mismatches, a MultiIndex containing the list of
    # mismatches.
    def find_mismatches(self, s, e):
        # Subtracting the start and end dataframes will match
        # groups. If a group in the start or end dataframe is
        # missing a row/index then it will insert a row of
        # NaNs at the cooresponding index in the output that
        # we can use to print an error.
        diff = e.sort_index() - s.sort_index()
        
        # Find rows with NaNs
        mismatches = diff[diff.isnull().any(axis="columns")].index
                
        # If mismatches is not empty, then there is a row of
        # NaNs, described above.
        return list(mismatches)

    # Sort the tags so that "Kernel" is last, followed by the
    # tags in sorted order.
    @classmethod
    def _sort_tags(cls, tags):
        tags = list(tags)

        if "Kernel" in tags:
            tags.remove("Kernel")
            tags.sort()
            tags = tags + ["Kernel"]
        else:
            tags.sort()

        return tags

    def __str__(self):
        return self._name

    # Create a string of length l with n (name) centered in the
    # middle, and padded by c (characters)
    @classmethod
    def _fill(cls, n, l, c):
        if(len(c) != 1):
            raise ValueError("Argument 'c' must be a character")
        l -= len(n)
        lpre = l // 2
        lpost = (l + 1) // 2
        s = (c * lpre) + n + (c * lpost)
        return s
    
    # Create section separator, of length l with name n
    @classmethod
    def _make_sec_sep(cls, n, l):
        return cls._fill(" " + n + " ", l, "#")

    # Create tag separator, of length l with name tag
    @classmethod
    def _make_tag_sep(cls, tag, l):
        t = f" Tag: {tag} "
        return cls._fill(t, l, "=")
        
    # Create sub-separator, of length l with name n
    @classmethod
    def _make_sub_sep(cls, n, l):
        return cls._fill(n, l, "-")



class CacheTagStats(CacheStats):

    def __init__(self, name, df):
        super().__init__(name, df)
        # Tag statistics are aggregated across banks. We use Tile-Tag
        # Iteration at the bottom of the hierarchy so that lines that
        # were printed by the same packet, i.e. different cache banks,
        # are grouped together and can be aggregated.
        #
        # Then, for per-tag statistics we take the sum of the lowest
        # group, to get aggregate the counters across all banks.
        hierarchy = ["Action", "Tag", "Tile Coordinate (Y,X)", "Tile-Tag Iteration"]
        banksums = df.groupby(hierarchy).sum()

        # Split into Start/End 
        starts = banksums.loc["Start"]
        ends = banksums.loc["End"]
        
        # Find mismatched start and end pairs
        mismatches = self.find_mismatches(starts, ends)
        if(list(mismatches)):
            raise RuntimeError("Unpaired calls to Start/End detected."
                               f" Check the following: {tuple(mismatches.names)}:"
                               f"{list(mismatches)}")

        # For all tag iterations, find the minium arrival time
        # for the start packet for that iteration

        # We will use groups again to do this. Group together
        # matching iterations at the bottom of the hierarchy,
        # and find the earliest arrived packet (for Starts),
        # and the latest arrived packet (for Ends).

        # The getmin/getmax functions below are general. They
        # will do what is described above. BUT, they are slow,
        # and unnecessary

        # getmin = lambda df: df.loc[df["global_ctr"].idxmin()]
        # tag_starts = tag_starts.groupby(["tag", "Tile-Tag Iteration"]).apply(getmin)
        # bank_starts = bank_starts.groupby(["tag", "Cache Coordinate (Y,X)", "Tile-Tag Iteration"]).apply(getmin)

        # Instead: Groupby maintains the relative order of rows within
        # a group, and the rows in the table were already in order
        # because they were already printed in order!

        # We use first() to get the first row, which
        # is also the earliest. No need to search for min/max
        # if an O(1) operation exists!
        starts = starts.groupby(["Tag", "Tile-Tag Iteration"]).first()

        # Same as above. Slow, unnecessary:
        # getmax = lambda df: df.loc[df["global_ctr"].idxmax()]
        # tag_ends = tag_ends.groupby(["tag", "Tile-Tag Iteration"]).apply(getmax)
        # bank_ends = bank_ends.groupby(["tag", "Cache Coordinate (Y,X)", "Tile-Tag Iteration"]).apply(getmax)

        # As above, groupby maintains order within groups so
        # we can just use last().
        ends = ends.groupby(["Tag", "Tile-Tag Iteration"]).last()

        # Finally, subtract all ends from starts and sum.
        results = (ends - starts).groupby("Tag").sum()
        
        # Save the result
        self.df = results


    # Parse the results into a pretty table
    def __prettify(self, df):
        doc = ""
        # Transpose so that columns are tags. Then we can easily see sums
        pretty = df.T

        # Sort into Events and Cycles
        counter_map = dict({*[(e,"Event") for e in pretty.index
                              if CacheStatsParser.field_is_event_counter(e)],
                            *[(c, "Cycle") for c in pretty.index
                              if CacheStatsParser.field_is_cycle_counter(c)]})
        pretty["Counter Type"] = pretty.index.map(counter_map)

        # Classify operations by type
        pretty['Operation Type'] = pretty.index.map(self._op_type_map)

        # Rename the rows that contain totals to "Total"
        istotal = lambda op: op.startswith("total") or op == "global_ctr"
        totals_map = {op:"Total" for op in pretty.index.values if istotal(op)}
        pretty = pretty.rename(mapper=totals_map)

        # Re-index the table. This creates a hierarchical table where
        # operations are grouped by Counter type (Event, or Cycle) and
        # Operation type (e.g. Atomic).
        pretty['Name'] = pretty.index
        pretty = pretty.set_index(["Counter Type", "Operation Type", "Name"])
        pretty = pretty.sort_index(level=[0, 1, 2], ascending=[True, True, False])

        # Sort the columns so that "Kernel" is last.
        srtd = self._sort_tags(pretty.columns)

        pretty = pretty.reindex(srtd, axis=1)

        doc += "Table Rows:\n"
        doc += "\tLoad Operations:\n"
        doc += "\t\t-instr_ld_l[wu,w,hu,h,du,d,bu,b]: Load [w]ord/[h]alf/[b]yte/[d]ouble [u]nsigned/[]signed\n"
        doc += "\tStore Operations:\n"
        doc += "\t\t-instr_sm_s[w,h,d,b]: Store [w]ord/[h]alf/[b]yte/[d]ouble\n"
        doc += "\tCache Management Operations:\n"
        doc += "\t\t-instr_tagst: Tag Store (Not caused by Vanilla Core)\n"
        doc += "\t\t-instr_tagfl: Tag Flush (Not caused by Vanilla Core)\n"
        doc += "\t\t-instr_taglv: Tag Load Valid (Not caused by Vanilla Core)\n"
        doc += "\t\t-instr_tagla: Tag Load Address (Not caused by Vanilla Core)\n"
        doc += "\t\t-instr_afl: Address Flush (Not caused by Vanilla Core)\n"
        doc += "\t\t-instr_aflinv: Address Flush Invalidate (Not caused by Vanilla Core)\n"
        doc += "\t\t-instr_ainv: Address Invalidate (Not caused by Vanilla Core)\n"
        doc += "\t\t-instr_alock: Address Lock (Not caused by Vanilla Core)\n"
        doc += "\t\t-instr_aunlock: Address Unlock (Not caused by Vanilla Core)\n"
        doc += "\t RISC-V Atomic Operations:\n"
        doc += "\t\t-instr_amoswap: Atomic Swap\n"
        doc += "\t\t-instr_amoor: Atomic OR\n"
        doc += "\t Cache Stall Operations:\n"
        doc += "\t\t-stall_miss: Miss Operation (Stall)\n"
        doc += "\t\t-stall_idle: Idle Operation (Stall)\n"
        doc += "\t\t-stall_rsp: Response Network Congestion Stall\n"
        doc += "\n"
        doc += " *** All operations take one cycle. *** \n"

        return (pretty, doc)


    # Compute the breakdowns for an operation type. 
    # Compute both intra group percentage, and total
    @classmethod
    def __cycle_breakdown(cls, tot_cyc, ds):
        # Construct a new dataframe (the input is a series)
        df = pd.DataFrame()
        df["Count"] = ds
        # Compute breakdowns. For anything that is NaN, just report 0
        df["% of Type Cycles"] = (100 * ds / ds.loc[:,"Total"]).fillna(0)
        df["% of Total Cycles"]   = 100 * ds / tot_cyc
        return df

    # Formatting method for table index.
    @classmethod
    def __index_tostr(cls, i):
        if i[0] == "Cycles":
            s =f"{i[1]} Cycles"
            return s
        if i[1] == "Total":
            s =f"{i[0]} Operation {i[1]}"
            return s + "\n" + "-" * len(s)
        else:
            return f"--{i[1]}"

    # Format the cycles table (operations)
    @classmethod
    def __cycle_tostr(cls, df):
        # Create columns for Type, and Group percentages
        tot_cyc = df.loc[("Cycles", "Total")]
        f = functools.partial(cls.__cycle_breakdown, tot_cyc)
        df = df.groupby(level=[0]).apply(f)
        
        # Format the final table...

        # Reorder the index
        order = ["Load", "Store", "Atomic", "Management", "Stall", "Cycles"]
        df = df.loc[(order),:]

        # Then prettify the by applying index_tostr
        i = list(df.index.map(cls.__index_tostr))

        # Specify the float precision
        fmt = [".0f", ".0f", ".2f", ".2f"]

        # Finally, format the table with the pretty index
        s = df.to_markdown(tablefmt="simple", floatfmt=fmt, index=i, numalign="right")

        return s

    # Format the events table (misses)
    @classmethod
    def __event_tostr(cls, ds, ld, st, atom):
        # Construct a pretty dataframe to print
        df = pd.DataFrame()

        # We only care about misses, so throw away DMA operations
        ds = ds.loc["Miss"]

        # Create a column for miss counts
        df["Misses"] = ds

        # Set up a "Type" column, to use as a new index, replacing the
        # one from the CSV
        df["Type"] = ds.index.map({"miss_st": "Stores",
                                   "miss_ld": "Loads",
                                   "miss_amo": "Atomics",
                                   "Total": "Total"})

        # Set up a column for access counts
        df["Accesses"] = pd.Series(index = ds.index.values,
                                   data =  [st, ld, atom, atom + ld + st])

        # Compute the miss rate by dividing the misses by the accesses
        # Nans are expected -- 0/0. Just turn them into 0's
        df["Miss Rate (%)"] = (100 * df["Misses"] / df["Accesses"]).fillna(0)

        # Set index to the type
        df = df.set_index(["Type"])

        # Set the format for floats
        fmt = [".0f"] * 3 + [".2f"]
        s = df.to_markdown(tablefmt="simple", floatfmt=fmt, numalign="right")
        return s

    # Get a pretty formatted table representation for a tag
    @classmethod
    def __tag_tostr(cls, df):
        # Get load and store totals for miss statistics
        ld_total = df.loc[("Cycle", ["Load"], "Total")][0]
        st_total = df.loc[("Cycle", ["Store"], "Total")][0]
        at_total = df.loc[("Cycle", ["Atomic"], "Total")][0]

        counts = cls.__cycle_tostr(df.loc["Cycle"]) + "\n"
        l = len(counts.splitlines()[0])

        events = cls.__event_tostr(df.loc["Event"], ld_total, st_total, at_total)

        s = ""
        s += ("Operation Cycle Counts" + " " * l)[:l] + "\n"
        s += cls._make_sub_sep("", l) + "\n"
        s += counts
        s += cls._make_sub_sep("", l) + "\n"

        # TODO: Bandwidth Utilization would go here:
        s += "\n"
        s += cls._make_sub_sep("", l) + "\n"
        s += ("Miss Statistics" + " " * l)[:l] + "\n"
        s += cls._make_sub_sep("", l) + "\n"
        s += events
        s += "\n"
        s += cls._make_sub_sep("", l) + "\n"

        return s

    # Get a pretty formatted table representation for all tags
    @classmethod
    def __tostr(cls, df):
        s = ""
        for tag in df.columns:
            tab= cls.__tag_tostr(df[tag])
            l = tab.splitlines()[0]

            s += cls._make_tag_sep(tag, len(l))
            s += "\n"
            s += tab
            s += "\n"
            s += "\n"
        return s

    # Define a string representation for Bank Statistics.
    # Returns a pretty table and the doc header
    def __str__(self):
        # Get name, and add spaces
        n = super().__str__()
        n = " " + n + " "

        # Get pretty dataframe, and documentation
        df, doc = self.__prettify(self.df)

        # Get string-formatted table for all tags
        tab = self.__tostr(df)

        # Get horizontal width of table 
        w = len(tab.splitlines()[0])

        # Build separators
        sep = self._make_sec_sep(n, w) + "\n"
        end = self._make_sec_sep("End " + n, w) + "\n"
        return sep + doc + tab

class CacheBankStats(CacheStats):
    # This class is highly similar to CacheTagStats. Detailed comments
    # are in that class.
    def __init__(self, name, df):
        super().__init__(name, df)
        
        # Create a table where we'll compute the per-bank tagsums. Do
        # not take the sum, because we are not aggregating here.
        hierarchy = ["Action", "Tag", "Cache Coordinate (Y,X)", "Tile-Tag Iteration"]
        banks = df.set_index(hierarchy)

        # Split into Start/End 
        starts = banks.loc["Start"]
        ends = banks.loc["End"]

        # Find mismatched start and end pairs
        mismatches = self.find_mismatches(starts, ends)
        if(list(mismatches)):
            raise RuntimeError("Unpaired calls to Start/End detected."
                               f" Check the following: {tuple(mismatches.names)}:"
                               f"{list(mismatches)}")

        # For all tag iterations, find the minium arrival time
        # for the start packet for that iteration
        starts = starts.groupby(["Tag", "Cache Coordinate (Y,X)", "Tile-Tag Iteration"]).first()

        # As above, groupby maintains order within groups so
        # we can just use last().
        ends = ends.groupby(["Tag", "Cache Coordinate (Y,X)", "Tile-Tag Iteration"]).last()

        # Same for tags, except keep the cache coordinates
        results = (ends - starts).groupby(["Tag", "Cache Coordinate (Y,X)"]).sum()

        # Save the result
        self.df = results


    # Parse the results into a pretty table
    def __prettify(self, df):

        pretty = pd.DataFrame()
        doc = ""
        ops = self.df[self._ops].sum(axis="columns")

        # Compute pretty table

        # Fill nans as 0's where this is expected behaviour (i.e. 0/0) but leave infs.
        doc += "Table Fields: \n"

        doc += "\t- Cache Coordinate (Y,X): Cache Coordinate within HammerBlade Pod\n"

        doc += "\t- Total Cycles: Total Cache Execution Cycles\n"
        pretty["Total Cycles"] = self.df["global_ctr"]

        doc += "\t- # Misses: Total Number of Cache Misses\n"
        pretty["# Misses"] = self.df["total_miss"]

        doc += "\t- Operations: Total Number of Cache Operations (Loads + Stores + Atomics + Management)\n"
        pretty["# Operations"] = ops

        doc += "\t- Miss Rate (%): 100 * (Number of Misses / Number of Ops)\n"
        pretty["Miss Rate"] = 100 * self.df["total_miss"] / ops

        doc += "\t- Memory Access Latency: Average Memory Access Latency for Misses (Total Miss Cycles / Number of Misses)\n"
        pretty["Mem. Latency"] = (self.df["stall_miss"] / self.df["total_miss"]).fillna(0)

        doc += "\t- Miss Percent: 100 * (Total Miss Cycles / Total Cycles)\n"
        pretty["Miss Percent"] = 100 *(self.df["stall_miss"] / self.df["global_ctr"])

        doc += "\t- Idle Percent: 100 * (Total Idle Cycles / Total Cycles)\n"
        pretty["Idle Percent"] = 100 *(self.df["stall_idle"] / self.df["global_ctr"])

        doc += "\t- Response Stall Percent: 100 * (Total Response Stall Cycles / Total Cycles)\n"
        pretty["Stall Percent"] = 100 *(self.df["stall_rsp"] / self.df["global_ctr"])

        doc += "\t- Operations Percent Cycles: 100 * (Total Operation Cycles / Total Cycles)\n"
        pretty["Ops. Percent"] = 100 * (ops / self.df["global_ctr"])

        doc += "\n"
        doc += "Note: inf (Infinite) occurs when a tag window captures miss stall cycles that bleed into its window, but has no misses"
        
        doc += "\n"
        

        return (pretty, doc)

    # Get a pretty formatted table representation for a tag
    @classmethod
    def __tag_tostr(cls, df):
        # Dictate the format of floats to two decimal
        # points. Everything else should be an integer. This isn't
        # clean, but effective, and the only way
        fmt = [".0f"] * 4 + [".2f"] * (len(df.columns) -3)
        s = df.to_markdown(tablefmt="simple", floatfmt=fmt, numalign="right")
        return s

    # Get a pretty formatted table representation for all tags
    @classmethod
    def __tostr(cls, df):
        s = ""
        for tag, sub in df.groupby(level=[0]):
            tab = cls.__tag_tostr(sub.loc[tag])
            l = tab.splitlines()[0]

            s += cls._make_tag_sep(tag, len(l))
            s += "\n"
            s += tab
            s += "\n"
            s += "\n"
        return s

    # Define a string representation for Bank Statistics.
    # Returns a pretty table and the doc header
    def __str__(self):
        # Get name
        n = super().__str__()

        # Get pretty dataframe, and documentation
        df, doc = self.__prettify(self.df)

        # Get string-formatted table
        tab = self.__tostr(df)

        # Get horizontal width of table 
        w = len(tab.splitlines()[0])

        # Build separators
        sep = self._make_sec_sep(n, w) + "\n"
        end = self._make_sec_sep("End " + n, w) + "\n"
        return sep + doc + tab + end
        

# Aggregate cache statistics for a particular dataframe. Can be reused
# for the device, or for a particular tile group (via GroupCacheStats)
class AggregateCacheStats():
    def __init__(self, df):
        # Create tables with data specific to the parser that will use it
        # Per-Tag Cache Parsing doesn't care about Tile Group ID
        tagdata = df.drop(["Tile Group ID"], axis="columns")

        # Per-Bank Cache Parsing doesn't care about Tile Group ID, or Tile Coordinate
        bankdata = df.drop(["Tile Group ID", "Tile Coordinate (Y,X)"], axis="columns")

        self.tag = CacheTagStats("Per-Tag Victim Cache Stats", tagdata)
        self.bank = CacheBankStats("Per-Bank Victim Cache Stats", bankdata)
        
    def __str__(self):
        s = str(self.tag)
        s += str(self.bank)
        return s

# Aggregate cache statistics for each tile group within a dataframe
class GroupCacheStats():
    def __init__(self, df):
        self._agg = dict()

        # Group the dataframe by Tile Group ID and then parse that
        # group
        for i, grp in df.groupby(["Tile Group ID"]):
            self._agg[i] = AggregateCacheStats(grp)

    def __getitem__(self, i):
        return self._agg[i]


class VanillaStatsParser:
    # formatting parameters for aligned printing
    type_fmt = {"name"      : "{:<35}",
                "name-short": "{:<20}",
                "name_indt" : "  {:<33}",
                "type"      : "{:>20}",
                "int"       : "{:>20}",
                "float"     : "{:>20.4f}",
                "percent"   : "{:>20.2f}",
                "cord"      : "{:<2}, {:<31}",
                "tag"       : "Tag {:<8}",
               }


    print_format = {"tg_timing_header": type_fmt["name"]       + type_fmt["type"] + type_fmt["type"]    + type_fmt["type"]    + type_fmt["type"]    + type_fmt["type"]    + type_fmt["type"]    + type_fmt["type"]    + "\n",
                    "tg_timing_data"  : type_fmt["name"]       + type_fmt["int"]  + type_fmt["int"]     + type_fmt["int"]     + type_fmt["float"]   + type_fmt["float"]   + type_fmt["percent"] + type_fmt["percent"] + "\n",
                    "timing_header"   : type_fmt["name"]       + type_fmt["type"] + type_fmt["type"]    + type_fmt["type"]    + type_fmt["type"]    + type_fmt["type"]    + type_fmt["type"]    + "\n",
                    "tile_timing_data": type_fmt["cord"]       + type_fmt["int"]  + type_fmt["int"]     + type_fmt["float"]   + type_fmt["float"]   + type_fmt["percent"] + type_fmt["percent"] + "\n",
                    "timing_data"     : type_fmt["name"]       + type_fmt["int"]  + type_fmt["int"]     + type_fmt["float"]   + type_fmt["percent"] + type_fmt["percent"] + "\n",

                    "instr_header"    : type_fmt["name"]       + type_fmt["int"]  + type_fmt["type"]    + "\n",
                    "instr_data"      : type_fmt["name"]       + type_fmt["int"]  + type_fmt["percent"] + "\n",
                    "instr_data_indt" : type_fmt["name_indt"]  + type_fmt["int"]  + type_fmt["percent"] + "\n",
                    "stall_header"    : type_fmt["name"]       + type_fmt["type"] + type_fmt["type"]    + type_fmt["type"]    + "\n",
                    "stall_data"      : type_fmt["name"]       + type_fmt["int"]  + type_fmt["percent"] + type_fmt["percent"] + "\n",
                    "stall_data_indt" : type_fmt["name_indt"]  + type_fmt["int"]  + type_fmt["percent"] + type_fmt["percent"] + "\n",
                    "bubble_header"   : type_fmt["name"]       + type_fmt["type"] + type_fmt["type"]    + type_fmt["type"]    + "\n",
                    "bubble_data"     : type_fmt["name"]       + type_fmt["int"]  + type_fmt["percent"] + type_fmt["percent"] + "\n",
                    "miss_header"     : type_fmt["name"]       + type_fmt["type"] + type_fmt["type"]    + type_fmt["type"]    + "\n",
                    "miss_data"       : type_fmt["name"]       + type_fmt["int"]  + type_fmt["int"]     + type_fmt["percent"]   + "\n",
                    "tag_header"      : type_fmt["name-short"] + type_fmt["type"] + type_fmt["type"]    + type_fmt["type"]    + type_fmt["type"]    + type_fmt["type"]    + type_fmt["type"] + type_fmt["type"]  + type_fmt["type"]  + type_fmt["type"]    + "\n",
                    "tag_data"        : type_fmt["name-short"] + type_fmt["int"]  + type_fmt["int"]     + type_fmt["int"]     + type_fmt["int"]     + type_fmt["int"]     + type_fmt["int"]  + type_fmt["float"] + type_fmt["float"] + type_fmt["percent"] + "\n",
                    "tag_separator"   : '-' * 93 + ' ' * 2     + type_fmt["tag"]  + ' ' * 2 + '-' * 93 + "\n",
                    "start_lbreak"    : '=' *202 + "\n",
                    "end_lbreak"      : '=' *202 + "\n\n",
                   }



    # default constructor
    def __init__(self, per_tile_stat, per_tile_group_stat, vanilla_input_file, vcache_input_file):

        self.per_tile_stat = per_tile_stat
        self.per_tile_group_stat = per_tile_group_stat
        self.vcache = True if vcache_input_file else False

        self.traces = []
        self.vcache_traces = []

        self.max_tile_groups = 1 << CudaStatTag._TG_ID_WIDTH
        self.num_tile_groups = []

        self.max_tags = 1 << CudaStatTag._TAG_WIDTH

        tags = list(range(self.max_tags)) + ["kernel"]
        self.tile_stat = {tag:Counter() for tag in tags}
        self.tile_group_stat = {tag:Counter() for tag in tags}
        self.manycore_stat = {tag:Counter() for tag in tags}
        self.manycore_cycle_parallel_cnt = {tag: 0 for tag in tags}

        # list of instructions, operations and events parsed from vanilla_stats.csv
        # populated by reading the header of input file 
        self.stats_list = []
        self.instrs = []
        self.misses = []
        self.stalls = []
        self.bubbles = []
        self.all_ops = []

        # Parse input file's header to generate a list of all types of operations
        self.stats, self.instrs, self.flops, self.misses, self.stalls, self.bubbles = self.parse_header(vanilla_input_file)


        # bubbles that are  a bubble in the Integer pipeline "caused" by
        # an FP instruction executing. Don't count it in the bubbles
        # because the procesor is still doing "useful work". 
        self.notbubbles = [] 

        # Remove all notbubbles from the bubbles list
        for nb in self.notbubbles:
            self.bubbles.remove(nb)


        # Floating point operations that should not count 
        # towards calculations FLOPS/sec
        self.notflops = ["instr_fsgnj"
                         ,"instr_fsgnjn"
                         ,"instr_fsgnjx"
                         ,"instr_fcvt_s_w"
                         ,"instr_fcvt_s_wu"
                         ,"instr_fcvt_w_s"
                         ,"instr_fcvt_wu_s"
                         ,"instr_fmv_w_x"
                         ,"instr_fmv_x_w"
                         ,"instr_fclass"]

        # Remove all notflops from the flops list
        for nf in self.notflops:
            self.flops.remove(nf)


        # Create a list of all types of opertaions for iteration
        self.all_ops = self.stats + self.instrs + self.misses + self.stalls + self.bubbles

        # Use sets to determine the active tiles (without duplicates)
        active_tiles = set()

        # Parse stats file line by line, and append the trace line to traces list. 
        with open(vanilla_input_file) as f:
            csv_reader = csv.DictReader (f, delimiter=",")
            for row in csv_reader:
                trace = {op:int(row[op]) for op in self.all_ops}
                active_tiles.add((trace['y'], trace['x']))
                self.traces.append(trace)




        # Raise exception and exit if there are no traces 
        if not self.traces:
            raise IOError("No Vanilla Stats Found: Use bsg_cuda_print_stat_kernel_start/end to generate runtime statistics")


        # Save the active tiles in a list
        self.active_tiles = list(active_tiles)
        self.active_tiles.sort()

        # generate timing stats for each tile and tile group 
        self.num_tile_groups, self.tile_group_stat, self.tile_stat, self.manycore_cycle_parallel_cnt = self.__generate_tile_stats(self.traces, self.active_tiles)

        # Calculate total aggregate stats for manycore by summing up per_tile stat counts
        self.manycore_stat = self.__generate_manycore_stats_all(self.tile_stat, self.manycore_cycle_parallel_cnt)

        # Generate VCache Stats
        # If vcache stats file is given as input, also generate vcache stats 
        if (self.vcache):
            self.vparser = CacheStatsParser(vcache_input_file)
            
        return


    # print a line of stat into stats file based on stat type
    def __print_stat(self, stat_file, stat_type, *argv):
        stat_file.write(self.print_format[stat_type].format(*argv));
        return


    # print instruction count, stall count, execution cycles for the entire manycore for each tag
    def __print_manycore_stats_tag(self, stat_file):
        stat_file.write("Per-Tag Stats\n")
        self.__print_stat(stat_file, "tag_header"
                                     ,"Tag ID"
                                     ,"Aggr Instructions"
                                     ,"Aggr I$ Misses"
                                     ,"Aggr Stall Cycles"
                                     ,"Aggr Bubble Cycles"
                                     ,"Aggr Total Cycles"
                                     ,"Abs Total Cycles"
                                     ,"IPC"
                                     ,"FLOPS/Cycle"
                                     ,"    % of Kernel Cycles")
        self.__print_stat(stat_file, "start_lbreak")

        for tag in self.manycore_stat.keys():
            if(self.manycore_stat[tag]["global_ctr"]):
                self.__print_stat(stat_file, "tag_data"
                                             ,tag
                                             ,self.manycore_stat[tag]["instr_total"]
                                             ,self.manycore_stat[tag]["miss_icache"]
                                             ,self.manycore_stat[tag]["stall_total"]
                                             ,self.manycore_stat[tag]["bubble_total"]
                                             ,self.manycore_stat[tag]["global_ctr"]
                                             ,self.manycore_stat[tag]["cycle_parallel_cnt"]
                                             ,(np.float64(self.manycore_stat[tag]["instr_total"]) / self.manycore_stat[tag]["global_ctr"])
                                             ,(np.float64(self.manycore_stat[tag]["flop_total"]) / self.manycore_stat[tag]["global_ctr"])
                                             ,np.float64(100 * self.manycore_stat[tag]["global_ctr"]) / self.manycore_stat["kernel"]["global_ctr"])
        self.__print_stat(stat_file, "end_lbreak")
        return




    # print instruction count, stall count, execution cycles 
    # for each tile group in a separate file for each tag
    # tg_id: tile group id
    # header - name of stats in the output stats file 
    # tile_group_stat: data structure containing tile group stats
    def __print_per_tile_group_stats_tag(self, stat_file, header, tg_id, tile_group_stat):
        stat_file.write(header + "\n")
        self.__print_stat(stat_file, "tag_header"
                                     ,"Tag ID"
                                     ,"Aggr Instructions"
                                     ,"Aggr I$ Misses"
                                     ,"Aggr Stall Cycles"
                                     ,"Aggr Bubble Cycles"
                                     ,"Aggr Total Cycles"
                                     ,"Abs Total Cycles"
                                     ,"IPC"
                                     ,"FLOPS/Cycle"
                                     ,"    % of Kernel Cycles")
        self.__print_stat(stat_file, "start_lbreak")

        for tag in tile_group_stat.keys():
            if(tile_group_stat[tag][tg_id]["global_ctr"]):
                self.__print_stat(stat_file, "tag_data"
                                             ,tag
                                             ,tile_group_stat[tag][tg_id]["instr_total"]
                                             ,tile_group_stat[tag][tg_id]["miss_icache"]
                                             ,tile_group_stat[tag][tg_id]["stall_total"]
                                             ,tile_group_stat[tag][tg_id]["bubble_total"]
                                             ,tile_group_stat[tag][tg_id]["global_ctr"]
                                             ,tile_group_stat[tag][tg_id]["cycle_parallel_cnt"]
                                             ,(np.float64(tile_group_stat[tag][tg_id]["instr_total"]) / tile_group_stat[tag][tg_id]["global_ctr"])
                                             ,(np.float64(tile_group_stat[tag][tg_id]["flop_total"]) / tile_group_stat[tag][tg_id]["global_ctr"])
                                             ,(np.float64(100 * tile_group_stat[tag][tg_id]["global_ctr"]) / tile_group_stat["kernel"][tg_id]["global_ctr"]))
        self.__print_stat(stat_file, "end_lbreak")
        return




    # print instruction count, stall count, execution cycles 
    # for each tile in a separate file for each tag
    def __print_per_tile_stats_tag(self, stat_file, header, tile, tile_stat):
        stat_file.write(header + "\n")
        self.__print_stat(stat_file, "tag_header"
                                     ,"Tag ID"
                                     ,"Aggr Instructions"
                                     ,"Aggr I$ Misses"
                                     ,"Aggr Stall Cycles"
                                     ,"Aggr Bubble Cycles"
                                     ,"Aggr Total Cycles"
                                     ,"Abs Total Cycles"
                                     ,"IPC"
                                     ,"FLOPS/Cycle"
                                     ,"    % of Kernel Cycles")
        self.__print_stat(stat_file, "start_lbreak")

        for tag in tile_stat.keys():
            if(tile_stat[tag][tile]["global_ctr"]):
                self.__print_stat(stat_file, "tag_data"
                                             ,tag
                                             ,tile_stat[tag][tile]["instr_total"]
                                             ,tile_stat[tag][tile]["miss_icache"]
                                             ,tile_stat[tag][tile]["stall_total"]
                                             ,tile_stat[tag][tile]["bubble_total"]
                                             ,tile_stat[tag][tile]["global_ctr"]
                                             ,tile_stat[tag][tile]["global_ctr"]
                                             ,(np.float64(tile_stat[tag][tile]["instr_total"]) / tile_stat[tag][tile]["global_ctr"])
                                             ,(np.float64(tile_stat[tag][tile]["flop_total"]) / tile_stat[tag][tile]["global_ctr"])
                                             ,(np.float64(100 * tile_stat[tag][tile]["global_ctr"]) / tile_stat["kernel"][tile]["global_ctr"]))
        self.__print_stat(stat_file, "end_lbreak")
        return




    # print execution timing for the entire manycore per tile group for a certain tag
    def __print_manycore_tag_stats_tile_group_timing(self, stat_file, tag):
        self.__print_stat(stat_file, "tag_separator", tag)

        for tg_id in range (0, self.num_tile_groups[tag]):
            self.__print_stat(stat_file, "tg_timing_data"
                                         ,tg_id
                                         ,(self.tile_group_stat[tag][tg_id]["instr_total"])
                                         ,(self.tile_group_stat[tag][tg_id]["global_ctr"])
                                         ,(self.tile_group_stat[tag][tg_id]["cycle_parallel_cnt"])
                                         ,(np.float64(self.tile_group_stat[tag][tg_id]["instr_total"]) / self.tile_group_stat[tag][tg_id]["global_ctr"])
                                         ,(np.float64(self.tile_group_stat[tag][tg_id]["flop_total"]) / self.tile_group_stat[tag][tg_id]["global_ctr"])
                                         ,(np.float64(100.0 * self.tile_group_stat[tag][tg_id]["global_ctr"]) / self.manycore_stat[tag]["global_ctr"])
                                         ,(np.float64(100.0 * self.tile_group_stat[tag][tg_id]["global_ctr"]) / self.tile_group_stat["kernel"][tg_id]["global_ctr"]))

        self.__print_stat(stat_file, "tg_timing_data"
                                     ,"total"
                                     ,(self.manycore_stat[tag]["instr_total"])
                                     ,(self.manycore_stat[tag]["global_ctr"])
                                     ,(self.manycore_stat[tag]["cycle_parallel_cnt"])
                                     ,(np.float64(self.manycore_stat[tag]["instr_total"]) / self.manycore_stat[tag]["global_ctr"])
                                     ,(np.float64(self.manycore_stat[tag]["flop_total"]) / self.manycore_stat[tag]["global_ctr"])
                                     ,(np.float64(100 * self.manycore_stat[tag]["instr_total"]) / self.manycore_stat[tag]["instr_total"])
                                     ,(np.float64(100 * self.manycore_stat[tag]["global_ctr"]) / self.manycore_stat["kernel"]["global_ctr"]))
        return


    # Prints manycore timing stats per tile group for all tags 
    def __print_manycore_stats_tile_group_timing(self, stat_file):
        stat_file.write("Per-Tile-Group Timing Stats\n")
        self.__print_stat(stat_file, "tg_timing_header"
                                     ,"Tile Group ID"
                                     ,"Aggr Instructions"
                                     ,"Aggr Total Cycles"
                                     ,"Abs Total Cycle"
                                     ,"IPC"
                                     ,"FLOPS/Cycle"
                                     ,"   TG / Tag-Total (%)"
                                     ,"   TG / Kernel-Total(%)")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in self.manycore_stat.keys():
            if(self.manycore_stat[tag]["global_ctr"]):
                self.__print_manycore_tag_stats_tile_group_timing(stat_file, tag)
        self.__print_stat(stat_file, "end_lbreak")
        return   




    # print execution timing for the entire manycore per tile
    def __print_manycore_tag_stats_tile_timing(self, stat_file, tag, tiles, manycore_stat, tile_stat):
        self.__print_stat(stat_file, "tag_separator", tag)

        for tile in tiles:
            self.__print_stat(stat_file, "tile_timing_data"
                              ,tile[0]
                              ,tile[1]
                              ,(tile_stat[tag][tile]["instr_total"])
                              ,(tile_stat[tag][tile]["global_ctr"])
                              ,(np.float64(tile_stat[tag][tile]["instr_total"]) / tile_stat[tag][tile]["global_ctr"])
                              ,(np.float64(tile_stat[tag][tile]["flop_total"]) / tile_stat[tag][tile]["global_ctr"])
                              ,(100 * tile_stat[tag][tile]["global_ctr"] / manycore_stat[tag]["global_ctr"])
                              ,(100 * np.float64(tile_stat[tag][tile]["global_ctr"]) / tile_stat["kernel"][tile]["global_ctr"]))

        self.__print_stat(stat_file, "timing_data"
                                     ,"total"
                                     ,(manycore_stat[tag]["instr_total"])
                                     ,(manycore_stat[tag]["global_ctr"])
                                     ,(manycore_stat[tag]["instr_total"] / manycore_stat[tag]["global_ctr"])
                                     ,(np.float64(100 * manycore_stat[tag]["global_ctr"]) / manycore_stat[tag]["global_ctr"])
                                     ,(np.float64(100 * manycore_stat[tag]["global_ctr"]) / manycore_stat["kernel"]["global_ctr"]))
        return


    # Prints manycore timing stats per tile group for all tags 
    def __print_manycore_stats_tile_timing(self, stat_file, header, tiles, manycore_stat, tile_stat):
        stat_file.write(header + "\n")
        self.__print_stat(stat_file, "timing_header"
                                     ,"Relative Tile Coordinate (Y,X)"
                                     ,"Instructions"
                                     ,"Cycles"
                                     ,"IPC"
                                     ,"FLOPS/Cycle"
                                     ,"   Tile / Tag-Total (%)"
                                     ,"   Tile / Kernel-Total(%)")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in manycore_stat.keys():
            if(manycore_stat[tag]["global_ctr"]):
                self.__print_manycore_tag_stats_tile_timing(stat_file, tag, tiles, manycore_stat, tile_stat)
        self.__print_stat(stat_file, "end_lbreak")
        return   


    # print timing stats for each tile group in a separate file 
    # tg_id is tile group id 
    def __print_per_tile_group_tag_stats_timing(self, stat_file, tg_id, tag, manycore_stat, tile_group_stat):
        self.__print_stat(stat_file, "tag_separator", tag)

        self.__print_stat(stat_file, "tg_timing_data"
                                     ,tg_id
                                     ,(tile_group_stat[tag][tg_id]["instr_total"])
                                     ,(tile_group_stat[tag][tg_id]["global_ctr"])
                                     ,(tile_group_stat[tag][tg_id]["cycle_parallel_cnt"])
                                     ,(np.float64(tile_group_stat[tag][tg_id]["instr_total"]) / tile_group_stat[tag][tg_id]["global_ctr"])
                                     ,(np.float64(tile_group_stat[tag][tg_id]["flop_total"]) / tile_group_stat[tag][tg_id]["global_ctr"])
                                     ,(100 * tile_group_stat[tag][tg_id]["global_ctr"] / manycore_stat[tag]["global_ctr"])
                                     ,(100 * np.float64(tile_group_stat[tag][tg_id]["instr_total"]) / tile_group_stat["kernel"][tg_id]["instr_total"]))
        return


    # Print timing stat for each tile group in separate file for all tags 
    # tg_id: tile group id
    # header - name of stats in the output stats file 
    # tile_group_stat: data structure containing tile group stats
    # manycore_stat: data structure containing manycore stats
    def __print_per_tile_group_stats_timing(self, stat_file, header, tg_id, manycore_stat, tile_group_stat):
        stat_file.write(header + "\n")
        self.__print_stat(stat_file, "tg_timing_header"
                                     ,"Tile Group ID"
                                     ,"Aggr Instructions"
                                     ,"Aggr Total Cycles"
                                     ,"Abs Total Cycle"
                                     ,"IPC"
                                     ,"FLOPS/Cycle"
                                     ,"   TG / Tag-Total (%)"
                                     ,"   TG / Kernel-Total(%)")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in tile_group_stat.keys():
            if(tile_group_stat[tag][tg_id]["global_ctr"]):
                self.__print_per_tile_group_tag_stats_timing(stat_file, tg_id, tag, manycore_stat, tile_group_stat)
        self.__print_stat(stat_file, "end_lbreak")
        return   




    # print timing stats for each tile in a separate file 
    # y,x are tile coordinates 
    def __print_per_tile_tag_stats_timing(self, stat_file, tile, tag, manycore_stat, tile_stat):
        self.__print_stat(stat_file, "tag_separator", tag)

        self.__print_stat(stat_file, "tile_timing_data"
                                     ,tile[0]
                                     ,tile[1]
                                     ,(tile_stat[tag][tile]["instr_total"])
                                     ,(tile_stat[tag][tile]["global_ctr"])
                                     ,(np.float64(tile_stat[tag][tile]["instr_total"]) / tile_stat[tag][tile]["global_ctr"])
                                     ,(np.float64(tile_stat[tag][tile]["flop_total"]) / tile_stat[tag][tile]["global_ctr"])
                                     ,(np.float64(100 * tile_stat[tag][tile]["global_ctr"]) / manycore_stat[tag]["global_ctr"])
                                     ,(np.float64(100 * tile_stat[tag][tile]["global_ctr"]) / tile_stat["kernel"][tile]["global_ctr"]))

        return


    # print timing stats for each tile in a separate file for all tags 
    def __print_per_tile_stats_timing(self, stat_file, header, tile, manycore_stat, tile_stat):
        stat_file.write(header + "\n")
        self.__print_stat(stat_file, "timing_header"
                                     ,"Relative Tile Coordinate (Y,X)"
                                     ,"instr"
                                     ,"cycle"
                                     ,"IPC"
                                     ,"FLOPS/Cycle"
                                     ,"    Tile / Tag-Total (%)"
                                     ,"    Tile / Kernel-Total (%)")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in tile_stat.keys():
            if(tile_stat[tag][tile]["global_ctr"]):
                self.__print_per_tile_tag_stats_timing(stat_file, tile, tag, manycore_stat, tile_stat)
        self.__print_stat(stat_file, "end_lbreak")
        return   




    # print instruction stats for the entire manycore
    # header - name of stats in the output stats file 
    # stat: data structure containing tile group stats
    # instrs: list of all instruction operations
    def __print_manycore_tag_stats_instr(self, stat_file, stat, instrs, tag):
        self.__print_stat(stat_file, "tag_separator", tag)
   
        # Print instruction stats for manycore
        for instr in instrs:
            instr_format = "instr_data_indt" if (instr.startswith('instr_ld_') or instr.startswith('instr_sm_')) else "instr_data"
            self.__print_stat(stat_file, instr_format, instr,
                                         stat[tag][instr]
                                         ,(100 * np.float64(stat[tag][instr]) / stat[tag]["instr_total"]))
        return


    # Prints manycore instruction stats per tile group for all tags 
    # header - name of stats in the output stats file 
    # stat: data structure containing manycore stats
    # instrs: list of all instruction operations
    def __print_manycore_stats_instr(self, stat_file, header, stat, instrs):
        stat_file.write(header + "\n")
        self.__print_stat(stat_file, "instr_header", "Instruction", "Count", "% of Instructions")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in stat.keys():
            if(stat[tag]["global_ctr"]):
                self.__print_manycore_tag_stats_instr(stat_file, stat, instrs, tag)
        self.__print_stat(stat_file, "end_lbreak")
        return   





    # print instruction stats for each tile group in a separate file 
    # tg_id: tile group id
    # header - name of stats in the output stats file 
    # tile_group_stat: data structure containing tile group stats
    # instrs: list of all instruction operations
    def __print_per_tile_group_tag_stats_instr(self, stat_file, tg_id, tag, tile_group_stat, instrs):
        self.__print_stat(stat_file, "tag_separator", tag)

        # Print instruction stats for manycore
        for instr in instrs:
            instr_format = "instr_data_indt" if (instr.startswith('instr_ld_') or instr.startswith('instr_sm_')) else "instr_data"
            self.__print_stat(stat_file, instr_format, instr,
                                         tile_group_stat[tag][tg_id][instr]
                                         ,(100 * np.float64(tile_group_stat[tag][tg_id][instr]) / tile_group_stat[tag][tg_id]["instr_total"]))
        return


    # Print instruction stat for each tile group in separate file for all tags 
    # tg_id: tile group id
    # header - name of stats in the output stats file 
    # tile_group_stat: data structure containing tile group stats
    # instrs: list of all instruction operations
    def __print_per_tile_group_stats_instr(self, stat_file, header, tg_id, tile_group_stat, instrs):
        stat_file.write(header + "\n")
        self.__print_stat(stat_file, "instr_header", "Instruction", "Count", "% of Instructions")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in tile_group_stat.keys():
            if(tile_group_stat[tag][tg_id]["global_ctr"]):
                self.__print_per_tile_group_tag_stats_instr(stat_file, tg_id, tag, tile_group_stat, instrs)
        self.__print_stat(stat_file, "end_lbreak")
        return   




    # print instruction stat for a single item (tile or vcache bank) in its given stat file
    # item: entity id (tile x,y cooryydinates, or vcache bank number, etc.)
    # stat: data structure containing manycore stats
    # instrs: list of all instruction operations
    def __print_tag_stats_instr(self, stat_file, item, tag, stat, instrs):
        self.__print_stat(stat_file, "tag_separator", tag)

        # Print instruction stats for manycore
        for instr in instrs:
            instr_format = "instr_data_indt" if (instr.startswith('instr_ld_') or instr.startswith('instr_st_')) else "instr_data"
            self.__print_stat(stat_file, instr_format, instr,
                                         stat[tag][item][instr]
                                         ,(100 * np.float64(stat[tag][item][instr]) / stat[tag][item]["instr_total"]))
        return


    # print instruction stat for a single item (tile or vcache bank) in its given stat file
    # header - name of stats in the output stats file 
    # item: entity id (tile x,y coordinates, or vcache bank number, etc.)
    # stat: data structure containing manycore stats
    # instrs: list of all instruction operations
    def __print_stats_instr(self, stat_file, header, item, stat, instrs):
        stat_file.write("Instruction Stats\n")
        self.__print_stat(stat_file, "instr_header", "Instruction", "Count", "% of Instructions")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in stat.keys():
            if(stat[tag][item]["global_ctr"]):
                self.__print_tag_stats_instr(stat_file, item, tag, stat, instrs)
        self.__print_stat(stat_file, "end_lbreak")
        return   




    # print stall stats for the entire manycore
    # stat: data structure containing manycore stats
    # stalls: list of all stall operations
    def __print_manycore_tag_stats_stall(self, stat_file, stat, stalls, tag):
        self.__print_stat(stat_file, "tag_separator", tag)

        # Print stall stats for manycore
        for stall in stalls:
            self.__print_stat(stat_file, "stall_data", stall
                                         ,stat[tag][stall]
                                         ,(100 * np.float64(stat[tag][stall]) / stat[tag]["stall_total"])
                                         ,(100 * np.float64(stat[tag][stall]) / stat[tag]["global_ctr"]))

        not_stall = stat[tag]["global_ctr"] - stat[tag]["stall_total"]
        self.__print_stat(stat_file, "stall_data", "not_stall"
                                     ,not_stall
                                     ,(100 * np.float64(not_stall) / stat[tag]["stall_total"])
                                     ,(100 * np.float64(not_stall) / stat[tag]["global_ctr"]))
        return


    # Prints manycore stall stats per tile group for all tags
    # header - name of stats in the output stats file 
    # stat: data structure containing manycore stats
    # stalls: list of all stall operations
    def __print_manycore_stats_stall(self, stat_file, header, stat, stalls):
        stat_file.write(header + "\n")
        self.__print_stat(stat_file, "stall_header", "Stall Type", "Cycles", " % Stall Cycles", " % Total Cycles")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in stat.keys():
            if(stat[tag]["global_ctr"]):
                self.__print_manycore_tag_stats_stall(stat_file, stat, stalls, tag)
        self.__print_stat(stat_file, "end_lbreak")
        return   





    # print stall stats for each tile group in a separate file
    # tg_id: tile group id
    # header - name of stats in the output stats file 
    # tile_group_stat: data structure containing tile group stats
    # stalls: list of all stall operations
    def __print_per_tile_group_tag_stats_stall(self, stat_file, tg_id, tag, tile_group_stat, stalls):
        self.__print_stat(stat_file, "tag_separator", tag)

        # Print stall stats for manycore
        for stall in stalls:
            self.__print_stat(stat_file, "stall_data"
                                         ,stall
                                         ,tile_group_stat[tag][tg_id][stall]
                                         ,(100 * np.float64(tile_group_stat[tag][tg_id][stall]) / tile_group_stat[tag][tg_id]["stall_total"])
                                         ,(100 * np.float64(tile_group_stat[tag][tg_id][stall]) / tile_group_stat[tag][tg_id]["global_ctr"]))
        return


    # Print stall stat for each tile group in separate file for all tags 
    # tg_id: tile group id
    # header - name of stats in the output stats file 
    # tile_group_stat: data structure containing tile group stats
    # stalls: list of all stall operations
    def __print_per_tile_group_stats_stall(self, stat_file, header, tg_id, tile_group_stat, stalls):
        stat_file.write(header + "\n")
        self.__print_stat(stat_file, "stall_header", "Stall Type", "Cycles", "% of Stall Cycles", " % of Total Cycles")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in tile_group_stat.keys():
            if(tile_group_stat[tag][tg_id]["global_ctr"]):
                self.__print_per_tile_group_tag_stats_stall(stat_file, tg_id, tag, tile_group_stat, stalls)
        self.__print_stat(stat_file, "end_lbreak")
        return   




    # print stall stat for a single item (tile or vcache bank) in its given stat file
    # item: entity id (tile x,y cooryydinates, or vcache bank number, etc.)
    # stat: data structure containing manycore stats
    # stalls: list of all stall operations
    def __print_tag_stats_stall(self, stat_file, item, tag, stat, stalls):
        self.__print_stat(stat_file, "tag_separator", tag)

        # Print stall stats for manycore
        for stall in stalls:
            self.__print_stat(stat_file, "stall_data", stall,
                                         stat[tag][item][stall],
                                         (100 * np.float64(stat[tag][item][stall]) / stat[tag][item]["stall_total"])
                                         ,(100 * np.float64(stat[tag][item][stall]) / stat[tag][item]["global_ctr"]))
        return


    # print stall stat for a single item (tile or vcache bank) in its given stat file
    # header - name of stats in the output stats file 
    # item: entity id (tile x,y coordinates, or vcache bank number, etc.)
    # stat: data structure containing manycore stats
    # stalls: list of all stall operations
    def __print_stats_stall(self, stat_file, header, item, stat, stalls):
        stat_file.write(header + "\n")
        self.__print_stat(stat_file, "stall_header", "Stall Type", "Cycles", "% of Stall Cycles", "% of Total Cycles")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in stat.keys():
            if(stat[tag][item]["global_ctr"]):
                self.__print_tag_stats_stall(stat_file, item, tag, stat, stalls)
        self.__print_stat(stat_file, "start_lbreak")
        return   




    # print bubble stats for the entire manycore
    # stat: data structure containing manycore stats
    # bubbles: list of all bubble operations
    def __print_manycore_tag_stats_bubble(self, stat_file, stat, bubbles, tag):
        self.__print_stat(stat_file, "tag_separator", tag)

        # Print bubble stats for manycore
        for bubble in bubbles:
            self.__print_stat(stat_file, "bubble_data", bubble,
                                         stat[tag][bubble],
                                         (100 * np.float64(stat[tag][bubble]) / stat[tag]["bubble_total"])
                                         ,(100 * stat[tag][bubble] / stat[tag]["global_ctr"]))
        return


    # Prints manycore bubble stats per tile group for all tags 
    # header - name of stats in the output stats file 
    # stat: data structure containing manycore stats
    # bubbles: list of all bubble operations
    def __print_manycore_stats_bubble(self, stat_file, header, stat, bubbles):
        stat_file.write(header + "\n")
        self.__print_stat(stat_file, "bubble_header", "Bubble Type", "Cycles", "% of Bubbles", "% of Total Cycles")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in stat.keys():
            if(stat[tag]["global_ctr"]):
                self.__print_manycore_tag_stats_bubble(stat_file, stat, bubbles, tag)
        self.__print_stat(stat_file, "end_lbreak")
        return   




    # print bubble stats for each tile group in a separate file
    # tg_id: tile group id
    # header - name of stats in the output stats file 
    # tile_group_stat: data structure containing manycore stats
    # bubbles: list of all bubble operations
    def __print_per_tile_group_tag_stats_bubble(self, stat_file, tg_id, tag, tile_group_stat, bubbles):
        self.__print_stat(stat_file, "tag_separator", tag)

        # Print bubble stats for manycore
        for bubble in bubbles:
            self.__print_stat(stat_file, "bubble_data"
                                         ,bubble
                                         ,tile_group_stat[tag][tg_id][bubble]
                                         ,(100 * np.float64(tile_group_stat[tag][tg_id][bubble]) / tile_group_stat[tag][tg_id]["bubble_total"])
                                         ,(100 * tile_group_stat[tag][tg_id][bubble] / tile_group_stat[tag][tg_id]["global_ctr"]))
        return


    # Print bubble stat for each tile group in separate file for all tags 
    # tg_id: tile group id
    # header - name of stats in the output stats file 
    # tile_group_stat: data structure containing tile group stats
    # bubbles: list of all bubble operations
    def __print_per_tile_group_stats_bubble(self, stat_file, header, tg_id, tile_group_stat, bubbles):
        stat_file.write(header + "\n")
        self.__print_stat(stat_file, "bubble_header", "Bubble Type", "Cycles", "% of Bubbles", "% of Total Cycles")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in tile_group_stat.keys():
            if(tile_group_stat[tag][tg_id]["global_ctr"]):
                self.__print_per_tile_group_tag_stats_bubble(stat_file, tg_id, tag, tile_group_stat, bubbles)
        self.__print_stat(stat_file, "end_lbreak")
        return   




    # print stall stat for a single item (tile or vcache bank) in its given stat file
    # item: entity id (tile x,y cooryydinates, or vcache bank number, etc.)
    # stat: data structure containing manycore stats
    # bubbles: list of all bubble operations
    def __print_tag_stats_bubble(self, stat_file, item, tag, stat, bubbles):
        self.__print_stat(stat_file, "tag_separator", tag)

        # Print bubble stats for manycore
        for bubble in bubbles:
            self.__print_stat(stat_file, "bubble_data", bubble,
                                         stat[tag][item][bubble],
                                         (100 * np.float64(stat[tag][item][bubble]) / stat[tag][item]["bubble_total"])
                                         ,(100 * np.float64(stat[tag][item][bubble]) / stat[tag][item]["global_ctr"]))
        return


    # print bubble stat for a single item (tile or vcache bank) in its given stat file
    # header - name of stats in the output stats file 
    # item: entity id (tile x,y coordinates, or vcache bank number, etc.)
    # stat: data structure containing manycore stats
    # bubbles: list of all bubble operations
    def __print_stats_bubble(self, stat_file, header, item, stat, bubbles):
        stat_file.write(header+ "\n")
        self.__print_stat(stat_file, "bubble_header", "Bubble Type", "Cycles", "% of Bubbles", "% of Total Cycles")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in stat.keys():
            if(stat[tag][item]["global_ctr"]):
                self.__print_tag_stats_bubble(stat_file, item, tag, stat, bubbles)
        self.__print_stat(stat_file, "start_lbreak")
        return   





    # print miss stats for the entire manycore
    # stat: data structure containing manycore stats
    # misses: list of all miss operations
    def __print_manycore_tag_stats_miss(self, stat_file, stat, misses, tag):
        self.__print_stat(stat_file, "tag_separator", tag)

        for miss in misses:
            # Find total number of operations for that miss If
            # operation is icache, the total is total # of instruction
            # otherwise, search for the specific instruction
            if (miss == "miss_icache"):
                operation = "icache"
                operation_cnt = stat[tag]["instr_total"]
            # For miss total, we count the hit numbers (hit_total)
            # not all instructions (instr_total)
            elif (miss == "miss_total"):
                operation = "hit_total"
                operation_cnt = stat[tag][operation] + stat[tag][miss]
            else:
                operation = miss.replace("miss_", "instr_")
                operation_cnt = stat[tag][operation] + stat[tag][miss]
            miss_cnt = stat[tag][miss]
            hit_rate = 100.0 if operation_cnt == 0 else 100.0*(1 - miss_cnt/operation_cnt)
         
            self.__print_stat(stat_file, "miss_data", miss, miss_cnt, operation_cnt, hit_rate )
        return


    # Prints manycore miss stats per tile group for all tags
    # header - name of stats in the output stats file 
    # stat: data structure containing manycore stats
    # misses: list of all miss operations
    def __print_manycore_stats_miss(self, stat_file, header, stat, misses):
        stat_file.write(header + "\n")
        self.__print_stat(stat_file, "miss_header", "Miss Type", "Misses", "Accesses", "Hit Rate (%)")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in stat.keys():
            if(stat[tag]["global_ctr"]):
                self.__print_manycore_tag_stats_miss(stat_file, stat, misses, tag)
        self.__print_stat(stat_file, "end_lbreak")
        return   






    # print miss stats for each tile group in a separate file
    # tg_id: tile group id  
    # header - name of stats in the output stats file 
    # tile_group_stat: data structure containing tile group stats
    # misses: list of all miss operations
    def __print_per_tile_group_tag_stats_miss(self, stat_file, tg_id, tag, tile_group_stat, misses):
        self.__print_stat(stat_file, "tag_separator", tag)

        for miss in misses:
            # Find total number of operations for that miss
            # If operation is icache, the total is total # of instruction
            # otherwise, search for the specific instruction
            if (miss == "miss_icache"):
                operation = "icache"
                operation_cnt = tile_group_stat[tag][tg_id]["instr_total"]
            # For miss total, we count the hit numbers (hit_total)
            # not all instructions (instr_total)
            elif (miss == "miss_total"):
                operation = "hit_total"
                operation_cnt = tile_group_stat[tag][tg_id][operation] + tile_group_stat[tag][tg_id][miss]
            else:
                operation = miss.replace("miss_", "instr_")
                operation_cnt = tile_group_stat[tag][tg_id][operation] + tile_group_stat[tag][tg_id][miss]
            miss_cnt = tile_group_stat[tag][tg_id][miss]
            hit_rate = 100.0 if operation_cnt == 0 else 100.0*(1 - miss_cnt/operation_cnt)

            self.__print_stat(stat_file, "miss_data", miss, miss_cnt, operation_cnt, hit_rate )

        return

    # Print miss stat for each tile group in separate file for all tags
    # header - name of stats in the output stats file 
    # tile_group_stat: data structure containing tile group stats
    # misses: list of all miss operations
    def __print_per_tile_group_stats_miss(self, stat_file, header, tg_id, tile_group_stat, misses):
        stat_file.write(header + "\n")
        self.__print_stat(stat_file, "miss_header", "Miss Type", "Misses", "Accesses", "Hit Rate (%)")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in tile_group_stat.keys():
            if(tile_group_stat[tag][tg_id]["global_ctr"]):
                self.__print_per_tile_group_tag_stats_miss(stat_file, tg_id, tag, tile_group_stat, misses)
        self.__print_stat(stat_file, "end_lbreak")
        return   




    # print miss stat for a single item (tile or vcache bank) in its given stat file
    # item: entity id (tile x,y cooryydinates, or vcache bank number, etc.)
    # stat: data structure containing manycore stats
    # misses: list of all miss operations
    def __print_tag_stats_miss(self, stat_file, item, tag, stat, misses):
        self.__print_stat(stat_file, "tag_separator", tag)

        for miss in misses:
            # Find total number of operations for that miss
            # If operation is icache, the total is total # of instruction
            # otherwise, search for the specific instruction
            if (miss == "miss_icache"):
                operation = "icache"
                operation_cnt = stat[tag][item]["instr_total"]
            elif (miss == "miss_total"):
                operation = "hit_total"
                operation_cnt = stat[tag][item][operation] + stat[tag][item][miss]
            else:
                operation = miss.replace("miss_", "instr_")
                operation_cnt = stat[tag][item][operation] + stat[tag][item][miss] 
            miss_cnt = stat[tag][item][miss]
            hit_rate = 1 if operation_cnt == 0 else (1 - miss_cnt/operation_cnt)
         
            self.__print_stat(stat_file, "miss_data", miss, miss_cnt, operation_cnt, hit_rate )

        return


    # print miss stat for a single item (tile or vcache bank) in its given stat file
    # header - name of stats in the output stats file 
    # item: entity id (tile x,y coordinates, or vcache bank number, etc.)
    # stat: data structure containing manycore stats
    # misses: list of all miss operations
    def __print_stats_miss(self, stat_file, header, item, stat, misses):
        stat_file.write(header + "\n")
        self.__print_stat(stat_file, "miss_header", "Miss Type", "miss", "total", "hit rate")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in stat.keys():
            if(stat[tag][item]["global_ctr"]):
                self.__print_tag_stats_miss(stat_file, item, tag, stat, misses)
        self.__print_stat(stat_file, "end_lbreak")
        return


    # prints all four types of stats, timing, instruction,
    # miss and stall for the entire manycore 
    def print_manycore_stats_all(self):
        stats_path = os.getcwd() + "/stats/"
        if not os.path.exists(stats_path):
            os.mkdir(stats_path)
        manycore_stats_file = open( (stats_path + "manycore_stats.log"), "w")
        self.__print_manycore_stats_tag(manycore_stats_file)
        self.__print_manycore_stats_tile_group_timing(manycore_stats_file)
        self.__print_manycore_stats_miss(manycore_stats_file, "Per-Tag Miss Stats", self.manycore_stat, self.misses)
        self.__print_manycore_stats_stall(manycore_stats_file, "Per-Tag Stall Stats", self.manycore_stat, self.stalls)
        self.__print_manycore_stats_bubble(manycore_stats_file, "Per-Tag Bubble Stats", self.manycore_stat, self.bubbles)
        self.__print_manycore_stats_instr(manycore_stats_file, "Per-Tag Instruction Stats", self.manycore_stat, self.instrs)
        self.__print_manycore_stats_tile_timing(manycore_stats_file, "Per-Tile Timing Stats", self.active_tiles, self.manycore_stat, self.tile_stat)

        # If vcache stats is given as input, also print vcache stats
        if (self.vcache):
            s = str(self.vparser.agg)
            manycore_stats_file.write(s)
        manycore_stats_file.close()
        return

    # prints all four types of stats, timing, instruction,
    # miss and stall for each tile group in a separate file  
    def print_per_tile_group_stats_all(self):
        stats_path = os.getcwd() + "/stats/tile_group/"
        if not os.path.exists(stats_path):
            os.mkdir(stats_path)
        
        for tg_id in range(max(self.num_tile_groups.values())):
            stat_file = open( (stats_path + "tile_group_" + str(tg_id) + "_stats.log"), "w")
            self.__print_per_tile_group_stats_tag(stat_file, "Per-Tile-Group Tag Stats", tg_id, self.tile_group_stat)
            self.__print_per_tile_group_stats_timing(stat_file, "Per-Tile-Group Timing Stats", tg_id, self.manycore_stat, self.tile_group_stat)
            self.__print_per_tile_group_stats_miss(stat_file, "Per-Tile-Group Miss Stats", tg_id, self.tile_group_stat, self.misses)
            self.__print_per_tile_group_stats_stall(stat_file, "Per-Tile-Group Stall Stats", tg_id, self.tile_group_stat, self.stalls)
            self.__print_per_tile_group_stats_bubble(stat_file, "Per-Tile-Group Bubble Stats", tg_id, self.tile_group_stat, self.bubbles)
            self.__print_per_tile_group_stats_instr(stat_file, "Per-Tile-Group Instruction Stats", tg_id, self.tile_group_stat, self.instrs)

            # If vcache stats is given as input 
            if (self.vcache):
                s = str(self.vparser.group[tg_id])
                stat_file.write(s)

            stat_file.close()
        return



    # prints all four types of stats, timing, instruction,
    # miss and stall for each tile in a separate file  
    def print_per_tile_stats_all(self):
        stats_path = os.getcwd() + "/stats/tile/"
        if not os.path.exists(stats_path):
            os.mkdir(stats_path)
        for tile in self.active_tiles:
            stat_file = open( (stats_path + "tile_" + str(tile[0]) + "_" + str(tile[1]) + "_stats.log"), "w")
            self.__print_per_tile_stats_tag(stat_file, "Per-Tile Stats", tile, self.tile_stat)
            self.__print_per_tile_stats_timing(stat_file, "Per-Tile Timing Stats", tile, self.manycore_stat, self.tile_stat)
            self.__print_stats_miss(stat_file, "Per-Tile Miss Stats", tile, self.tile_stat, self.misses)
            self.__print_stats_stall(stat_file, "Per-Tile Stall Stats", tile, self.tile_stat, self.stalls)
            self.__print_stats_bubble(stat_file, "Per-Tile Bubble Stats", tile, self.tile_stat, self.bubbles)
            self.__print_stats_instr(stat_file, "Per-Tile Instr Stats", tile, self.tile_stat, self.instrs)
            stat_file.close()


    # go though the input traces and extract start and end stats  
    # for each tile, and each tile group 
    # return number of tile groups, tile group timing stats, tile stats, and cycle parallel cnt
    # this function only counts the portion between two print_stat_start and end messages
    # in practice, this excludes the time in between executions,
    # i.e. when tiles are waiting to be loaded by the host.
    # cycle parallel cnt is the absolute cycles (not aggregate), i.e. the longest interval 
    # among tiles that participate in a certain tag 
    def __generate_tile_stats(self, traces, tiles):
        tags = list(range(self.max_tags)) + ["kernel"]
        num_tile_groups = {tag:0 for tag in tags}

        tile_stat_start = {tag: {tile:Counter() for tile in tiles} for tag in tags}
        tile_stat_end   = {tag: {tile:Counter() for tile in tiles} for tag in tags}
        tile_stat       = {tag: {tile:Counter() for tile in tiles} for tag in tags}

        tile_group_stat_start = {tag: [Counter() for tg_id in range(self.max_tile_groups)] for tag in tags}
        tile_group_stat_end   = {tag: [Counter() for tg_id in range(self.max_tile_groups)] for tag in tags}
        tile_group_stat       = {tag: [Counter() for tg_id in range(self.max_tile_groups)] for tag in tags}


        # For calculating the absolute cycle count across the manycore or tile groups
        # Contrary to the manycore_stats and tile_group_stats that sum the cycne count
        # of all tiles involved in running a kernel or a tile group, this structure
        # calculates the absolute cycle count. In other words, if multiple tiles run a
        # kernel or a tile group in `parallel`, this structure calculates the interval from
        # when the earliest tile starts running, until when the latest tile stops running
        # manycore_cycle_parallel_earliest_start: minimum start cycle among all tiles involved in a tag
        # cycle_parallel_latest_test   : maximum end cycle among all tiles involved in a tag
        # cycle_parlalel_interval      : manycore_cycle_parallel_latest_end - manycore_cycle_parallel_earliest_start
        # For calculating manycore stats, all tiles are considerd to be involved
        # For calculating tile group stats, only tiles inside the tile group are considered
        # For manycore (all tiles that participate in tag are included)
        manycore_cycle_parallel_earliest_start = {tag: traces[0]["global_ctr"] for tag in tags}
        manycore_cycle_parallel_latest_end     = {tag: traces[0]["global_ctr"] for tag in tags}
        manycore_cycle_parallel_cnt       = {tag: 0 for tag in tags}

        # For each tile group (only tiles in a tile group that participate in a tag are included)
        tile_group_cycle_parallel_earliest_start = {tag: [traces[0]["global_ctr"] for tg_id in range(self.max_tile_groups)] for tag in tags}
        tile_group_cycle_parallel_latest_end     = {tag: [traces[0]["global_ctr"] for tg_id in range(self.max_tile_groups)] for tag in tags}
        tile_group_cycle_parallel_cnt            = {tag: [traces[0]["global_ctr"] for tg_id in range(self.max_tile_groups)] for tag in tags}


        tag_seen = {tag: {tile:False for tile in tiles} for tag in tags}


        for trace in traces:
            cur_tile = (trace['y'], trace['x'])

            # instantiate a CudaStatTag object with the tag value
            cst = CudaStatTag(trace["tag"])

            # Separate depending on stat type (start or end)
            if(cst.isStart):
                if(tag_seen[cst.tag][cur_tile]):
                    print ("Warning: missing end stat for tag {}, tile {},{}.".format(cst.tag, relative_x, relative_y))                    
                tag_seen[cst.tag][cur_tile] = True;

                # Only increase number of tile groups if haven't seen a trace from this tile group before
                if(not tile_group_stat_start[cst.tag][cst.tg_id]):
                    num_tile_groups[cst.tag] += 1 

                for op in self.all_ops:
                    tile_stat_start[cst.tag][cur_tile][op] = trace[op]
                    tile_group_stat_start[cst.tag][cst.tg_id][op] += trace[op]

                    # if op is cycle, find the earliest start cycle in tag among tiles in a tile group for parallel cycle stats
                    if (op == "global_ctr"):
                        tile_group_cycle_parallel_earliest_start[cst.tag][cst.tg_id] = min (trace[op], tile_group_cycle_parallel_earliest_start[cst.tag][cst.tg_id])
                        manycore_cycle_parallel_earliest_start[cst.tag] = min (trace[op], manycore_cycle_parallel_earliest_start[cst.tag])


            elif (cst.isEnd):
                if(not tag_seen[cst.tag][cur_tile]):
                    print ("Warning: missing start stat for tag {}, tile {},{}.".format(cst.tag, relative_x, relative_y))
                tag_seen[cst.tag][cur_tile] = False;

                for op in self.all_ops:
                    tile_stat_end[cst.tag][cur_tile][op] = trace[op]
                    tile_group_stat_end[cst.tag][cst.tg_id][op] += trace[op]

                    # if op is cycle, find the latest end cycle in tag among tiles in a tile group for parallel cycle stats
                    if (op == "global_ctr"):
                        tile_group_cycle_parallel_latest_end[cst.tag][cst.tg_id] = max (trace[op], tile_group_cycle_parallel_latest_end[cst.tag][cst.tg_id])
                        manycore_cycle_parallel_latest_end[cst.tag] = max (trace[op], manycore_cycle_parallel_latest_end[cst.tag])


                tile_stat[cst.tag][cur_tile] += tile_stat_end[cst.tag][cur_tile] - tile_stat_start[cst.tag][cur_tile]

            # And depending on kernel start/end
            if(cst.isKernelStart):
                if(tag_seen["kernel"][cur_tile]):
                    print ("Warning: missing Kernel End, tile: {}.".format(cur_tile))
                tag_seen["kernel"][cur_tile] = True;

                # Only increase number of tile groups if haven't seen a trace from this tile group before
                if(not tile_group_stat_start["kernel"][cst.tg_id]):
                    num_tile_groups["kernel"] += 1

                for op in self.all_ops:
                    tile_stat_start["kernel"][cur_tile][op] = trace[op]
                    tile_group_stat_start["kernel"][cst.tg_id][op] += trace[op]

                    # if op is cycle, find the earliest start cycle in kernel among tiles in a tile group for parallel cycle stats
                    if (op == "global_ctr"):
                        tile_group_cycle_parallel_earliest_start["kernel"][cst.tg_id] = min (trace[op], tile_group_cycle_parallel_earliest_start["kernel"][cst.tg_id])
                        manycore_cycle_parallel_earliest_start["kernel"] = min (trace[op], manycore_cycle_parallel_earliest_start["kernel"])


            elif (cst.isKernelEnd):
                if(not tag_seen["kernel"][cur_tile]):
                    print ("Warning: missing Kernel Start, tile {}.".format(cur_tile))
                tag_seen["kernel"][cur_tile] = False;

                for op in self.all_ops:
                    tile_stat_end["kernel"][cur_tile][op] = trace[op]
                    tile_group_stat_end["kernel"][cst.tg_id][op] += trace[op]

                    # if op is cycle, find the latest end cycle in kernel among tiles in a tile group for parallel cycle stats
                    if (op == "global_ctr"):
                        tile_group_cycle_parallel_latest_end["kernel"][cst.tg_id] = max (trace[op], tile_group_cycle_parallel_latest_end["kernel"][cst.tg_id])
                        manycore_cycle_parallel_latest_end["kernel"] = max (trace[op], manycore_cycle_parallel_latest_end["kernel"])


                tile_stat["kernel"][cur_tile] += tile_stat_end["kernel"][cur_tile] - tile_stat_start["kernel"][cur_tile]



        # Generate parallel cycle count (not aggregate, but the longest parallel interval) 
        # for the entire manycore by subtracting the earliest start cycle from the latest end cycle 
        # manycore_cycle_parallel_earliest_start: minimum start cycle among all tiles involved in a tag
        # manycore_cycle_parallel_latest_test   : maximum end cycle among all tiles involved in a tag
        # manycore_cycle_parlalel_cnt    l      : manycore_cycle_parallel_latest_end - manycore_cycle_parallel_earliest_start
        for tag in tags:
            manycore_cycle_parallel_cnt[tag]       = manycore_cycle_parallel_latest_end[tag] - manycore_cycle_parallel_earliest_start[tag]


        # Generate all tile group stats by subtracting start time from end time
        for tag in tags:
            for tg_id in range(num_tile_groups[tag]):
                tile_group_stat[tag][tg_id] = tile_group_stat_end[tag][tg_id] - tile_group_stat_start[tag][tg_id]

                # also generate parallel cycle count (not aggregate, but the longest parallel interval) 
                # for each tile group by subtracting the earliest start cycle from the latest end cycle 
                tile_group_cycle_parallel_cnt[tag][tg_id] = tile_group_cycle_parallel_latest_end[tag][tg_id] - tile_group_cycle_parallel_earliest_start[tag][tg_id]

        # Generate total stats for each tile by summing all stats 
        for tag in tags:
            for tile in tiles:
                for instr in self.instrs:
                    tile_stat[tag][tile]["instr_total"] += tile_stat[tag][tile][instr]
                for flop in self.flops:
                    tile_stat[tag][tile]["flop_total"] += tile_stat[tag][tile][flop]
                # Count fused multiply add twice as it is two instructions
                tile_stat[tag][tile]["flop_total"] += tile_stat[tag][tile]["instr_fmadd"]
                for stall in self.stalls:
                    tile_stat[tag][tile]["stall_total"] += tile_stat[tag][tile][stall]
                for bubble in self.bubbles:
                    tile_stat[tag][tile]["bubble_total"] += tile_stat[tag][tile][bubble]
                for miss in self.misses:
                    tile_stat[tag][tile]["miss_total"] += tile_stat[tag][tile][miss]
                    hit = miss.replace("miss_", "instr_")
                    tile_stat[tag][tile]["hit_total"] += tile_stat[tag][tile][hit]

        # Generate total stats for each tile group by summing all stats 
        for tag in tags:
            for tg_id in range(num_tile_groups[tag]):
                for instr in self.instrs:
                    tile_group_stat[tag][tg_id]["instr_total"] += tile_group_stat[tag][tg_id][instr]
                for flop in self.flops:
                    tile_group_stat[tag][tg_id]["flop_total"] += tile_group_stat[tag][tg_id][flop]
                # Count fused multiply add twice as it is two instructions
                tile_group_stat[tag][tg_id]["flop_total"] += tile_group_stat[tag][tg_id]["instr_fmadd"]
                for stall in self.stalls:
                    tile_group_stat[tag][tg_id]["stall_total"] += tile_group_stat[tag][tg_id][stall]
                for bubble in self.bubbles:
                    tile_group_stat[tag][tg_id]["bubble_total"] += tile_group_stat[tag][tg_id][bubble]
                for miss in self.misses:
                    tile_group_stat[tag][tg_id]["miss_total"] += tile_group_stat[tag][tg_id][miss]
                    hit = miss.replace("miss_", "instr_")
                    tile_group_stat[tag][tg_id]["hit_total"] += tile_group_stat[tag][tg_id][hit]


                # Add the parallel cycle stats (not the aggregate, i.e. the longest parallel interval)
                # to the tile group stats manually
                tile_group_stat[tag][tg_id]["cycle_parallel_cnt"] = tile_group_cycle_parallel_cnt[tag][tg_id]

        self.instrs  += ["instr_total"]
        self.stalls  += ["stall_total"]
        self.bubbles += ["bubble_total"]
        self.misses  += ["miss_total"]
        self.all_ops += ["instr_total", "flop_total", "stall_total", "bubble_total", "miss_total", "hit_total"]

        return num_tile_groups, tile_group_stat, tile_stat, manycore_cycle_parallel_cnt




    # Calculate aggregate manycore stats dictionary by summing 
    # all per tile stats dictionaries
    def __generate_manycore_stats_all(self, tile_stat, manycore_cycle_parallel_cnt):
        # Create a dictionary and initialize elements to zero
        tags = list(range(self.max_tags)) + ["kernel"]
        manycore_stat = {tag: Counter() for tag in tags}
        for tag in tags:
            for tile in self.active_tiles:
                for op in self.all_ops:
                    manycore_stat[tag][op] += tile_stat[tag][tile][op]
            # The parallel cycle count (not aggregate), i.e. the longest 
            # interval among tiles that participate in a tag in parallel 
            # is generated in __generate_tile_stats and passed to this function
            # and is added as a new entry "cycle_parallel_cnt" to the manycore_stats
            manycore_stat[tag]["cycle_parallel_cnt"] = manycore_cycle_parallel_cnt[tag]

        return manycore_stat


    # Parses stat file's header to generate list of all 
    # operations based on type (stat, instruction, miss, stall)
    def parse_header(self, f):
        # Generate lists of stats/instruction/miss/stall names
        instrs  = []
        flops   = []
        misses  = []
        stalls  = []
        bubbles = []
        stats   = []
        with open(f) as fp:
            rdr = csv.DictReader (fp, delimiter=",")
      
            header = rdr.fieldnames
            for item in header:
                if (item.startswith('instr_f')):
                    flops += [item]
                if (item.startswith('instr_')):
                    if (not item == 'instr_total'):
                        instrs += [item]
                elif (item.startswith('miss_')):
                    misses += [item]
                elif (item.startswith('stall_')):
                    stalls += [item]
                elif (item.startswith('bubble_')):
                    bubbles += [item]
                else:
                    stats += [item]

        return (stats, instrs, flops, misses, stalls, bubbles)


# parses input arguments
def add_args(parser):
    pass

def main(args): 
    st = VanillaStatsParser(args.tile, args.tile_group, args.stats, args.vcache_stats)
    st.print_manycore_stats_all()
    if(st.per_tile_stat):
        st.print_per_tile_stats_all()
    if(st.per_tile_group_stat):
        st.print_per_tile_group_stats_all()

# main()
if __name__ == "__main__":
    np.seterr(divide='ignore', invalid='ignore')
    parser = argparse.ArgumentParser(description="Vanilla Stats Parser")
    common.add_args(parser)
    add_args(parser)
    args = parser.parse_args()
    main(args)
