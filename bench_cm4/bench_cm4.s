	.syntax	unified
	.cpu	cortex-m4
	.file	"bench_cm4.s"
	.text

	.equ	SYSCNT_ADDR, 0xE0001004

@ =======================================================================
@ This macro defines a public function ('name') that calls another function
@ ('target') and measures its execution time. That time is returned (in
@ clock cycles). Incoming parameters (up to four registers) are passed
@ through to the target; the target's returned value is discarded.
@ =======================================================================
.macro	BENCH	name, target
	.align	2
	.global	\name
	.thumb
	.thumb_func
	.type	\name, %function
\name:
	push.w	{ r10, r11, lr }
	movw	r11, #(SYSCNT_ADDR & 0xFFFF)
	movt	r11, #(SYSCNT_ADDR >> 16)
	ldr.w	r10, [r11]
	bl	\target
	ldr.w	r0, [r11]
	sub.w	r0, r0, r10
	pop	{ r10, r11, pc }
	.size	\name,.-\name
.endm

BENCH	bench_none,               do_nothing
BENCH	bench_of32,               fndsa_fpr_of32
BENCH	bench_scaled,             fndsa_fpr_scaled
BENCH	bench_add,                fndsa_fpr_add
BENCH	bench_sqr,                fndsa_fpr_sqr
BENCH	bench_mul,                fndsa_fpr_mul
BENCH	bench_div,                fndsa_fpr_div
BENCH	bench_sqrt,               fndsa_fpr_sqrt
BENCH	bench_keccak,             fndsa_sha3_process_block
BENCH	bench_NTT_q,              fndsa_mqpoly_int_to_ntt
BENCH	bench_iNTT_q,             fndsa_mqpoly_ntt_to_int
BENCH	bench_NTT_q2,             fndsa_mq2poly_NTT
BENCH	bench_iNTT_q2,            fndsa_mq2poly_iNTT
BENCH   bench_hash_to_point,      fndsa_hash_to_point
BENCH	bench_FFT_int32,          fndsa_fpoly_FFT_int32
BENCH	bench_FFT_int32_selfadj,  fndsa_fpoly_FFT_int32_selfadj

@ A do-nothing function, used for calibration. Its inherent cost should
@ be 2 cycles (a single 'bx lr' opcode).
	.align	2
	.thumb
	.thumb_func
	.type	do_nothing, %function
do_nothing:
	bx	lr
	.size	do_nothing,.-do_nothing

@ A special bench function for fndsa_fpr_add_sub, which uses a non-standard
@ ABI and requires the caller to save many more registers.
	.align	2
	.global	bench_add_sub
	.thumb
	.thumb_func
bench_add_sub:
	push.w	{ r4, r5, r6, r7, r8, r10, r11, lr }
	movw	r11, #(SYSCNT_ADDR & 0xFFFF)
	movt	r11, #(SYSCNT_ADDR >> 16)
	vmov	s1, r11
	ldr.w	r10, [r11]
	vmov	s0, r10
	bl	fndsa_fpr_add_sub
	vmov	r11, s1
	ldr.w	r0, [r11]
	vmov	r10, s0
	sub.w	r0, r0, r10
	pop	{ r4, r5, r6, r7, r8, r10, r11, pc }
	.size	bench_add_sub,.-bench_add_sub

@ ==========================================================================
@ void prepare_stack(void)
@ ==========================================================================

	.align	2
	.global	prepare_stack
	.thumb
	.thumb_func
	.type	prepare_stack, %function
prepare_stack:
	ldr	r0, Lmeasure_stack__addr
	mov	r3, sp
	str	r3, [r0]
	movw	r1, #0x83FE
	movt	r1, #0xA7C0
	movs	r2, #512
Lprepare_stack__L1:
	push	{ r1 }
	subs	r2, #1
	bne	Lprepare_stack__L1
	mov	sp, r3
	bx	lr
	.size	prepare_stack, .-prepare_stack

@ ==========================================================================
@ size_t measure_stack(void)
@ ==========================================================================

	.align	2
	.global	measure_stack
	.thumb
	.thumb_func
	.type	measure_stack, %function
measure_stack:
	ldr	r0, Lmeasure_stack__addr
	ldr	r3, [r0]
	sub	r3, #2048
	movw	r1, #0x83FE
	movt	r1, #0xA7C0
	movs	r2, #512
Lmeasure_stack__L1:
	ldr	r12, [r3], #4
	cmp	r12, r1
	bne	Lmeasure_stack__L2
	subs	r2, #1
	bne	Lmeasure_stack__L1
Lmeasure_stack__L2:
	lsls	r0, r2, #2
	bx	lr
Lmeasure_stack__addr:
	.word	measure_stack_savesp__ANCHOR
	.size	measure_stack, .-measure_stack

	.bss
	.align	2
	.set	measure_stack_savesp__ANCHOR, .
	.type	measure_stack_savesp, %object
measure_stack_savesp:
	.space	4
	.size	measure_stack_savesp, .-measure_stack_savesp
