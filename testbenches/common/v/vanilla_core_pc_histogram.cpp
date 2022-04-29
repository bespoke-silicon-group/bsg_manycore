#include <map>
#include <vector>
#include <sstream>
#include <string>
#include <cstdio>
#include <cstdlib>

// pc width is 24 bits
// op is 8 bits
// key width
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
            ,int op
            ,int cycles
            ) {
            fprintf(ofile()
                    ,"%s,0x%08x,%s,%d\n"
                    ,instance.c_str()
                    ,pc
                    ,opstr(op)
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

    // constants
    static constexpr int PC_WIDTH = 24;

    // constructors
    vanilla_core_pc_hist(){}

    //api
    void increment(int pc, int operation) {
        int key = make_key(pc, operation);
        auto it = _pc_hist.find(key);
        if (it != _pc_hist.end()) {
            _pc_hist[key]++;
        } else {
            _pc_hist[key]=1;
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
            int key = it->first;
            int pc = key_to_pc(key);
            int op = key_to_op(key);
            cd.write_entry(
                _instance
                ,pc
                ,op
                ,it->second
                );
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

    long make_key(int pc, int op) const {
        long lop = static_cast<long>(op);
        long lpc = static_cast<long>(pc);
        return (lop << PC_WIDTH) | (lpc & ((1l<<PC_WIDTH)-1));
    }

    int key_to_pc(long key) const {
        return key & ((1l<<PC_WIDTH)-1);
    }

    int key_to_op(long key) const {
        return (key >> PC_WIDTH) & ((1l<<(sizeof(long)*8 - PC_WIDTH))-1);
    }
private:
    // members
    std::string          _instance;
    std::map<long, int>   _pc_hist;
};

extern "C" void* vanilla_core_pc_hist_new() {
    vanilla_core_pc_hist *pc_hist = new vanilla_core_pc_hist;
    return pc_hist;
}
extern "C" void  vanilla_core_pc_hist_set_instance_name(
    void *pc_hist_vptr
    ,int x
    ,int y
    ) {
   vanilla_core_pc_hist *pc_hist
        = reinterpret_cast<vanilla_core_pc_hist*>(pc_hist_vptr);
   std::stringstream ss;
   ss << "x[" << x << "].y[" << y << "]";
   pc_hist->instance() = ss.str();
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


