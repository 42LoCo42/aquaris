project(
	'nix-yaml',
	'cpp',
	default_options: {
		'cpp_std': 'c++23',
		'b_lundef': false,
		'buildtype': 'debugoptimized',
		'warning_level': '3',
	},
)

library(
	'yaml',
	'src/dynamic.cpp',
	install: true,
)

library(
	'nix-yaml',
	'src/nix.cpp',
	dependencies: [
		dependency('nix-expr').partial_dependency(compile_args: true),
		dependency('yaml-cpp'),
	],
	install: true,
)

library(
	'lix-yaml',
	'src/lix.cpp',
	dependencies: [
		dependency('lix-expr').partial_dependency(compile_args: true),
		dependency('yaml-cpp'),
	],
	install: true,
)
