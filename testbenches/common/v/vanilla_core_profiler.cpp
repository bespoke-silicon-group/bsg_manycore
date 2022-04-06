#include <map>
#include <vector>
#include <string>
#include <cstdio>
#include <cstdlib>
#include "profiler.hpp"

class vanilla_core_profiler : public bsg_profiler::profiler {
public:
    vanilla_core_profiler(): bsg_profiler::profiler (){}
};

vanilla_core_profiler bsg_vanilla_core_profiler;

DEFINE_PROFILER(bsg_vanilla_core_profiler);

class vanilla_core_pc_hist {
public:
    // types
    class class_data {
    public:
        // constants
        static constexpr char *FILE_NAME = "vanilla_core_pc_hist.csv";

        // constructors
        class_data()
            : _ofile(NULL) {
        }

        // api
        void register_operation(
            int operation
            ,const std::string &operation_name
            ) {
            if (operation >= _op_names.size()) {
                _op_names.resize(operation+1);
                _op_names[operation] = operation_name;
            }
        }
        const char *opstr(int op) {
            return _op_names[op].c_str();
        }
        int ops_vector_size() const {
            return _op_names.size();
        }
        FILE *ofile() {
            // open file, if not open
            if (_ofile == NULL) {
                _ofile = fopen(FILE_NAME, "w");
                // check errors
                if (_ofile == NULL) {
                    fprintf(stderr
                            , "%s: %d: could not open '%s' : %m"
                            , __FILE__
                            , __LINE__
                            , FILE_NAME
                        );
                    exit(1);
                }
                write_header();
            }
            return _ofile;
        }
        // write csv entry
        void write_entry(
            const std::string &instance
            ,int pc
            ,const std::string &opstr
            ,int cycles
            ) {
            fprintf(ofile()
                    ,"%s,0x%08x,%s,%d\n"
                    ,instance.c_str()
                    ,pc
                    ,opstr.c_str()
                    ,cycles
                );
        }

    protected:
        // helper functions
        // write csv header
        void write_header() {
            // write the header out
            fprintf(_ofile, "instance,pc,operation,cycles\n");
        }
    private:
        // members
        std::vector<std::string>   _op_names;
        FILE*                      _ofile;
    };

    // constructors
    vanilla_core_pc_hist(){}

    //api
    void increment(int pc, int operation) {
        auto it = _pc_hist.find(pc);
        if (it != _pc_hist.end()) {
            _pc_hist[pc][operation]++;
        } else {
            _pc_hist[pc] = std::vector<int>(ClassData().ops_vector_size(), 0);
            _pc_hist[pc][operation]++;
        }
    }
    std::string &instance() {
        return _instance;
    }
    void write_data() {
        class_data &cd = ClassData();
        for (auto it = _pc_hist.begin();
             it != _pc_hist.end();
             it++) {
            int pc = it->first;
            std::vector<int>& cycle_counts = it->second;
            for (int op = 0; op < cycle_counts.size(); op++) {
                if (cycle_counts[op]!=0) {
                    cd.write_entry(
                        _instance
                        ,pc
                        ,cd.opstr(op)
                        ,cycle_counts[op]
                        );
                }
            }
        }
    }

    void register_operation(
        int operation
        ,const std::string &operation_name
        ) {
        ClassData().register_operation(operation, operation_name);
    }

protected:
    // shared class data
    static class_data & ClassData() {
        static class_data _singleton;
        return _singleton;
    }

private:
    // members
    std::string                    _instance;
    std::map<int, std::vector<int>> _pc_hist;
};

extern "C" void* vanilla_core_pc_hist_new(
    const char *instance
    )
{
    vanilla_core_pc_hist *pc_hist = new vanilla_core_pc_hist;
    pc_hist->instance() = std::string(instance);
    return pc_hist;
}

extern "C" void vanilla_core_pc_hist_increment(
    void *pc_hist_vptr
    ,int pc
    ,int operation
    ) {
    vanilla_core_pc_hist *pc_hist
        = reinterpret_cast<vanilla_core_pc_hist*>(pc_hist_vptr);
    pc_hist->increment(pc, operation);
}

extern "C" void vanilla_core_pc_hist_register_operation(
    void *pc_hist_vptr
    ,int operation
    ,const char *operation_name
    ) {
   vanilla_core_pc_hist *pc_hist
        = reinterpret_cast<vanilla_core_pc_hist*>(pc_hist_vptr);
   pc_hist->register_operation(operation, operation_name);
}
extern "C" void vanilla_core_pc_hist_del(
    void *pc_hist_vptr) {
    vanilla_core_pc_hist *pc_hist
        = reinterpret_cast<vanilla_core_pc_hist*>(pc_hist_vptr);
    pc_hist->write_data();
    delete pc_hist;
}
