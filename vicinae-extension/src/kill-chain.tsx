import {
	Action,
	ActionPanel,
	closeMainWindow,
	Icon,
	List,
	useNavigation,
} from "@vicinae/api";
import { useMemo, useState } from "react";
import { DATA_PATH, loadData, type Tool, type TreeNode } from "./data";
import { launch } from "./launch";
import { classColor } from "./theme";

function nodeIcon(node: TreeNode) {
	return node.icon ? { source: node.icon } : Icon.Folder;
}

function toolIcon(tool: Tool) {
	return tool.icon ? { source: tool.icon } : Icon.Terminal;
}

function countTools(node: TreeNode): number {
	if (node.children.length === 0) return node.tools.length;
	return node.children.reduce((sum, child) => sum + countTools(child), 0);
}

interface Match {
	tool: Tool;
	breadcrumb: string[];
}

function collectTools(node: TreeNode, chain: string[]): Match[] {
	if (node.children.length === 0) {
		return node.tools.map((tool) => ({ tool, breadcrumb: chain }));
	}
	return node.children.flatMap((child) => collectTools(child, [...chain, child.label]));
}

// A one-level preview of what a category/phase row holds
function contentsList(node: TreeNode): string[] {
	if (node.children.length === 0) return node.tools.map((tool) => tool.name);
	return node.children.map((child) => `${child.label} (${countTools(child)})`);
}

function contentsMarkdown(node: TreeNode): string {
	const lines = contentsList(node);
	return lines.length > 0 ? lines.map((line) => `- ${line}`).join("\n") : "_Nothing here yet._";
}

function toolMarkdown(tool: Tool): string {
	const parts: string[] = [];
	if (tool.description) parts.push(tool.description);
	if (tool.snippets.length > 0) {
		const blocks = tool.snippets.map(
			(snippet) => `**${snippet.label}**\n\`\`\`sh\n${snippet.command}\n\`\`\``,
		);
		parts.push(["### Snippets", ...blocks].join("\n\n"));
	}
	return parts.length > 0 ? parts.join("\n\n") : "_No description available._";
}

function ToolItem({ tool, breadcrumb }: { tool: Tool; breadcrumb: string[] }) {
	return (
		<List.Item
			key={tool.id}
			title={tool.name}
			subtitle={tool.genericName ?? undefined}
			icon={toolIcon(tool)}
			keywords={[tool.genericName, tool.comment].filter((s): s is string => Boolean(s))}
			actions={
				<ActionPanel>
					<Action
						title="Launch"
						icon={Icon.ArrowRight}
						onAction={() => {
							launch(tool.exec);
							closeMainWindow();
						}}
					/>
					<Action.CopyToClipboard title="Copy Command" content={tool.exec} />
					{tool.docs ? (
						<Action.OpenInBrowser title="Open Documentation" url={tool.docs} />
					) : null}
					{tool.snippets.map((snippet, i) => (
						<Action.CopyToClipboard
							key={i}
							title={`Copy Snippet: ${snippet.label}`}
							content={snippet.command}
						/>
					))}
				</ActionPanel>
			}
			detail={
				<List.Item.Detail
					markdown={toolMarkdown(tool)}
					metadata={
						<List.Item.Detail.Metadata>
							<List.Item.Detail.Metadata.Label title="Tool" text={tool.name} />
							{breadcrumb.map((crumb, i) => (
								<List.Item.Detail.Metadata.Label
									key={i}
									title={i === 0 ? "Phase" : "Category"}
									text={crumb}
								/>
							))}
							<List.Item.Detail.Metadata.TagList title="Class">
								<List.Item.Detail.Metadata.TagList.Item
									text={tool.markClass}
									color={classColor(tool.markClass)}
								/>
							</List.Item.Detail.Metadata.TagList>
							<List.Item.Detail.Metadata.Separator />
							{tool.genericName ? (
								<List.Item.Detail.Metadata.Label title="Description" text={tool.genericName} />
							) : null}
							{tool.comment ? (
								<List.Item.Detail.Metadata.Label title="Comment" text={tool.comment} />
							) : null}
							<List.Item.Detail.Metadata.Label title="Command" text={tool.exec} />
							{tool.docs ? (
								<List.Item.Detail.Metadata.Link title="Documentation" target={tool.docs} text={tool.docs} />
							) : null}
						</List.Item.Detail.Metadata>
					}
				/>
			}
		/>
	);
}

function NodeScreen({
	node,
	chain,
	isRoot = false,
}: {
	node: TreeNode;
	chain: string[];
	isRoot?: boolean;
}) {
	const { push } = useNavigation();
	const [searchText, setSearchText] = useState("");

	const isLeaf = node.children.length === 0;
	const searching = searchText.trim().length > 0;

	// Every tool reachable under this screen, flattened
	const allTools = useMemo<Match[]>(() => {
		if (isLeaf) return node.tools.map((tool) => ({ tool, breadcrumb: chain }));
		return node.children.flatMap((child) => collectTools(child, [...chain, child.label]));
	}, [node, chain, isLeaf]);

	return (
		<List
			navigationTitle={node.label}
			isShowingDetail
			searchBarPlaceholder={`Search ${node.label}...`}
			searchText={searchText}
			onSearchTextChange={setSearchText}
			filtering
		>
			{isLeaf || searching ? (
				<List.Section
					title={searching ? "Search Results" : node.label}
					subtitle={allTools.length.toString()}
				>
					{allTools.map(({ tool, breadcrumb }) => (
						<ToolItem key={tool.id} tool={tool} breadcrumb={breadcrumb} />
					))}
				</List.Section>
			) : (
				<List.Section title={node.label} subtitle={node.children.length.toString()}>
					{node.children.map((child) => (
						<List.Item
							key={child.id}
							title={child.label}
							icon={nodeIcon(child)}
							accessories={[{ text: `${countTools(child)} tools` }]}
							actions={
								<ActionPanel>
									<Action
										title="Open"
										icon={Icon.ArrowRight}
										onAction={() =>
											push(
												<NodeScreen node={child} chain={isRoot ? [] : [...chain, node.label]} />,
											)
										}
									/>
								</ActionPanel>
							}
							detail={
								<List.Item.Detail
									markdown={contentsMarkdown(child)}
									metadata={
										<List.Item.Detail.Metadata>
											<List.Item.Detail.Metadata.Label title="Category" text={child.label} />
											<List.Item.Detail.Metadata.Label
												title="Tools"
												text={countTools(child).toString()}
											/>
										</List.Item.Detail.Metadata>
									}
								/>
							}
						/>
					))}
				</List.Section>
			)}
		</List>
	);
}

export default function KillChain() {
	let data: ReturnType<typeof loadData>;
	try {
		data = loadData();
	} catch {
		return (
			<List>
				<List.EmptyView
					icon={Icon.Warning}
					title="Catalog data not found"
					description={`${DATA_PATH} is missing. Run home-manager switch (or nixos-rebuild switch) to regenerate it.`}
				/>
			</List>
		);
	}

	const { phases, other } = data;
	const otherNode: TreeNode = {
		id: "other",
		label: "Other",
		markClass: "utility",
		icon: null,
		children: other,
		tools: [],
	};
	const children = other.length > 0 ? [...phases, otherNode] : phases;
	const root: TreeNode = {
		id: "__root__",
		label: "AnNIXion",
		markClass: "utility",
		icon: null,
		children,
		tools: [],
	};

	return <NodeScreen node={root} chain={[]} isRoot />;
}
