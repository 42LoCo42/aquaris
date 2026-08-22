project(
	'lix-yaml',
	'cpp',
	default_options: {
		'cpp_std': 'c++23',
		'b_lundef': false,
		'buildtype': 'debug',
		'warning_level': '3',
	},
)

library(
	'lix-yaml',
	'plugin.cpp',
	dependencies: [
		dependency('lix-expr').partial_dependency(compile_args: true),
		dependency('yaml-cpp'),
	],
	install: true,
)
