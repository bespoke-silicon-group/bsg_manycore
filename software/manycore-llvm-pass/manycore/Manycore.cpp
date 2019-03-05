#include "llvm/Pass.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Constants.h"
using namespace llvm;

#define STRIPE 1

void replace_extern_store(Module &M, StoreInst *op) {
    IRBuilder<> builder(op);
    Function *store_fn = M.getFunction("extern_store");

    std::vector<Value *> args_vector;
    args_vector.push_back(op->getPointerOperand());

    if (auto *gep = dyn_cast<GEPOperator>(op->getPointerOperand())) {
        Value *base_arr_ptr = builder.CreateBitCast(gep->getOperand(0),
                Type::getInt32PtrTy(gep->getType()->getContext(),
                    gep->getOperand(0)->getType()->getPointerAddressSpace()));

        args_vector.push_back(base_arr_ptr);

        // Descend to find the base type of the array
        ArrayType *arr_t = cast<ArrayType>(gep->getOperand(0)->getType()->getPointerElementType());
        ArrayType *last;
        // Array referencing starts at GEP operand 2
        for (int i = 2; i < gep->getNumOperands(); i++) {
            last = arr_t;
            arr_t = dyn_cast<ArrayType>(arr_t->getElementType());
        }
        args_vector.push_back(ConstantInt::get(last->getElementType(),
                    last->getElementType()->getPrimitiveSizeInBits() / 8, false));

        args_vector.push_back(op->getValueOperand());
        ArrayRef<Value *> args = ArrayRef<Value *>(args_vector);

        // Create the call and replace all uses of the store inst with the call
        Value *new_str = builder.CreateCall(store_fn, args);
        op->replaceAllUsesWith(new_str);
        op->dropAllReferences();

        errs() << "Replace done\n";
        new_str->dump();
    }
}


void replace_extern_load(Module &M, LoadInst *op) {
    IRBuilder<> builder(op);
    Function *load_fn = M.getFunction("extern_load");
    std::vector<Value *> args_vector;
    args_vector.push_back(op->getPointerOperand());

    if (auto *gep = dyn_cast<GEPOperator>(op->getPointerOperand())) {
        Value *base_arr_ptr = builder.CreateBitCast(gep->getOperand(0),
                Type::getInt32PtrTy(gep->getType()->getContext(),
                    gep->getOperand(0)->getType()->getPointerAddressSpace()));
        args_vector.push_back(base_arr_ptr);

        // Descend to find the base type of the array
        ArrayType *arr_t = cast<ArrayType>(gep->getOperand(0)->getType()->getPointerElementType());
        ArrayType *last;
        // Array referencing starts at GEP operand 2
        for (int i = 2; i < gep->getNumOperands(); i++) {
            last = arr_t;
            arr_t = cast<ArrayType>(arr_t->getElementType());
        }
        args_vector.push_back(ConstantInt::get(last->getElementType(),
                    last->getElementType()->getPrimitiveSizeInBits() / 8, false));

        ArrayRef<Value *> args = ArrayRef<Value *>(args_vector);

        Value *new_ld = builder.CreateCall(load_fn, args);
        op->replaceAllUsesWith(new_ld);
        op->dropAllReferences();
        errs() << "Replace done\n";
        new_ld->dump();
    }
}


void resize_array(Module &M, GlobalVariable *G, int64_t cores_in_group) {
    unsigned addr_space = G->getType()->getPointerAddressSpace();
    G->dump();
    PointerType *arr_ptr_t = cast<PointerType>(G->getType());
    Type *arr_t = arr_ptr_t->getElementType();
    // Get array size
    uint64_t num_elements = 1;
    while (isa<SequentialType>(arr_t)) {
        num_elements *= arr_t->getArrayNumElements();
        arr_t = arr_t->getArrayElementType();
    }
    errs() << "Num elements = " << num_elements << "\n";
    // Allocate new array of (size/G)
    PointerType *new_arr_ptr_t = PointerType::get(
            ArrayType::get(arr_t, num_elements / cores_in_group),
            addr_space);
    Constant *G_init = G->getInitializer();
    const std::initializer_list<int32_t> initializer{0,0};
    Constant *init = ConstantDataArray::get(M.getContext(),
            ArrayRef<int32_t>(initializer));
    errs() << "Initializer\n";

    GlobalVariable *new_G = new GlobalVariable(M, new_arr_ptr_t,
            true,
            GlobalValue::ExternalWeakLinkage,
            init,
            G->getName(),
            G,
            GlobalValue::NotThreadLocal,
            addr_space);

    // Need new initializer for smaller array
    new_G->setAlignment(4);
    new_G->dump();
    // Replace all uses of old array with new array
    while (!G->use_empty()) {
        auto &U = *G->use_begin();
        U.set(new_G);
    }
    G->dropAllReferences();
    G->removeFromParent();
    errs() << "Dumping all globals\n";
    for (auto &global : M.globals()) {
        global.dump();
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
            int64_t x_dim = getGlobalVal(M, "bsg_X_len");
            int64_t y_dim = getGlobalVal(M, "bsg_Y_len");
            int64_t cores_in_group = x_dim * y_dim;
            std::vector<GlobalVariable *> globals_to_resize;
            for (auto &G : M.globals()) {
                Type *g_type = G.getType();
                // If global variable is an array in address space 1
                if (isa<PointerType>(g_type) && g_type->getPointerAddressSpace() > 0) {
                    globals_to_resize.push_back(&G);
                }
            }
            for (auto G: globals_to_resize) {
                resize_array(M, G, cores_in_group);
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
                                } else {
                                    throw addressSpaceException;
                                }
                                errs() << "\n";
                            }
                        }
                    }
                }
            }
            errs() << "Pass complete\n";
            return true;
        }
    };
}

char ManycorePass::ID = 0;
static RegisterPass<ManycorePass> X("manycore", "Manycore addressing Pass",
        false /* Doesn't only look at CFG */,
        false /* Isn't an Analysis Pass -- modifies code */);
