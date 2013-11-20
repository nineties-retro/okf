# Saving space is more important than speed in this initialisation section
# so stosl is used rather than an indexed load via %edi.
        leal    okf_base, %edi
        movl    $16, %eax
        stosl
        leal    okf_dict, %eax
        stosl                                     # dict_here
        leal    okf_p_dict_top, %eax
        stosl                                     # dict_top
        leal    okf_p_in_word_exec, %eax
        stosl                                     # parse_vector
        leal    okf_p_find_exec, %eax
        stosl                                     # find_vector
	leal	okf_defined_interpret, %eax
	stosl                                     # defined_vector
	leal	okf_number_interpret, %eax
	stosl                                     # undefined_vector
	leal	okf_atou, %eax
	stosl                                     # number_vector
	leal	okf_abort_default, %eax
	stosl                                     # not_number_vector
	stosl                                     # abort_vector
	leal	okf_stack, %eax
	stosl                                     # data_end
	leal	okf_stack_end, %eax
	stosl                                     # stack_base
