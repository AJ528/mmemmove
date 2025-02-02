
  @ tells the assembler to use the unified instruction set
  .syntax unified
  @ this directive selects the thumb (16-bit) instruction set
  .thumb
  @ this directive specifies the following symbol is a thumb-encoded function
  .thumb_func
  @ align the next variable or instruction on a 2-byte boundary
  .align 2
  @ make the symbol visible to the linker
  .global memmove_new
  @ marks the symbol as being a function name
  .type memmove_new, STT_FUNC
memmove_new:
@ r0 = destination addr
@ r1 = source addr
@ r2 = num bytes
@ returns destination addr in r0
  cmp   r2, #0            @ if there are 0 bytes to move
  push  {r4, r5}          @ store r4 & r5 values on stack
  beq   exit              @ exit

  add   r3, r1, r2      @ calculate final source address + 1 and store in r3
  subs  r5, r0, r1      @ subtract source addr from destination addr, update flags, and store result in r5
  blo   copy_f          @ if destination < source (source ahead), copy forward
  beq   exit            @ if source=destination, nothing to do

@ source is behind destination, check for overlap
  cmp   r0, r3          @ compare first destination addr against final source address + 1
  bhs   copy_f          @ if the first destination addr is >= final source addr + 1, there is no overlap

@ otherwise we must copy backwards
  add   r4, r0, r2      @ calculate final destination addr + 1 and store in r4
  cmp   r2, #4          @ check if there are 4 or more bytes to copy
  blo   copy_bck_single @ if not, copy one at a time
  cmp   r2, #16         @ check if there are 16 or more bytes to copy
  blo   quad_b_copy     @ if not, copy 4 bytes at a time
  tst   r5, #3          @ check if dest-source is a multiple of 4
  bne   quad_b_copy     @ if not, copy 4 bytes at a time
  tst   r1, #3          @ check if the source address is 4-byte aligned
  bne   quad_b_copy     @ if not, copy 4 bytes at a time

  @ if there are 16 or more bytes to copy and the src and dest are 4-byte aligned, can copy word-wise
quad_word_b_copy:
  sub   r2, r2, #16     @ decrement remaining bytes by 4
  ldr   r5, [r3, #-4]        @ load word from memory[r1] into r5
  str   r5, [r4, #-4]        @ store r5 word into memory[r4]
  ldr   r5, [r3, #-8]    @ load word from memory[r1+4] into r5
  str   r5, [r4, #-8]    @ store r5 word into memory[r4+4]
  ldr   r5, [r3, #-12]
  str   r5, [r4, #-12]
  ldr   r5, [r3, #-16]
  str   r5, [r4, #-16]
  cmp   r2, #16          @ check if there are 16 or more bytes to copy
  sub   r3, r3, #16
  sub   r4, r4, #16
  bhs   quad_word_b_copy     @ if so, quad copy again
  cmp   r2, #4          @ if there are 4 or more bytes to copy
  bhs   quad_b_copy
  cmp   r3, r1          @ check if we are at the final source address
  bne   copy_bck_single @ if not, finish with single byte copying
  b     exit            @ otherwise, exit

quad_b_copy:            @ copy backwards 4 bytes at a time
  sub   r2, r2, #4      @ decrement remaining bytes by 4
  ldrb  r5, [r3, #-1]   @ load byte from memory[r3-1] into r5
  strb  r5, [r4, #-1]   @ store r5 byte into memory[r4-1]
  ldrb  r5, [r3, #-2]   @ load byte from memory[r3-2] into r5
  strb  r5, [r4, #-2]   @ store r5 byte into memory[r4-2]
  ldrb  r5, [r3, #-3]   @ continue for next 2 bytes
  strb  r5, [r4, #-3]
  ldrb  r5, [r3, #-4]
  strb  r5, [r4, #-4]
  cmp   r2, #4          @ check if there are 4 or more bytes to copy
  sub   r4, r4, #4
  sub   r3, r3, #4
  bhs   quad_b_copy     @ if so, quad copy again
  
  cmp   r3, r1          @ check if we are at the final source address
  beq     exit          @ if so, exit
@ otherwise, there are <4 bytes left to copy

copy_bck_single: 
  ldrb  r5, [r3, #-1]!  @ load byte from memory[r3-1] into r5. r3 is updated to r3-1
  strb  r5, [r4, #-1]!  @ store r5 byte into memory[r4-1]. r4 is updated to r4-1
  cmp   r1, r3          @ check if we are at the first source address
  bne   copy_bck_single @ if not done, repeat
  b     exit

@ copy forwards
copy_f:                 @ copy from beginning of source and work forwards
  mov   r4, r0          @ copy destination addr into r4
  cmp   r2, #4          @ check if there are 4 or more bytes to copy
  blo   copy_fwd_single @ if not, copy one at a time
  cmp   r2, #16         @ check if there are 16 or more bytes to copy
  blo   quad_f_copy     @ if not, copy 4 bytes at a time
  tst   r5, #3          @ check if dest-source is a multiple of 4
  bne   quad_f_copy     @ if not, copy 4 bytes at a time
  tst   r1, #3          @ check if the source address is 4-byte aligned
  bne   quad_f_copy     @ if not, copy 4 bytes at a time

@ if there are 16 or more bytes to copy and the src and dest are 4-byte aligned, can copy word-wise
quad_word_f_copy:
  sub   r2, r2, #16     @ decrement remaining bytes by 4
  ldr   r5, [r1]        @ load word from memory[r1] into r5
  str   r5, [r4]        @ store r5 word into memory[r4]
  ldr   r5, [r1, #4]    @ load word from memory[r1+4] into r5
  str   r5, [r4, #4]    @ store r5 word into memory[r4+4]
  ldr   r5, [r1, #8]
  str   r5, [r4, #8]
  ldr   r5, [r1, #12]
  str   r5, [r4, #12]
  cmp   r2, #16          @ check if there are 16 or more bytes to copy
  add   r4, r4, #16
  add   r1, r1, #16
  bhs   quad_word_f_copy     @ if so, quad copy again
  cmp   r2, #4          @ if there are 4 or more bytes to copy
  bhs   quad_f_copy
  cmp   r3, r1          @ check if we are at the final source address
  bne   copy_fwd_single @ if not, finish with single byte copying
  b     exit            @ otherwise, exit

quad_f_copy:
  sub   r2, r2, #4      @ decrement remaining bytes by 4
  ldrb  r5, [r1]        @ load byte from memory[r1] into r5
  strb  r5, [r4]        @ store r5 byte into memory[r4]
  ldrb  r5, [r1, #1]    @ load byte from memory[r1+1] into r5
  strb  r5, [r4, #1]    @ store r5 byte into memory[r4+1]
  ldrb  r5, [r1, #2]
  strb  r5, [r4, #2]
  ldrb  r5, [r1, #3]
  strb  r5, [r4, #3]
  cmp   r2, #4          @ check if there are 4 or more bytes to copy
  add   r4, r4, #4
  add   r1, r1, #4
  bhs   quad_f_copy     @ if so, quad copy again

  cmp   r3, r1          @ check if we are at the final source address
  beq   exit            @ if so, exit
@ otherwise, there are <4 bytes left to copy forward

copy_fwd_single:
  ldrb  r5, [r1], #1    @ load byte from memory[r1] into r5. r1 is updated to r1+1
  strb  r5, [r4], #1    @ store r5 byte into memory[r4]. r4 is updated to r4+1
  cmp   r3, r1          @ check if we are at the final source address
  bne   copy_fwd_single @ if not done, repeat

exit:
  pop   {r4, r5}        @ restore previous value of r4 & r5
  bx    lr              @ exit function

  .size memmove_new, . - memmove_new 

