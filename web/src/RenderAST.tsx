import React from 'react';
import { ASTNode, RootNode } from './types';

interface RenderContext {
  theme: Theme;
  width: number;
  onLinkTap?: (url: string) => void;
  onImageTap?: (node: ImageNode) => void;
  onMentionTap?: (node: MentionNode) => void;
}

interface Theme {
  fontSize: number;
  codeFontSize: number;
  textColor: string;
  linkColor: string;
  codeBackgroundColor: string;
  codeTextColor: string;
  headingColors: string[];
  paragraphSpacing: number;
  listItemSpacing: number;
}

const defaultTheme: Theme = {
  fontSize: 16,
  codeFontSize: 14,
  textColor: '#000000',
  linkColor: '#0066cc',
  codeBackgroundColor: '#f5f5f5',
  codeTextColor: '#000000',
  headingColors: ['#000000', '#000000', '#000000', '#000000', '#000000', '#000000'],
  paragraphSpacing: 8,
  listItemSpacing: 4,
};

export function RenderAST({
  node,
  context = { theme: defaultTheme, width: 0 },
}: {
  node: RootNode;
  context?: RenderContext;
}) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: `${context.theme.paragraphSpacing}px` }}>
      {node.children.map((child, index) => (
        <RenderNode key={index} node={child} context={context} />
      ))}
    </div>
  );
}

function RenderNode({
  node,
  context,
}: {
  node: ASTNode;
  context: RenderContext;
}) {
  switch (node.type) {
    case 'paragraph':
      return <RenderParagraph node={node as ParagraphNode} context={context} />;
    case 'heading':
      return <RenderHeading node={node as HeadingNode} context={context} />;
    case 'codeBlock':
      return <RenderCodeBlock node={node as CodeBlockNode} context={context} />;
    case 'list':
      return <RenderList node={node as ListNode} context={context} />;
    case 'table':
      return <RenderTable node={node as TableNode} context={context} />;
    case 'image':
      return <RenderImage node={node as ImageNode} context={context} />;
    case 'math':
      return <RenderMath node={node as MathNode} context={context} />;
    case 'mermaid':
      return <RenderMermaid node={node as MermaidNode} context={context} />;
    case 'link':
      return <RenderLink node={node as LinkNode} context={context} />;
    case 'mention':
      return <RenderMention node={node as MentionNode} context={context} />;
    case 'blockquote':
      return <RenderBlockquote node={node as BlockquoteNode} context={context} />;
    case 'horizontalRule':
      return <RenderHorizontalRule context={context} />;
    default:
      return null;
  }
}

function RenderParagraph({
  node,
  context,
}: {
  node: ParagraphNode;
  context: RenderContext;
}) {
  return (
    <p style={{ margin: 0 }}>
      {node.children.map((child, index) => (
        <RenderInlineNode key={index} node={child} context={context} />
      ))}
    </p>
  );
}

function RenderHeading({
  node,
  context,
}: {
  node: HeadingNode;
  context: RenderContext;
}) {
  const fontSize = 24 - (node.level - 1) * 2;
  const color = context.theme.headingColors[node.level - 1] || context.theme.textColor;
  const Tag = `h${node.level}` as keyof JSX.IntrinsicElements;

  return (
    <Tag
      style={{
        fontSize: `${fontSize}px`,
        fontWeight: 'bold',
        color,
        margin: 0,
      }}
    >
      {node.children.map((child, index) => (
        <RenderInlineNode key={index} node={child} context={context} />
      ))}
    </Tag>
  );
}

function RenderCodeBlock({
  node,
  context,
}: {
  node: CodeBlockNode;
  context: RenderContext;
}) {
  return (
    <pre
      style={{
        backgroundColor: context.theme.codeBackgroundColor,
        padding: '16px',
        borderRadius: '8px',
        overflowX: 'auto',
        margin: 0,
      }}
    >
      <code
        style={{
          fontSize: `${context.theme.codeFontSize}px`,
          fontFamily: 'monospace',
          color: context.theme.codeTextColor,
        }}
      >
        {node.content}
      </code>
    </pre>
  );
}

function RenderList({
  node,
  context,
}: {
  node: ListNode;
  context: RenderContext;
}) {
  const Tag = node.listType === 'bullet' ? 'ul' : 'ol';

  return (
    <Tag
      style={{
        margin: 0,
        paddingLeft: '24px',
        display: 'flex',
        flexDirection: 'column',
        gap: `${context.theme.listItemSpacing}px`,
      }}
    >
      {node.items.map((item, index) => (
        <li key={index}>
          {item.children.map((child, childIndex) => (
            <RenderInlineNode key={childIndex} node={child} context={context} />
          ))}
        </li>
      ))}
    </Tag>
  );
}

function RenderTable({
  node,
  context,
}: {
  node: TableNode;
  context: RenderContext;
}) {
  return (
    <table
      style={{
        width: '100%',
        borderCollapse: 'collapse',
        border: '1px solid #e0e0e0',
      }}
    >
      <tbody>
        {node.rows.map((row, rowIndex) => (
          <tr
            key={rowIndex}
            style={{
              backgroundColor: rowIndex === 0 ? 'rgba(0, 0, 0, 0.05)' : 'transparent',
            }}
          >
            {row.cells.map((cell, cellIndex) => (
              <td
                key={cellIndex}
                style={{
                  padding: '8px',
                  textAlign: cell.align || 'left',
                }}
              >
                {cell.children.map((child, childIndex) => (
                  <RenderInlineNode key={childIndex} node={child} context={context} />
                ))}
              </td>
            ))}
          </tr>
        ))}
      </tbody>
    </table>
  );
}

function RenderImage({
  node,
  context,
}: {
  node: ImageNode;
  context: RenderContext;
}) {
  return (
    <img
      src={node.url}
      alt={node.alt || ''}
      style={{
        maxWidth: '100%',
        height: 'auto',
        cursor: 'pointer',
      }}
      onClick={() => context.onImageTap?.(node)}
      onError={(e) => {
        // 图片加载失败处理
        console.error('Image load failed:', node.url);
      }}
    />
  );
}

function RenderMath({
  node,
  context,
}: {
  node: MathNode;
  context: RenderContext;
}) {
  // 使用 KaTeX 渲染数学公式
  // 需要安装 react-katex: npm install react-katex katex
  // import { InlineMath, BlockMath } from 'react-katex';
  // import 'katex/dist/katex.min.css';

  return (
    <div
      style={{
        backgroundColor: context.theme.codeBackgroundColor,
        padding: '16px',
        borderRadius: '8px',
        margin: '8px 0',
      }}
    >
      {node.display ? (
        <div>{/* <BlockMath math={node.content} /> */}</div>
      ) : (
        <span>{/* <InlineMath math={node.content} /> */}</span>
      )}
      {/* 临时显示原始内容 */}
      <code>{node.content}</code>
    </div>
  );
}

function RenderMermaid({
  node,
  context,
}: {
  node: MermaidNode;
  context: RenderContext;
}) {
  // 使用 Mermaid.js 渲染图表
  // 需要安装 mermaid: npm install mermaid
  // import mermaid from 'mermaid';

  return (
    <div
      className="mermaid"
      style={{
        backgroundColor: context.theme.codeBackgroundColor,
        padding: '16px',
        borderRadius: '8px',
        margin: '8px 0',
      }}
    >
      {node.content}
    </div>
  );
}

function RenderLink({
  node,
  context,
}: {
  node: LinkNode;
  context: RenderContext;
}) {
  return (
    <a
      href={node.url}
      style={{
        color: context.theme.linkColor,
        textDecoration: 'underline',
        cursor: 'pointer',
      }}
      onClick={(e) => {
        if (context.onLinkTap) {
          e.preventDefault();
          context.onLinkTap(node.url);
        }
      }}
    >
      {node.children.map((child, index) => (
        <RenderInlineNode key={index} node={child} context={context} />
      ))}
    </a>
  );
}

function RenderMention({
  node,
  context,
}: {
  node: MentionNode;
  context: RenderContext;
}) {
  return (
    <span
      style={{
        color: context.theme.linkColor,
        cursor: 'pointer',
      }}
      onClick={() => context.onMentionTap?.(node)}
    >
      @{node.name}
    </span>
  );
}

function RenderBlockquote({
  node,
  context,
}: {
  node: BlockquoteNode;
  context: RenderContext;
}) {
  return (
    <blockquote
      style={{
        margin: 0,
        paddingLeft: '16px',
        borderLeft: `4px solid ${context.theme.textColor}33`,
      }}
    >
      {node.children.map((child, index) => (
        <RenderInlineNode key={index} node={child} context={context} />
      ))}
    </blockquote>
  );
}

function RenderHorizontalRule({ context }: { context: RenderContext }) {
  return (
    <hr
      style={{
        margin: '8px 0',
        border: 'none',
        borderTop: '1px solid #e0e0e0',
      }}
    />
  );
}

function RenderInlineNode({
  node,
  context,
}: {
  node: ASTNode;
  context: RenderContext;
}) {
  switch (node.type) {
    case 'text':
      return <span>{node.content}</span>;
    case 'strong':
      return (
        <strong>
          {node.children.map((child, index) => (
            <RenderInlineNode key={index} node={child} context={context} />
          ))}
        </strong>
      );
    case 'em':
      return (
        <em>
          {node.children.map((child, index) => (
            <RenderInlineNode key={index} node={child} context={context} />
          ))}
        </em>
      );
    case 'underline':
      return (
        <u>
          {node.children.map((child, index) => (
            <RenderInlineNode key={index} node={child} context={context} />
          ))}
        </u>
      );
    case 'strike':
      return (
        <s>
          {node.children.map((child, index) => (
            <RenderInlineNode key={index} node={child} context={context} />
          ))}
        </s>
      );
    case 'code':
      return (
        <code
          style={{
            backgroundColor: context.theme.codeBackgroundColor,
            padding: '2px 4px',
            borderRadius: '4px',
            fontSize: `${context.theme.codeFontSize}px`,
            fontFamily: 'monospace',
            color: context.theme.codeTextColor,
          }}
        >
          {node.content}
        </code>
      );
    case 'link':
      return <RenderLink node={node as LinkNode} context={context} />;
    case 'mention':
      return <RenderMention node={node as MentionNode} context={context} />;
    default:
      return null;
  }
}

// 类型定义
interface ParagraphNode extends ASTNode {
  type: 'paragraph';
  children: ASTNode[];
}

interface HeadingNode extends ASTNode {
  type: 'heading';
  level: number;
  children: ASTNode[];
}

interface CodeBlockNode extends ASTNode {
  type: 'codeBlock';
  language?: string;
  content: string;
}

interface ListNode extends ASTNode {
  type: 'list';
  listType: 'bullet' | 'ordered';
  items: ListItemNode[];
}

interface ListItemNode {
  children: ASTNode[];
  checked?: boolean;
}

interface TableNode extends ASTNode {
  type: 'table';
  rows: TableRow[];
}

interface TableRow {
  cells: TableCell[];
}

interface TableCell {
  children: ASTNode[];
  align?: 'left' | 'center' | 'right';
}

interface ImageNode extends ASTNode {
  type: 'image';
  url: string;
  width?: number;
  height?: number;
  alt?: string;
}

interface MathNode extends ASTNode {
  type: 'math';
  content: string;
  display: boolean;
}

interface MermaidNode extends ASTNode {
  type: 'mermaid';
  content: string;
}

interface LinkNode extends ASTNode {
  type: 'link';
  url: string;
  children: ASTNode[];
}

interface MentionNode extends ASTNode {
  type: 'mention';
  id: string;
  name: string;
}

interface BlockquoteNode extends ASTNode {
  type: 'blockquote';
  children: ASTNode[];
}

