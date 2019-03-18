#include "llvm/Pass.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Constants.h"
using namespace llvm;

#define STRIPE 1 // Needs to match address_space set by library

class FunctionNotFound: public std::exception {
    virtual const char *what() const throw() {
        return "Error: Function not found\n";
    }
} functionNotFoundException;


void replace_extern_store(Module &M, StoreInst *op) {
    IRBuilder<> builder(op);
    Function *store_fn;

    std::vector<Value *> args_vector;
    Value *ptr_op = op->getPointerOperand();
    Type *int32_ptr = Type::getInt32PtrTy(M.getContext(),
            dyn_cast<PointerType>(ptr_op->getType())->getAddressSpace());
    Value *ptr_bc = builder.CreatePointerCast(ptr_op, int32_ptr);

    args_vector.push_back(ptr_bc);
    unsigned elem_size = op->getValueOperand()->getType()->getPrimitiveSizeInBits() / 8;
    args_vector.push_back(ConstantInt::get(Type::getInt32Ty(M.getContext()),
                elem_size, false));
    if (elem_size == 1) {
        store_fn = M.getFunction("extern_store_char");
    } else if (elem_size == 2) {
        store_fn = M.getFunction("extern_store_short");
    } else {
        store_fn = M.getFunction("extern_store_int");
    }
    if (store_fn == NULL) {
       throw functionNotFoundException;
    }
    args_vector.push_back(op->getValueOperand());

    ArrayRef<Value *> args = ArrayRef<Value *>(args_vector);

    // Create the call and replace all uses of the store inst with the call
    Value *new_str = builder.CreateCall(store_fn, args);
    op->replaceAllUsesWith(new_str);

    errs() << "Replace done\n";
    new_str->dump();
}


void replace_extern_load(Module &M, LoadInst *op) {
    IRBuilder<> builder(op);
    Function *load_fn;
    std::vector<Value *> args_vector;

    Value *ptr_op = op->getPointerOperand();
    Type *int32_ptr = Type::getInt32PtrTy(M.getContext(),
            dyn_cast<PointerType>(ptr_op->getType())->getAddressSpace());
    Value *ptr_bc = builder.CreatePointerCast(ptr_op, int32_ptr);

    args_vector.push_back(ptr_bc);
    unsigned elem_size = op->getType()->getPrimitiveSizeInBits() / 8;
    if (elem_size == 1) {
        load_fn = M.getFunction("extern_load_char");
    } else if (elem_size == 2) {
        load_fn = M.getFunction("extern_load_short");
    } else {
        load_fn = M.getFunction("extern_load_int");
    }
    if (load_fn == NULL) {
       throw functionNotFoundException;
    }

    args_vector.push_back(ConstantInt::get(Type::getInt32Ty(M.getContext()),
                elem_size, false));

    ArrayRef<Value *> args = ArrayRef<Value *>(args_vector);

    Value *new_ld = builder.CreateCall(load_fn, args);
    op->replaceAllUsesWith(new_ld);
    errs() << "Replace done\n";
    new_ld->dump();
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

        class AddressSpaceException: public std::exception {
            virtual const char *what() const throw() {
                return "Invalid Address Space Encountered!\n";
            }
        } addressSpaceException;

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
                        if (auto* op = dyn_cast<StoreInst>(&I)) {
                            if (op->getPointerAddressSpace() > 0) {
                                op->dump();
                                if (op->getPointerAddressSpace() == STRIPE) {
                                    replace_extern_store(M, op);
                                    insts_to_remove.push_back(op);
                                } else {
                                    throw addressSpaceException;
                                }
                                errs() << "\n";
                            }
                        } else if (auto* op = dyn_cast<LoadInst>(&I)) {
                            if (op->getPointerAddressSpace() > 0) {
                                op->dump();
                                if (op->getPointerAddressSpace() == STRIPE) {
                                    replace_extern_load(M, op);
                                    insts_to_remove.push_back(op);
                                } else {
                                    throw addressSpaceException;
                                }
                                errs() << "\n";
                            }
                        }
                    }
                }
            }
            // Can't erase while iterating, so we do it here
            for (auto I : insts_to_remove) {
                I->eraseFromParent();
            }

            std::vector<Function *> funcs_to_internalize;
            funcs_to_internalize.push_back(M.getFunction("extern_store_char"));
            funcs_to_internalize.push_back(M.getFunction("extern_store_short"));
            funcs_to_internalize.push_back(M.getFunction("extern_store_int"));
            funcs_to_internalize.push_back(M.getFunction("extern_load_char"));
            funcs_to_internalize.push_back(M.getFunction("extern_load_short"));
            funcs_to_internalize.push_back(M.getFunction("extern_load_int"));
            for (auto F : funcs_to_internalize) {
                Attribute attr = Attribute::get(M.getContext(), "static", "true");
                F->addAttribute(0, attr);
            }


            return true;
        }
    };
}

char ManycorePass::ID = 0;
static RegisterPass<ManycorePass> X("manycore", "Manycore addressing Pass",
        false /* Doesn't only look at CFG */,
        false /* Isn't an Analysis Pass -- modifies code */);
