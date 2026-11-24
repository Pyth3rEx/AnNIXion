// Semantic class colours
export const CLASS_COLOR: Record<string, string> = {
	passive: "#33e62b",
	probe: "#ffd000",
	offensive: "#ff0033",
	forensic: "#4a90ff",
	reverse: "#f213a0",
	utility: "#7a8494",
};

export function classColor(markClass: string): string {
	return CLASS_COLOR[markClass] ?? CLASS_COLOR.utility;
}
