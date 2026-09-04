#include <dlfcn.h>
#include <err.h>
#include <libgen.h>
#include <stdio.h>
#include <string.h>

extern "C" void nix_plugin_entry(void) {
	Dl_info info;
	if(!dladdr((void*) nix_plugin_entry, &info))
		err(1, "failed to find libyaml library directory");

	bool isLix = dlsym(RTLD_DEFAULT, "lixdoc_free_string") != NULL;

	char libPath[1024] = {0};
	snprintf(
		libPath, sizeof(libPath),        //
		"%s/lib%six-yaml.so",            //
		dirname((char*) info.dli_fname), //
		isLix ? "l" : "n"
	);

	void* handle = dlopen(libPath, RTLD_LAZY);
	if(handle == NULL) err(1, "failed to open libyaml: %s", dlerror());

	void (*entry)(void) = (void (*)(void)) dlsym(handle, "nix_plugin_entry");
	if(entry == NULL) err(1, "failed to find entrypoint: %s", dlerror());

	entry();
}
