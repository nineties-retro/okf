okf_vars = bss
okf_ld=ld
okf_as=as
okf_ld_magic_flags_bss=
okf_ld_magic_flags_text=-N
okf_ld_magic_flags=$(okf_ld_magic_flags_$(okf_vars))

okf_dir = . vars/$(okf_vars)
okf_src = okf.s
okf_obj = okf.o

VPATH = $(okf_dir)

all:	okf

okf:	$(okf_obj)
	$(okf_ld) $(okf_ld_magic_flags) -o $@ $(okf_obj)

okf.o:	$(okf_src)
	$(okf_as) $(ASFLAGS) -o $@ $(okf_src) $(okf_dir:%=-I%)

clean:
	rm -f $(okf_obj)

realclean:	clean
	rm -f okf
