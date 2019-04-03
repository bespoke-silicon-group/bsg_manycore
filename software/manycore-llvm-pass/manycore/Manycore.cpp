#include "llvm/Pass.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/DataLayout.h"

using namespace llvm;

#define STRIPE 1 // Needs to match address_space set by library

class FunctionNotFound: public std::exception {
    virtual const char *what() const throw() {
        return "Error: Function not found\n";
    }
} functionNotFoundException;

// Get the size of the overall struct and the offset of the field being accessed.
// Returns -1 if we're not accessing a struct, and the offset otherwise
// The size of the struct is returned in *struct_size if the function returns
// a non-negative value
int get_struct_info(Module &M, Value *ptr_op, unsigned *struct_size) {
    DataLayout layout = DataLayout(&M);

    // Check if we're actually dealing with a struct
    if (!isa<GEPOperator>(ptr_op)) { return -1;}
    GEPOperator *gep = cast<GEPOperator>(ptr_op);
    // if GEP on array, descend until base type
    Type *source_type = gep->getSourceElementType();
    unsigned struct_start_op_idx = 2;
    while (isa<SequentialType>(source_type)) {
        source_type = cast<SequentialType>(source_type)->getElementType();
        struct_start_op_idx++;
    }
    if (!isa<StructType>(source_type)) { return -1;}

    // Work backwards through GEP Operations, computing offsets of the field being accessed to
    // get the total offset of the field into the struct
    unsigned struct_offset = 0, struct_idx;
    StructType *struct_type;
    Value *struct_idx_val;
    while ((gep != NULL) && isa<StructType>(source_type)) {
        // The last operand of GEP gives the index of the field in the struct definition
        struct_type = cast<StructType>(source_type);
        for (int i = struct_start_op_idx; i < gep->getNumOperands(); i++) {
            struct_idx_val = gep->getOperand(i);
            struct_idx = cast<ConstantInt>(struct_idx_val)->getSExtValue();
            // Get the offset of the selected field into the struct, add it to the overall offset
            struct_offset += layout.getStructLayout(struct_type)->getElementOffset(struct_idx);
            if (!isa<StructType>(struct_type->getElementType(struct_idx))) { break;}
            struct_type = cast<StructType>(struct_type->getElementType(struct_idx));
        }

        // We only care about the size of the outermost struct, but this does the same
        struct_type = cast<StructType>(source_type);
        *struct_size = layout.getTypeAllocSizeInBits(struct_type) / 8;

        // Get the GEP that preceeded the current one
        gep = dyn_cast<GEPOperator>(gep->getOperand(0));
        source_type = (gep == NULL) ? NULL : gep->getSourceElementType();
    }

    return struct_offset;
}


void replace_mem_op(Module &M, Instruction *op, bool isStore) {
    IRBuilder<> builder(op);
    Function *mem_op_fn;
    Value *ptr_op, *val_op;
    unsigned value_elem_size;
    if (isStore) {
        errs() << "Replace Store begin\n";
        ptr_op = cast<StoreInst>(op)->getPointerOperand();
        val_op = cast<StoreInst>(op)->getValueOperand();
        value_elem_size = val_op->getType()->getPrimitiveSizeInBits() / 8;
    } else {
        errs() << "Replace load begin\n";
        ptr_op = cast<LoadInst>(op)->getPointerOperand();
        value_elem_size = cast<LoadInst>(op)->getType()->getPrimitiveSizeInBits() / 8;
    }
    op->dump();


    std::vector<Value *> args_vector;
    Type *int32_ptr = Type::getInt32PtrTy(M.getContext(),
            dyn_cast<PointerType>(ptr_op->getType())->getAddressSpace());
    Type *int32 = Type::getInt32Ty(M.getContext());
    Value *ptr_bc = builder.CreatePointerCast(ptr_op, int32_ptr);

    args_vector.push_back(ptr_bc);

    if (value_elem_size == 1) {
        mem_op_fn = (isStore) ? M.getFunction("extern_store_char") :
            M.getFunction("extern_load_char");
    } else if (value_elem_size == 2) {
        mem_op_fn = (isStore) ? M.getFunction("extern_store_short") :
            M.getFunction("extern_load_short");
    } else {
        mem_op_fn = (isStore) ? M.getFunction("extern_store_int") :
            M.getFunction("extern_load_int");
    }
    if (mem_op_fn == NULL) {
        throw functionNotFoundException;
    }

    unsigned struct_size;
    int struct_off = get_struct_info(M, ptr_op, &struct_size);
    if (struct_off < 0) { // Not accessing a struct field
        args_vector.push_back(ConstantInt::get(int32, value_elem_size, false));
        args_vector.push_back(ConstantInt::get(int32, 0, false));
    } else { // Accessing a struct field
        args_vector.push_back(ConstantInt::get(int32, struct_size, false));
        args_vector.push_back(ConstantInt::get(int32, struct_off, false));
    }
    if (isStore) { args_vector.push_back(val_op);}

    ArrayRef<Value *> args = ArrayRef<Value *>(args_vector);

    // Create the call and replace all uses of the store inst with the call
    Value *new_mem_op = builder.CreateCall(mem_op_fn, args);
    op->replaceAllUsesWith(new_mem_op);

    new_mem_op->dump();
    if (isStore) {
        errs() << "Replace store done\n\n";
    } else {
        errs() << "Replace load done\n\n";
    }
}


void replace_extern_memcpy(Module &M, CallInst *op, bool isStore) {
    IRBuilder<> builder(op);
    Function *memcpy_fn;
    errs() << "Replacing memcpy\n";
    op->dump();
    if (isStore) {
        memcpy_fn = M.getFunction("extern_store_memcpy");
    } else {
        memcpy_fn = M.getFunction("extern_load_memcpy");
    }
    Type *char_ptr = Type::getInt8PtrTy(M.getContext(), 0);
    Type *int_t = Type::getInt32Ty(M.getContext());
    std::vector<Value *> args_vector;

    assert(op->getNumArgOperands() == 4); // dest, src, len, isvolatile

    // Make all arguments pointers to address space 0 so types match runtime fn
    Value *dest_ptr = op->getArgOperand(0);
    Value *src_ptr = op->getArgOperand(1);
    Value *isvol = builder.CreateIntCast(op->getArgOperand(3), int_t, false);
    // Create argument list to pass to memcpy
    args_vector.push_back(dest_ptr);
    args_vector.push_back(src_ptr);
    args_vector.push_back(op->getArgOperand(2));
    ArrayRef<Value *> args = ArrayRef<Value *>(args_vector);

    Value *new_memcpy = builder.CreateCall(memcpy_fn, args);
    op->replaceAllUsesWith(new_memcpy);
    new_memcpy->dump();
    errs() << "Memcpy replace done\n\n";
}


namespace {
    struct ManycorePass : public ModulePass {
        static char ID;
        ManycorePass() : ModulePass(ID) {}

        int64_t getGlobalVal(Module &M, StringRef name) {
            GlobalVariable *var = M.getGlobalVariable(name);
            if (var) {
                return cast<ConstantInt>(var->getInitializer())->getSExtValue();
            }
            return -1;
        }

        bool isMemcpy(Function *F) {
            if (F != NULL) {
                StringRef fname = F->getName();
                if (fname.startswith(StringRef("llvm.memcpy"))) {
                    return true;
                }
            }
            return false;
        }


        bool shouldReplaceMemcpy(CallInst *op, bool *isStore) {
            for (int i = 0; i < op->getNumArgOperands(); i++) {
                if (auto *bc = dyn_cast<BitCastInst>(op->getArgOperand(i))) {
                    if (auto *pt = dyn_cast<PointerType>(bc->getSrcTy())) {
                        if (pt->getAddressSpace() == STRIPE) {
                            *isStore = (i == 0);
                            return true;
                        }
                    }
                    if (auto *pt = dyn_cast<PointerType>(bc->getDestTy())) {
                        if (pt->getAddressSpace() == STRIPE) {
                            *isStore = (i == 0);
                            return true;
                        }
                    }
                }
            }
            return false;
        }

        class AddressSpaceException: public std::exception {
            virtual const char *what() const throw() {
                return "Invalid Address Space Encountered!\n";
            }
        } addressSpaceException;

        class StripedArrayException: public std::exception {
            virtual const char *what() const throw() {
                return "Arrays declared with STRIPE must not have initializers or be in DRAM!\n";
            }
        } stripedArrayException;

        bool runOnModule(Module &M) override {
            // If the function doesn't exist, it means that this c file didn't
            // include the striping functions.
            if (!M.getFunction("extern_load_int")) {
                return false;
            }
            std::vector<GlobalVariable *> globals_to_resize;
            std::vector<Instruction *> insts_to_remove;
            for (auto &G : M.globals()) {
                Type *g_type = G.getType();
                // If global variable is an array in address space 1
                if (isa<PointerType>(g_type) && g_type->getPointerAddressSpace() > 0) {
                    globals_to_resize.push_back(&G);
                    // Striped arrays cannot have initializers or be in DRAM at the moment
                    if (!isa<ConstantAggregateZero>(G.getInitializer()) ||
                            G.getSection().endswith(StringRef(".dram"))) {
                        throw stripedArrayException;
                    }
                }
            }
            for (auto G: globals_to_resize) {
                // We set alignment so that index 0 of an array is always on
                // core 0. Additionally, this has the effect of the start of
                // a striped array being word-aligned on individual cores,
                // which is arguably more important.
                //
                // bsg_group_size is passed via the command line
                G->setAlignment(4 * bsg_group_size);
                G->setSection(".striped.data");
            }

            for (auto &F : M) {
                for (auto &B : F) {
                    for (auto &I : B) {
                        if (isa<StoreInst>(&I) || isa<LoadInst>(&I)) {
                            unsigned addr_space;
                            bool isStore;
                            if (isa<StoreInst>(&I)) {
                                addr_space = cast<StoreInst>(I).getPointerAddressSpace();
                                isStore = true;
                            } else {
                                addr_space = cast<LoadInst>(I).getPointerAddressSpace();
                                isStore = false;
                            }
                            if (addr_space > 0 && addr_space == STRIPE) {
                                replace_mem_op(M, &I, isStore);
                                insts_to_remove.push_back(&I);
                            } else if (addr_space > 0) {
                                throw addressSpaceException;
                            }
                        } else if (auto* op = dyn_cast<CallInst>(&I)) {
                            Function *F = op->getCalledFunction();
                            if (!isMemcpy(F)) { continue;}
                            bool isStore;
                            if (shouldReplaceMemcpy(op, &isStore)) {
                                replace_extern_memcpy(M, op, isStore);
                                insts_to_remove.push_back(op);
                            }
                        }
                    }
                }
            }
            // Can't erase while iterating, so we do it here
            for (auto I : insts_to_remove) {
                I->eraseFromParent();
            }

            return true;
        }
    };
}

char ManycorePass::ID = 0;
static RegisterPass<ManycorePass> X("manycore", "Manycore addressing Pass",
        false /* Doesn't only look at CFG */,
        false /* Isn't an Analysis Pass -- modifies code */);
