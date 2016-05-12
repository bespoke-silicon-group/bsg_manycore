.globl infinite

.text
infinite:
        li t1,1
t:      sw t2,foo,t3
        bnez t1,  t
        li t1,0

        ret


.data
foo:
	.word 0

