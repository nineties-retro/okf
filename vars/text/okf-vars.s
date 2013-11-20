okf_argc:		.space okf_cell_size
okf_argv:		.space okf_cell_size
okf_base:		.long 16
okf_dict_here:		.long okf_dict
okf_dict_top:		.long okf_p_dict_top
okf_parse_vector:	.long okf_p_in_word_exec
okf_find_vector:	.long okf_p_find_exec
okf_defined_vector:	.long okf_defined_interpret
okf_undefined_vector:	.long okf_number_interpret
okf_number_vector:	.long okf_atou
okf_not_number_vector:	.long okf_abort_default
okf_abort_vector:	.long okf_abort_default
okf_data_end:		.long okf_stack
okf_stack_base:		.long okf_stack_end
okf_in_current:		.space okf_cell_size
okf_dict:		.space okf_dict_size
okf_stack:		.space okf_stack_size
okf_stack_end:
