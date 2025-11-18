// AST 节点类型定义

export type ASTNode =
  | RootNode
  | ParagraphNode
  | HeadingNode
  | TextNode
  | StrongNode
  | EmNode
  | UnderlineNode
  | StrikeNode
  | CodeNode
  | CodeBlockNode
  | LinkNode
  | ImageNode
  | ListNode
  | ListItemNode
  | TableNode
  | TableRow
  | TableCell
  | MathNode
  | MermaidNode
  | CardNode
  | MentionNode
  | HorizontalRuleNode
  | BlockquoteNode;

export interface RootNode {
  type: 'root';
  children: ASTNode[];
}

export interface ParagraphNode {
  type: 'paragraph';
  children: ASTNode[];
}

export interface HeadingNode {
  type: 'heading';
  level: number;
  children: ASTNode[];
}

export interface TextNode {
  type: 'text';
  content: string;
}

export interface StrongNode {
  type: 'strong';
  children: ASTNode[];
}

export interface EmNode {
  type: 'em';
  children: ASTNode[];
}

export interface UnderlineNode {
  type: 'underline';
  children: ASTNode[];
}

export interface StrikeNode {
  type: 'strike';
  children: ASTNode[];
}

export interface CodeNode {
  type: 'code';
  content: string;
}

export interface CodeBlockNode {
  type: 'codeBlock';
  language?: string;
  content: string;
}

export interface LinkNode {
  type: 'link';
  url: string;
  children: ASTNode[];
}

export interface ImageNode {
  type: 'image';
  url: string;
  width?: number;
  height?: number;
  alt?: string;
}

export interface ListNode {
  type: 'list';
  listType: 'bullet' | 'ordered';
  items: ListItemNode[];
}

export interface ListItemNode {
  children: ASTNode[];
  checked?: boolean;
}

export interface TableNode {
  type: 'table';
  rows: TableRow[];
}

export interface TableRow {
  cells: TableCell[];
}

export interface TableCell {
  children: ASTNode[];
  align?: 'left' | 'center' | 'right';
}

export interface MathNode {
  type: 'math';
  content: string;
  display: boolean;
}

export interface MermaidNode {
  type: 'mermaid';
  content: string;
}

export interface CardNode {
  type: 'card';
  subtype: string;
  content: string;
  metadata: Record<string, string>;
}

export interface MentionNode {
  type: 'mention';
  id: string;
  name: string;
}

export interface HorizontalRuleNode {
  type: 'horizontalRule';
}

export interface BlockquoteNode {
  type: 'blockquote';
  children: ASTNode[];
}

