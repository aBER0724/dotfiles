import { appendFileSync, mkdirSync, readFileSync, unlinkSync, watch, writeFileSync, type FSWatcher } from "node:fs";
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
		const stateDir = join(agentDir, "state");
		const logPath = join(stateDir, "nbshell-theme-watch.log");
		const markerPath = join(stateDir, "nbshell-theme-watch.active");
		mkdirSync(stateDir, { recursive: true });
		writeFileSync(markerPath, `${process.pid}\n`);

		const log = (message: string) => {
			appendFileSync(logPath, `${new Date().toISOString()} pid=${process.pid} ${message}\n`);
		};

		let lastContent = "";
		const applyTheme = () => {
			try {
				const content = readFileSync(themePath, "utf8");
				if (content === lastContent) return;
				const parsed = JSON.parse(content) as { colors?: { accent?: string } };
				// Switch away first: Pi caches registered custom Theme objects by name.
				// Re-selecting nbshell alone can therefore keep the previous colors.
				ctx.ui.setTheme("dark");
				const result = ctx.ui.setTheme("nbshell");
				if (!result.success) {
					log(`apply failed: ${result.error}`);
					return;
				}
				lastContent = content;
				log(`applied accent=${parsed.colors?.accent ?? "unknown"}`);
			} catch (error) {
				log(`apply exception: ${error instanceof Error ? error.message : String(error)}`);
			}
		};

		applyTheme();
		watcher = watch(dirname(themePath), (eventType, filename) => {
			if (filename?.toString() !== themeFile) return;
			log(`event=${eventType} file=${filename.toString()}`);
			if (timer) clearTimeout(timer);
			// Atomic replace can emit several events before the destination settles.
			timer = setTimeout(applyTheme, 150);
		});
		log(`started path=${themePath}`);
	});

	pi.on("session_shutdown", () => {
		if (timer) clearTimeout(timer);
		timer = null;
		watcher?.close();
		watcher = null;
		const agentDir = process.env.PI_AGENT_DIR || join(homedir(), ".pi", "agent");
		try {
			unlinkSync(join(agentDir, "state", "nbshell-theme-watch.active"));
		} catch {}
	});
}
