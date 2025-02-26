// https://superuser.com/a/1669834
// https://github.com/tsaost/autoload-temporary-addon/blob/main/userChrome.js

function Run() {
	Services.obs.addObserver(this, "final-ui-startup", false);
}

Run.prototype = {
	observe: async () => {
		const { AddonManager } = Cu.import(
			"resource://gre/modules/AddonManager.jsm",
		);

		const { ExtensionPermissions } = Cu.import(
			"resource://gre/modules/ExtensionPermissions.jsm",
		);

		const { WebExtensionPolicy } = Cu.getGlobalForObject(Services);

		const PRIVATE_BROWSING_PERMS = {
			permissions: ["internal:privateBrowsingAllowed"],
			origins: [],
		};

		const allExtensions = await AddonManager.getAddonsByTypes(["extension"]);

		const privateExtensions = @x@;

		for (const ext of allExtensions) {
			if (!privateExtensions.includes(ext.id)) continue;

			const policy = WebExtensionPolicy.getByID(ext.id);
			const combined = policy && policy.extension;

			await ExtensionPermissions.add(ext.id, PRIVATE_BROWSING_PERMS, combined);

			if (ext.isActive) ext.reload();
		}
	},
};

new Run();
