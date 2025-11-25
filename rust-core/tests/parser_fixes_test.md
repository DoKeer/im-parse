# Parser Fixes Test Cases

## 1. Blockquote 中的表格

> | Header 1 | Header 2 |
> |----------|----------|
> | Cell 1   | Cell 2   |
> | Cell 3   | Cell 4   |

## 2. List item 中的表格

- Item 1
  
  | Header 1 | Header 2 |
  |----------|----------|
  | Cell 1   | Cell 2   |

- Item 2

## 3. 行内 HTML

This is <span style="color:red">red text</span> and this is <strong>bold</strong>.

## 4. 段落中的 HTML

<div>Custom HTML block</div>

Some text after.

## 5. 嵌套列表（3层）

- Level 1 Item 1
  - Level 2 Item 1
    - Level 3 Item 1
    - Level 3 Item 2
  - Level 2 Item 2
- Level 1 Item 2
  - Level 2 Item 3

## 6. 混合嵌套列表（有序和无序）

1. First ordered item
   - Nested unordered 1
   - Nested unordered 2
     1. Nested ordered 1
     2. Nested ordered 2
2. Second ordered item

## 7. Blockquote 中的嵌套列表

> - Item 1
>   - Nested item 1
>   - Nested item 2
> - Item 2

## 8. List item 中的 blockquote

- Item 1
  
  > This is a quote inside a list item
  
- Item 2

## 9. 复杂嵌套（blockquote + table + list）

> # Header in blockquote
>
> | Col1 | Col2 |
> |------|------|
> | A    | B    |
>
> - List in blockquote
>   - Nested list item

