import { spawn } from "node:child_process";

export function launch(exec: string): void {
	const child = spawn("bash", ["-c", exec], {
		detached: true,
		stdio: "ignore",
	});
	child.unref();
}
