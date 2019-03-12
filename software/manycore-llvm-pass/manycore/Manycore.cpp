#include "llvm/Pass.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Constants.h"
using namespace llvm;

#define STRIPE 1 // Needs to match address_space set by library

class GEPPointerException: public std::exception {
    virtual const char *what() const throw() {
        return "Error: Encountered a pointer that isn't set by a GEP instruction!\n";
    }
} gepPointerException;


void replace_extern_store(Module &M, StoreInst *op) {
    IRBuilder<> builder(op);
    Function *store_fn;

    std::vector<Value *> args_vector;
    Value *ptr_op = op->getPointerOperand();

    if (auto *gep = dyn_cast<GEPOperator>(ptr_op)) {
        Value *ptr_bc = builder.CreatePointerCast(ptr_op,
                Type::getInt32PtrTy(M.getContext(), dyn_cast<PointerType>(ptr_op->getType())->getAddressSpace()));
        args_vector.push_back(ptr_bc);

        // Descend to find the base type of the array
        ArrayType *arr_t = cast<ArrayType>(gep->getOperand(0)->getType()->getPointerElementType());
        ArrayType *last;
        // Array referencing starts at GEP operand 2
        for (int i = 2; i < gep->getNumOperands(); i++) {
            last = arr_t;
            arr_t = dyn_cast<ArrayType>(arr_t->getElementType());
        }

        // Divide by 8 for bits->bytes
        unsigned elem_size = last->getElementType()->getPrimitiveSizeInBits() / 8;
        args_vector.push_back(ConstantInt::get(Type::getInt32Ty(M.getContext()),
                    elem_size, false));

        // Different store function so we return the right size variable
        if (elem_size == 1) {
            store_fn = M.getFunction("extern_store_char");
        } else if (elem_size == 2) {
            store_fn = M.getFunction("extern_store_short");
        } else {
            store_fn = M.getFunction("extern_store_int");
        }
        args_vector.push_back(op->getValueOperand());

        ArrayRef<Value *> args = ArrayRef<Value *>(args_vector);

        // Create the call and replace all uses of the store inst with the call
        Value *new_str = builder.CreateCall(store_fn, args);
        op->replaceAllUsesWith(new_str);

        errs() << "Replace done\n";
        new_str->dump();
    } else {
        throw gepPointerException;
    }
}


void replace_extern_load(Module &M, LoadInst *op) {
    IRBuilder<> builder(op);
    Function *load_fn;
    std::vector<Value *> args_vector;
    Value *ptr_op = op->getPointerOperand();

    if (auto *gep = dyn_cast<GEPOperator>(ptr_op)) {

        Value *ptr_bc = builder.CreatePointerCast(ptr_op,
                Type::getInt32PtrTy(M.getContext(), dyn_cast<PointerType>(ptr_op->getType())->getAddressSpace()));

        args_vector.push_back(ptr_bc);
        // Descend to find the base type of the array
        ArrayType *arr_t = cast<ArrayType>(gep->getOperand(0)->getType()->getPointerElementType());
        ArrayType *last;
        // Array referencing starts at GEP operand 2
        for (int i = 2; i < gep->getNumOperands(); i++) {
            last = arr_t;
            arr_t = dyn_cast<ArrayType>(arr_t->getElementType());
        }
        // Divide by 8 for bits->bytes
        unsigned elem_size = last->getElementType()->getPrimitiveSizeInBits() / 8;

        // Different load function so we return the right size variable
        if (elem_size == 1) {
            load_fn = M.getFunction("extern_load_char");
        } else if (elem_size == 2) {
            load_fn = M.getFunction("extern_load_short");
        } else {
            load_fn = M.getFunction("extern_load_int");
        }

        args_vector.push_back(ConstantInt::get(Type::getInt32Ty(M.getContext()),
                    elem_size, false));

        ArrayRef<Value *> args = ArrayRef<Value *>(args_vector);

        Value *new_ld = builder.CreateCall(load_fn, args);
        op->replaceAllUsesWith(new_ld);
        errs() << "Replace done\n";
        new_ld->dump();
    } else {
        throw gepPointerException;
    }
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
                G->dump();
            }

            for (auto &F : M) {
                errs() << "\nI saw a function called " << F.getName() << "!\n";
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
            errs() << "BSG_GROUP_SIZE = " << bsg_group_size << "\n";
            errs() << "Pass complete\n";
            return true;
        }
    };
}

char ManycorePass::ID = 0;
static RegisterPass<ManycorePass> X("manycore", "Manycore addressing Pass",
        false /* Doesn't only look at CFG */,
        false /* Isn't an Analysis Pass -- modifies code */);
