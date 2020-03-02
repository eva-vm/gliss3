project('gliss', 'c', version: '2.3')
make = find_program('make')
ocamlopt = find_program('ocamlopt')
ocamlc = find_program('ocamlc')
ocamldep = find_program('ocamldep')
ocamllex = find_program('ocamllex')
ocamlyacc = find_program('ocamlyacc')

binname = 'gep'
if target_machine.system() == 'windows'
	binname += '.exe'
endif

env = {
	'OCAMLOPT': ocamlopt,
	'OCAMLC': ocamlc,
	'OCAMLDEP': ocamldep,
	'OCAMLLEX': ocamllex,
	'OCAMLYACC': ocamlyacc,
}
command = [find_program('env')]
foreach k,v : env
	command += ['@0@=@1@'.format(k,v.path())]
endforeach
command += [find_program(meson.source_root()/'build.sh'), meson.current_build_dir()]

gep_exe = custom_target(binname,
	build_always_stale: true,
	build_by_default: true,
	install: true,
	install_dir: get_option('bindir'),
	output: binname,
	command: command,
	console: true
)
