# OKF kernel.

#
# Adjust the following to taste.  All sizes are in bytes.
# 
        okf_dict_size        = 65536
        okf_in_fd_block_size = 1024
        okf_stack_size       = 16384

#
# From here on, you should not alter anything unless you are
# sure you know what you are doing.
#
        okf_cell_size = 4
        okf_char_size = 1
        okf_p_end_marker = 0
        okf_syscall = 0x80
        okf_syscall_exit = 0x1
        okf_syscall_read = 0x3
        okf_syscall_write = 0x4
        okf_syscall_open = 0x5
        okf_syscall_close = 0x6
        okf_exit_success = 0x0
        okf_exit_failure = 0x1

        okf_dh_len    = 0
        okf_dh_next   = okf_dh_len  + okf_char_size
        okf_dh_exec   = okf_dh_next + okf_cell_size
        okf_dh__size  = okf_dh_exec + okf_cell_size

        okf_opcode_call = 0xE8      # see bib.pentium.opcode.call
        okf_opcode_ret  = 0xC3      # see bib.pentium.opcode.ret

#
# Input structure
#
        okf_in_refill    = 0
        okf_in_name      = okf_in_refill    + okf_cell_size
        okf_in_p         = okf_in_name      + okf_cell_size
        okf_in_s         = okf_in_p         + okf_cell_size
        okf_in_e         = okf_in_s         + okf_cell_size
        okf_in_last_char = okf_in_e         + okf_cell_size
        okf_in__size     = okf_in_last_char + okf_cell_size

#
# File Input Structure
#
        okf_in_fd_fd    = okf_in__size
        okf_in_fd_bs    = okf_in_fd_fd + okf_cell_size
        okf_in_fd__size = okf_in_fd_bs + okf_cell_size

	.include "okf-vars.s"
        .text
        .global _start
_start: 
	.include "okf-vars-init.s"
        leal    okf_stack_end, %ebp

#
# If there is a argument, assume it is a OKF file and try and boot from it.
# Conventionally a shell would try and boot from stdin if there is no 
# argument so that you can use it interactively.  However, the OKF kernel
# is so minimal there is little you can do other than type in HEX encoded
# assembler definitions of the primitives you want to add to OKF.  This is
# is not likely to be a commonly used feature and so it has been left out.
# If you do want an interactive Forth shell, then (assuming that OKF is
# installed in /usr/local/bin and its support files are in /usr/local/lib/okf)
# then create a file containing :-
#
#   #! /usr/local/bin/okf
#   #< /usr/local/lib/okf/ans-core.okf
#   #< /usr/local/lib/okf/ans-core-ext.okf
#   0 #{
#
# make it executable and you now have a shell that contains all the ANS
# core Forth definitions loaded.
#
	popl	%eax
	cmpl	$2, %eax
	jb	okf_abort
	movl	%eax, okf_argc
	movl	%esp, okf_argv
	movl	okf_cell_size(%esp), %ebx             # file-name
	call	okf_boot_from_file
okf_exit:
        movl    $okf_syscall_exit, %eax
        movl    $okf_exit_success, %ebx
        int     $okf_syscall

#
# interpreter loop ...
#
okf_loop:
        movl    okf_dict_here, %edi
        movl    okf_in_current, %ebx
        call    okf_in_wsw
        testl   %eax, %eax
        jle     okf_loop_end
        movl    okf_dict_top, %edx   
        call    okf_dict_find   
        testl   %edx, %edx
        jz      okf_loop_not_found
	movl	okf_defined_vector, %ebx
	call	*%ebx
        jmp     okf_loop
okf_loop_not_found:
	# uses %ebx since this will usually end up calling okf_number_default
	# which has its own register requirements.
	movl	okf_undefined_vector, %ebx
	call	*%ebx
	jmp	okf_loop
okf_loop_end:   
        ret


# inputs:
#   %eax = length of the word-name.
#   %edx = start of word header.
#   %edi = start of word-name.
# trashes: %eax
# outputs: 
#   depends on the execution semantics of the word being called
okf_defined_interpret:
	leal	okf_dh__size(%edx), %eax
	jmp	*%eax


# inputs:
#   %eax = length of the string.
#   %ebx = %eip
#   %esi = start of string.
# trashes: %eax %ebx %esi
# outputs: 
#   %ecx = 0 if %esi' is a number
#   %ebp = %ebp' - 4
#   %edi = the number
#   (%ebp') = %edi
okf_number_interpret:
	movl	okf_number_vector, %ebx
	call	*%ebx
	testl	%ecx, %ecx
	jne	okf_abort
        movl    %edi, -okf_cell_size(%ebp)
        subl    $okf_cell_size, %ebp
	ret	


# okf_comp_default - default word compiler
#   This plants a call instruction to the execution semantics of the
#   word whose dictionary header is in %edx and updates HERE.
#
# inputs:
#   %edx - DH
# trashes:
#   %eax %edi
okf_comp_default:
        movl    okf_dict_here, %edi
        movb    $okf_opcode_call, (%edi)
        leal    okf_dh__size(%edx), %eax
        subl    %edi, %eax
        subl    $(okf_char_size+okf_cell_size), %eax  # size of call.
        movl    %eax, okf_char_size(%edi)
        addl    $(okf_char_size+okf_cell_size), %edi  # size of call.
        movl    %edi, okf_dict_here
        ret

#
# for now just abort ...
#
okf_abort:
	movl	okf_abort_vector, %eax
	jmp	*%eax

okf_abort_default:
        movl    $okf_syscall_exit, %eax
        movl    $okf_exit_failure, %ebx
        int     $okf_syscall


# Read a whitespace delimited word from the input.
# 
# input:
#   %ebx - address of input descriptor
#   %edi - address of string pad
# outputs:
#   %eax = > 0 - length of word
#          = 0 - end of input
#          < 0 - error 
#   %ebx = %ebx'
#   %esi = address of first char in word
#   %edi = address of last char in word + 1

okf_in_wsw:     
        pushl   %edi
okf_in_wsw_restart:
        movl    okf_in_p(%ebx), %esi
okf_in_wsw_find_start:
        lodsb   
        cmpb    $' ', %al
        je      okf_in_wsw_find_start
        cmpb    $'\n', %al
        je      okf_in_wsw_nl_in_ws
okf_in_wsw_found_start: 
        stosb
okf_in_wsw_next_word_char:
        lodsb
        cmpb    $'\n', %al
        je      okf_in_wsw_nl_in_word
        cmpb    $' ', %al
        jne     okf_in_wsw_found_start
okf_in_wsw_found_end:
        movl    %esi, okf_in_p(%ebx)
        popl    %esi
        movl    %edi, %eax
        subl    %esi, %eax
        ret

#
# A '\n' has been detected when skipping whitespace.
# It could be a normal '\n' or it could be the '\n' that signifies
# the end of the buffer ...
#
okf_in_wsw_nl_in_ws:
        cmp     %esi, okf_in_e(%ebx)
        jne     okf_in_wsw_find_start
#
# The '\n' marks the end of the buffer.  If the charater the '\n' replaced
# is also whitespace then need to refill the buffer ...
#
        movb    okf_in_last_char(%ebx), %al
        cmpb    $'\n', %al
        je      okf_in_wsw_nl_in_ws_ws
        cmpb    $' ', %al
        je      okf_in_wsw_nl_in_ws_ws
#
# The character the '\n' replaced is not whitespace so it starts a word.
# Copy the saved character to the output buffer and refill the input 
# buffer
#
        stosb
        call    *okf_in_refill(%ebx)
        testl   %eax, %eax
        jle     okf_in_wsw_nl_in_ws_error_or_finish
        movl    okf_in_p(%ebx), %esi
        jmp     okf_in_wsw_next_word_char
okf_in_wsw_nl_in_ws_ws:
        call    *okf_in_refill(%ebx)
        testl   %eax, %eax
        jg      okf_in_wsw_restart
okf_in_wsw_nl_in_ws_error_or_finish:
        popl    %edi
        ret

#
# A '\n' has been detected when scanning for the end of a word.
# It could be a normal '\n' or it could be the '\n' that signifies
# the end of the buffer ...
#
okf_in_wsw_nl_in_word:
        cmpl    %esi, okf_in_e(%ebx)
        jne     okf_in_wsw_nl_in_word_end
#
# The '\n' marks the end of the buffer.  If the charater the '\n' replaced
# is also whitespace then the end of the word has been found ...
#
        movb    okf_in_last_char(%ebx), %al
        cmpb    $'\n', %al
        je      okf_in_wsw_nl_in_word_end
        cmpb    $' ', %al
        je      okf_in_wsw_nl_in_word_end
#
# The saved character is not whitespace, so copy the saved character to
# the output buffer and refill the input buffer ...
#
        stosb
        call    *okf_in_refill(%ebx)
        movl    okf_in_p(%ebx), %esi
        testl   %eax, %eax
	jg	okf_in_wsw_next_word_char
okf_in_wsw_nl_in_word_error_or_finish:
        popl    %edi
        ret
okf_in_wsw_nl_in_word_end:
	decl	%esi
	jmp	okf_in_wsw_found_end


# okf_in_fd_refill - refill the input buffer from a file descriptor.
#
#   Note this should not be called directly, it should be placed in
#   the okf_in_refill slot of a input buffer attached to a file descriptor.
#   
# input:
#   %ebx - input file descriptor
# trashes:
#   %eax %ecx %edx
# output:
#   %eax - > 0 - nchars read
#          = 0 - end of input
#          < 0 - error 
#   %ebx = %ebx'
#
okf_in_fd_refill:
        movl    okf_in_s(%ebx), %ecx
        movl    %ecx, okf_in_p(%ebx)
        movl    okf_in_fd_bs(%ebx), %edx
        pushl   %ebx
        movl    okf_in_fd_fd(%ebx), %ebx
        movl    $okf_syscall_read, %eax
        int     $okf_syscall
        popl    %ebx
        testl   %eax, %eax
        jle     okf_in_fd_refill_in_ws_error_or_finish
        addl    %eax, %ecx
        movl    %ecx, okf_in_e(%ebx)
        movb    -okf_char_size(%ecx), %dl
        movb    %dl, okf_in_last_char(%ebx)
        movb    $'\n', -okf_char_size(%ecx)
okf_in_fd_refill_in_ws_error_or_finish:
        ret



# okf_in_fd_name - output the name of the input buffer.
# 
#   Note this should not be called directly, it should be placed in
#   the okf_in_name slot of a input buffer attached to a file descriptor.
#
# inputs:
#   %eax - output descriptor
#   %ebx - input file buffer
# trashes:
#   %ebx %ecx %edx
# outputs:
#   %eax - ?
# XXX patch this.
okf_in_fd_name:
        ret


# Skip all the input chars up to an including the given character.
# 
# input:
#   %ebx - address of input descriptor
#   %cl  - char to skip to.
# trashes:
#   %esi
# output:
#   %ebx = %ebx'
#   %eax = ...
#
okf_in_skip:
        movl    okf_in_p(%ebx), %esi
okf_in_skip_next:
        lodsb
        cmpb    $'\n', %al
        je      okf_in_skip_nl
okf_in_skip_check_char:
        cmpb    %cl, %al
        jne     okf_in_skip_next
okf_in_skip_found:
        movl    %esi, okf_in_p(%ebx)    
        movl    $1, %eax
        ret     

okf_in_skip_nl:
        cmpl    %esi, okf_in_e(%ebx)
        jne     okf_in_skip_check_char
#
# Have reached the last character in the block.  
# If the character that is being looked for is the saved character, then
# If the character being looked for is not the saved character, then
# just refill the buffer and carry on looking for it.
#
okf_in_skip_block_end:
        movb    okf_in_last_char(%ebx), %al
        cmpb    %cl, %al
        je      okf_in_skip_found_as_last_char
        pushl   %ecx
        call    *okf_in_refill(%ebx)
        popl    %ecx
        testl   %eax, %eax
        jg      okf_in_skip
        ret

okf_in_skip_found_as_last_char:
        movb    $'\n', okf_in_last_char(%ebx)
        decl    %esi
	jmp	okf_in_skip_found


#
# inputs:
#  %esi = start of string
#  %eax = length of string if not null terminated
# trashes:
#  %eax %ebx
# outputs:
#  %ecx = 0 if string is a number
#  %edi = number
#
okf_atou:
        movl    %eax, %ecx
        xorl    %edi, %edi
        movl    okf_base, %ebx
okf_atou_loop:
        lodsb
        testb   %al, %al
        jz      okf_atou_nul
        subb    $'0', %al
        jl      okf_atou_not_digit
        cmpb    $('9'-'0'+1), %al
        jl      okf_atou_digit
        subb    $7, %al               # map 'A' .. 'F' down to 10 .. 15
        jl      okf_atou_not_digit
        cmpb    $16, %al
        jl      okf_atou_digit
        subb    $32, %al              # map 'a' .. 'f' down to 10 .. 15
        jl      okf_atou_not_digit
        cmpb    $16, %al
        jge     okf_atou_not_digit
okf_atou_digit:
        cbw
        cwde
        cmpl    %ebx, %eax
        jge     okf_atou_not_digit
        xchgl   %edi, %eax
        mull    %ebx
        addl    %eax, %edi
        decl    %ecx
        jne     okf_atou_loop
okf_atou_not_digit:
        ret
okf_atou_nul:
        xorl    %ecx, %ecx
        ret


# okf_dict_find - locate a string in the dictionary.
#
#   Note that whilst the input length is 32-bit, only 8-bits (%al) are
#   actually taken notice of.
#
# inputs:
#   %eax - length
#   %esi - string
#   %edx - dictionary top
# trashes:
#   %ecx
# outputs:
#   %edx = header of found word (i.e. address of name length in the header).
#   (%edx != 0  /\  %eax = %eax'  /\  %edi = %esi'  /\   %esi = %esi' + %eax)
#   \/
#   (%edx = 0  /\  %esi = %esi'  /\  %eax = %eax')
#
okf_dict_find:
        testl   %edx, %edx
        je      okf_dict_find_fail
        cmpb    %al, (%edx)
        je      okf_dict_find_check_str
        movl    okf_dh_next(%edx), %edx
        jmp     okf_dict_find
okf_dict_find_check_str:
        pushl   %esi
        movl    %edx, %edi
        subl    %eax, %edi
        movl    %eax, %ecx
        repe
        cmpsb
        je      okf_dict_find_found
        popl    %esi
        movl    okf_dh_next(%edx), %edx
        jmp     okf_dict_find
okf_dict_find_found:
        popl    %edi
        ret
okf_dict_find_fail:
        xor     %edx, %edx
        ret


# c-addr u -- xt | 0
#
okf_p_find_exec:
        movl    (%ebp), %eax
        movl    okf_cell_size(%ebp), %esi
        movl    okf_dict_top, %edx   
        call    okf_dict_find   
        testl   %edx, %edx
        jz      okf_p_find_exec_result
        addl    $okf_dh__size, %edx
okf_p_find_exec_result:
        movl    %edx, okf_cell_size(%ebp)
        addl    $okf_cell_size, %ebp
        ret


# <spaces>name -- c-addr u
# Skip leading spaces and parse <code>name</code> delimited by
# whitespace.  <code>c-addr</code> is the address of the start
# of the string that was read in and stored at HERE and <code>u</code>
# is the length of the string.  This is approximately what
# PARSE-WORD does in some other implementations.
okf_p_in_word_exec: # -- ( str len )
        movl    okf_dict_here, %edi
        movl    okf_in_current, %ebx
        call    okf_in_wsw
        testl   %eax, %eax
        jle     okf_abort
        movl    %esi, -okf_cell_size(%ebp)
        movl    %eax, -(2*okf_cell_size)(%ebp)
        subl    $(okf_cell_size*2), %ebp
        ret


# ( u -- x )
# <code>#%</code> is a mechanism for making available various OKF system
# variables.  <code>u</code> should be in the range 0 - 8 inclusive.
#
        .ascii "#%"
okf_p_vars: # n -- addr
        .byte 2
        .long okf_p_end_marker
        .long okf_comp_default
#
# The extra label okf_debug_break is here because #% is a handy thing
# to breakpoint when debugging a minimal OKF since it is one of the
# few things that is not called that often.  For example, stick
#
#  9 #% 
#
# somewhere in a file and then under gdb do :-
#
#  b okf_debug_break
#  condition 1 (*(int *)$ebp == 9)
#
# Note the value 9 is arbitrary, anything out of range will do.
#
okf_debug_break:
okf_p_vars_exec:
        leal    okf_argc, %ebx
        movl    (%ebp), %eax
        leal    (%ebx, %eax, 4), %eax
        movl    %eax, (%ebp)
        ret


# compilation:
#   perform the execution semntics given below
# execution: "ccc<eol>" --
#   Skip everything up to and including next \n in the input.
#
# Equivalent to ANS FORTH CORE \.
# This is the default since it makes it possible to write OKF scripts
# that will be automatically executed if they start with <code>#!</code>
# followed by the executable name.  For example, if OKF is installed
# as <code>/usr/local/bin/okf</code>, you can create an ANS FORTH shell
# like :-
#
#   $ cat ans-forth
#   #! /usr/local/bin/okf
#   #< ans-core.okf
#   0 #{
#
# Note that if you alter okf_p_line_comment_exec in any way, check with
# <code>(</code> in ans-core.okf which jumps directly into it.
#
        .ascii "#!"
okf_p_line_comment:
        .byte 2
        .long okf_p_vars
        .long okf_p_line_comment_exec
okf_p_line_comment_exec:
        movb    $'\n', %cl
        movl    okf_in_current, %ebx
        call    okf_in_skip
        testl   %eax, %eax
        jle     okf_abort
        ret


# ANS FORTH CORE ,
# ( x -- )
# Reserve one cell of data space and store <code>x</code> in the cell.
# If the data space is aligned when <code>,</code> begins execution,
# it will remain aligned when <code>,</code> finishes execution.  
        .ascii ","
okf_p_dict_store_4: # x --
        .byte 1
        .long okf_p_line_comment
        .long okf_comp_default
okf_p_dict_store_4_exec:
        movl    (%ebp), %eax
        movl    okf_dict_here, %edi
        stosl
        movl    %edi, okf_dict_here
        addl    $okf_cell_size, %ebp
        ret


# ANS FORTH FILE INCLUDE-FILE
# ( i*x fileid -- j*x )
# Remove <code>filid</code> from the stack and use it as a file descriptor
# from which to read the input.  Aborts if <code>fileid</code> is not a 
# valid file descriptor.
        .ascii "#{"
okf_p_input_from_fd:
        .byte 2
        .long okf_p_dict_store_4
        .long okf_comp_default
okf_p_input_from_fd_exec:
	xorl	%ebx, %ebx              # null file-name
	movl	(%ebp), %eax
        addl    $okf_cell_size, %ebp
okf_p_input_from_fd_for_file:
	pushl	%eax
	pushl	okf_in_current
        leal    -okf_in_fd__size(%esp), %edi
	movl	%edi, okf_in_current
        leal    -(okf_in_fd__size+okf_in_fd_block_size)(%esp), %ecx
        leal    okf_in_fd_refill, %eax
        stosl                           # okf_in_refill
        movl    %ebx, %eax
        stosl                           # okf_in_name
        movl    %ecx, %eax
        stosl                           # okf_in_p
        stosl                           # okf_in_s
        movb    $'\n', (%eax)
        incl    %eax
        stosl                           # okf_in_e
        movb    $'\n', %al
        stosl                           # okf_in_last_char
        movl    4(%esp), %eax           # okf_in_fd_fd
        stosl
        movl    $okf_in_fd_block_size, %eax
        stosl                           # okf_in_fd_bs
        movl    %ecx, %esp
        call    okf_loop
	addl	$(okf_in_fd__size+okf_in_fd_block_size), %esp
        popl    okf_in_current
        popl    %ebx
	ret

# ( "<spaces>name" -- )
# Parse a <code>name</code> and use it as the name of a file from which
# to read input from.
# Similar to ANS FORTH FILE INCLUDED.
        .ascii "#<"
okf_p_input_from_file:
        .byte 2
        .long okf_p_input_from_fd
        .long okf_comp_default
okf_p_input_from_file_exec:
        call    okf_p_in_word_exec
        addl    $(okf_cell_size*2), %ebp
        movl    %esi, %ebx
        movb    $0, (%esi, %eax)               # null terminate.
okf_boot_from_file:
        xorl    %ecx, %ecx                     # O_RDONLY
        movl    $okf_syscall_open, %eax
        int     $okf_syscall
        testl   %eax, %eax
        jl      okf_abort
	call	okf_p_input_from_fd_for_file
        movl    $okf_syscall_close, %eax
        int     $okf_syscall
        # don't bother testing result.
        ret


# ( "<spaces>name" -- )
# Skip leaing whitespace.  Parse <code>name</code> delimited by
# whitespace.  Create a definition for <code>name</code>.
#
# Unlike ANS FORTH CORE CREATE, #: does not give the word any default
# execution semantics.
        .ascii "#:"
okf_p_create:
        .byte 2
        .long okf_p_input_from_file
        .long okf_comp_default
okf_p_create_exec:
        movl    okf_dict_here, %edi
        movl    okf_in_current, %ebx
        call    okf_in_wsw
        testl   %eax, %eax
        jle     okf_abort
        movl    okf_dict_top, %ebx
        movl    %edi, okf_dict_top
	stosb                              # okf_dh_len
	movl	%ebx, %eax
	stosl                              # okf_dh_next
        leal    okf_comp_default, %eax
	stosl                              # okf_dh_exec
        movl    %edi, okf_dict_here
        ret

        okf_p_dict_top = okf_p_create
