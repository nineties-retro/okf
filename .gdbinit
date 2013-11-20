define fdt
  set $okf_dp = okf_dict_top
  while $okf_dp != 0
    print/x $okf_dp
    print/x *((unsigned int *)($okf_dp + 5))
    print/x ($okf_dp + 9)
    set $okf_name_len = *((char *)($okf_dp))
    set $okf_name_addr = $okf_dp - $okf_name_len
    x/3cb $okf_name_addr
    set $okf_dp = *((unsigned int *)(((char *)($okf_dp))+1))
  end
end

define fbp
  b okf_debug_break
  condition 1 (*(int *)$ebp == 0xF)
end
