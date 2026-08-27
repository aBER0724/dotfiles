import { watch, type FSWatcher } from "node:fs";
import { dirname, join } from "node:path";
import { homedir } from "node:os";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/**
 * Reliably reload the generated nbshell theme.
 *
 * Pi's built-in custom-theme watcher does not consistently react when
 * theme-sync.py atomically replaces nbshell.json. Watching the directory here
 * and explicitly selecting the theme makes both rename and change writes work.
 */
export default function (pi: ExtensionAPI) {
	let watcher: FSWatcher | null = null;
	let timer: ReturnType<typeof setTimeout> | null = null;

	pi.on("session_start", (_event, ctx) => {
		const agentDir = process.env.PI_AGENT_DIR || join(homedir(), ".pi", "agent");
		const themePath = join(agentDir, "themes", "nbshell.json");
		const themeFile = "nbshell.json";

		const applyTheme = () => {
			const theme = ctx.ui.getTheme("nbshell");
			if (!theme) return;
			ctx.ui.setTheme(theme);
		};

		applyTheme();
		watcher = watch(dirname(themePath), (_eventType, filename) => {
			if (filename?.toString() !== themeFile) return;
			if (timer) clearTimeout(timer);
			// Atomic replace can emit several events before the destination settles.
			timer = setTimeout(applyTheme, 75);
		});
	});

	pi.on("session_shutdown", () => {
		if (timer) clearTimeout(timer);
		timer = null;
		watcher?.close();
		watcher = null;
	});
}
