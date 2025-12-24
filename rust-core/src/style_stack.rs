// 样式嵌套安全性增强
//
// 问题：依赖 Vec<InlineStyle> 的 push/pop 顺序来推断嵌套关系
// 解决：显式管理样式栈，检测和处理非法嵌套

use std::collections::HashMap;
use std::fmt;

/// 行内样式（简化版，用于样式栈）
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum InlineStyle {
    Strong,
    Em,
    Strike,
    Link(String),
}

impl InlineStyle {
    /// 获取样式的类型标识（忽略参数）
    pub fn type_id(&self) -> StyleTypeId {
        match self {
            InlineStyle::Strong => StyleTypeId::Strong,
            InlineStyle::Em => StyleTypeId::Em,
            InlineStyle::Strike => StyleTypeId::Strike,
            InlineStyle::Link(_) => StyleTypeId::Link,
        }
    }
}

/// 样式类型标识（用于比较，忽略参数）
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum StyleTypeId {
    Strong,
    Em,
    Strike,
    Link,
}

/// 样式不匹配错误
#[derive(Debug, Clone)]
pub enum StyleMismatch {
    /// 尝试关闭未打开的样式
    NotOpened { style: InlineStyle },
    
    /// 交错嵌套（应该先关闭其他样式）
    Interleaved {
        expected: InlineStyle,
        got: InlineStyle,
        stack_depth: usize,
    },
    
    /// 栈为空但尝试弹出
    EmptyStack,
}

impl fmt::Display for StyleMismatch {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            StyleMismatch::NotOpened { style } => {
                write!(f, "尝试关闭未打开的样式: {:?}", style)
            }
            StyleMismatch::Interleaved { expected, got, stack_depth } => {
                write!(
                    f,
                    "样式嵌套交错: 期望关闭 {:?}, 但遇到 {:?} (栈深度: {})",
                    expected, got, stack_depth
                )
            }
            StyleMismatch::EmptyStack => {
                write!(f, "样式栈为空")
            }
        }
    }
}

/// 样式栈（用于检测和处理嵌套问题）
#[derive(Debug, Clone)]
pub struct StyleStack {
    /// 样式栈（按打开顺序）
    stack: Vec<InlineStyle>,
    
    /// 样式类型 → 栈位置映射（用于快速查找）
    type_positions: HashMap<StyleTypeId, Vec<usize>>,
    
    /// 是否启用严格模式（严格模式下遇到错误会报错，否则尝试修复）
    strict_mode: bool,
    
    /// 错误记录
    errors: Vec<StyleMismatch>,
}

impl StyleStack {
    pub fn new(strict_mode: bool) -> Self {
        Self {
            stack: Vec::new(),
            type_positions: HashMap::new(),
            strict_mode,
            errors: Vec::new(),
        }
    }
    
    /// 创建宽松模式的栈（尝试修复错误）
    pub fn lenient() -> Self {
        Self::new(false)
    }
    
    /// 创建严格模式的栈（遇到错误立即报错）
    pub fn strict() -> Self {
        Self::new(true)
    }
    
    /// 推入样式
    pub fn push(&mut self, style: InlineStyle) {
        let pos = self.stack.len();
        let type_id = style.type_id();
        
        self.type_positions
            .entry(type_id)
            .or_insert_with(Vec::new)
            .push(pos);
        
        self.stack.push(style);
    }
    
    /// 弹出样式
    /// 
    /// 返回：
    /// - Ok(style): 成功弹出
    /// - Err(StyleMismatch): 检测到样式不匹配
    pub fn pop(&mut self, style: &InlineStyle) -> Result<InlineStyle, StyleMismatch> {
        if self.stack.is_empty() {
            let error = StyleMismatch::EmptyStack;
            self.errors.push(error.clone());
            return Err(error);
        }
        
        let type_id = style.type_id();
        
        // 查找样式在栈中的位置
        let positions = self.type_positions.get(&type_id);
        
        if positions.is_none() || positions.unwrap().is_empty() {
            // 样式未打开
            let error = StyleMismatch::NotOpened {
                style: style.clone(),
            };
            self.errors.push(error.clone());
            return Err(error);
        }
        
        // 获取最后一个相同类型的样式位置
        let last_pos = *positions.unwrap().last().unwrap();
        
        // 检查是否是栈顶
        if last_pos != self.stack.len() - 1 {
            // 交错嵌套
            let expected = self.stack.last().unwrap().clone();
            let error = StyleMismatch::Interleaved {
                expected,
                got: style.clone(),
                stack_depth: self.stack.len(),
            };
            self.errors.push(error.clone());
            
            if self.strict_mode {
                return Err(error);
            } else {
                // 宽松模式：尝试修复（强制关闭中间的样式）
                return Ok(self.force_pop_at(last_pos));
            }
        }
        
        // 正常弹出
        let popped = self.stack.pop().unwrap();
        
        // 更新位置映射
        if let Some(positions) = self.type_positions.get_mut(&type_id) {
            positions.pop();
        }
        
        Ok(popped)
    }
    
    /// 强制弹出指定位置的样式（用于修复交错嵌套）
    fn force_pop_at(&mut self, pos: usize) -> InlineStyle {
        let style = self.stack.remove(pos);
        let type_id = style.type_id();
        
        // 更新所有受影响的位置
        for positions in self.type_positions.values_mut() {
            positions.retain(|&p| p != pos);
            for p in positions.iter_mut() {
                if *p > pos {
                    *p -= 1;
                }
            }
        }
        
        style
    }
    
    /// 获取当前样式（栈顶到栈底）
    pub fn current_styles(&self) -> &[InlineStyle] {
        &self.stack
    }
    
    /// 检查栈是否为空
    pub fn is_empty(&self) -> bool {
        self.stack.is_empty()
    }
    
    /// 获取栈深度
    pub fn depth(&self) -> usize {
        self.stack.len()
    }
    
    /// 获取错误记录
    pub fn errors(&self) -> &[StyleMismatch] {
        &self.errors
    }
    
    /// 检查是否有错误
    pub fn has_errors(&self) -> bool {
        !self.errors.is_empty()
    }
    
    /// 清空错误记录
    pub fn clear_errors(&mut self) {
        self.errors.clear();
    }
    
    /// 强制关闭所有未闭合的样式（用于容错）
    pub fn close_all(&mut self) -> Vec<InlineStyle> {
        let remaining = self.stack.clone();
        self.stack.clear();
        self.type_positions.clear();
        remaining
    }
}

impl Default for StyleStack {
    fn default() -> Self {
        Self::lenient()
    }
}

/// 样式树（显式表示嵌套关系）
#[derive(Debug, Clone)]
pub enum StyleTree {
    /// 叶子节点（纯文本）
    Text(String),
    
    /// 样式节点（带子节点）
    Styled {
        style: InlineStyle,
        children: Vec<StyleTree>,
    },
}

impl StyleTree {
    /// 从扁平样式列表构造样式树
    /// 
    /// 假设：样式列表按嵌套顺序排列（外层在前）
    pub fn from_flat_list(content: String, styles: &[InlineStyle]) -> Self {
        if styles.is_empty() {
            return StyleTree::Text(content);
        }
        
        // 从外到内嵌套
        let mut current = StyleTree::Text(content);
        
        for style in styles.iter().rev() {
            current = StyleTree::Styled {
                style: style.clone(),
                children: vec![current],
            };
        }
        
        current
    }
    
    /// 从样式栈构造（使用当前栈状态）
    pub fn from_stack(content: String, stack: &StyleStack) -> Self {
        Self::from_flat_list(content, stack.current_styles())
    }
    
    /// 拍平样式树为扁平列表（用于降级处理）
    pub fn flatten(&self) -> (String, Vec<InlineStyle>) {
        match self {
            StyleTree::Text(content) => (content.clone(), Vec::new()),
            StyleTree::Styled { style, children } => {
                let mut styles = vec![style.clone()];
                if let Some(child) = children.first() {
                    let (content, mut child_styles) = child.flatten();
                    styles.append(&mut child_styles);
                    (content, styles)
                } else {
                    (String::new(), styles)
                }
            }
        }
    }
}

/// 样式验证器
pub struct StyleValidator;

impl StyleValidator {
    /// 验证样式序列是否合法
    /// 
    /// 检查规则：
    /// 1. 所有打开的样式都正确关闭
    /// 2. 没有交错嵌套
    pub fn validate(open_close_pairs: &[(InlineStyle, bool)]) -> Result<(), Vec<StyleMismatch>> {
        let mut stack = StyleStack::strict();
        let mut errors = Vec::new();
        
        for (style, is_open) in open_close_pairs {
            if *is_open {
                stack.push(style.clone());
            } else {
                if let Err(err) = stack.pop(style) {
                    errors.push(err);
                }
            }
        }
        
        // 检查是否有未关闭的样式
        if !stack.is_empty() {
            for style in stack.close_all() {
                errors.push(StyleMismatch::NotOpened { style });
            }
        }
        
        if errors.is_empty() {
            Ok(())
        } else {
            Err(errors)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_style_stack_normal() {
        let mut stack = StyleStack::lenient();
        
        stack.push(InlineStyle::Strong);
        stack.push(InlineStyle::Em);
        
        assert_eq!(stack.depth(), 2);
        
        // 正常弹出
        assert!(stack.pop(&InlineStyle::Em).is_ok());
        assert!(stack.pop(&InlineStyle::Strong).is_ok());
        
        assert!(stack.is_empty());
        assert!(!stack.has_errors());
    }
    
    #[test]
    fn test_style_stack_interleaved_lenient() {
        let mut stack = StyleStack::lenient();
        
        stack.push(InlineStyle::Strong);
        stack.push(InlineStyle::Em);
        
        // 交错关闭（宽松模式应该修复）
        let result = stack.pop(&InlineStyle::Strong);
        assert!(result.is_ok());
        
        // 应该有错误记录
        assert!(stack.has_errors());
    }
    
    #[test]
    fn test_style_stack_interleaved_strict() {
        let mut stack = StyleStack::strict();
        
        stack.push(InlineStyle::Strong);
        stack.push(InlineStyle::Em);
        
        // 交错关闭（严格模式应该报错）
        let result = stack.pop(&InlineStyle::Strong);
        assert!(result.is_err());
    }
    
    #[test]
    fn test_style_stack_not_opened() {
        let mut stack = StyleStack::lenient();
        
        // 尝试关闭未打开的样式
        let result = stack.pop(&InlineStyle::Strong);
        assert!(result.is_err());
        assert!(stack.has_errors());
    }
    
    #[test]
    fn test_style_tree_from_flat() {
        let tree = StyleTree::from_flat_list(
            "text".to_string(),
            &[InlineStyle::Strong, InlineStyle::Em],
        );
        
        // 应该构造嵌套结构：Strong(Em(Text))
        if let StyleTree::Styled { style, children } = tree {
            assert_eq!(style, InlineStyle::Strong);
            assert_eq!(children.len(), 1);
            
            if let StyleTree::Styled { style, .. } = &children[0] {
                assert_eq!(*style, InlineStyle::Em);
            } else {
                panic!("Expected Styled node");
            }
        } else {
            panic!("Expected Styled node");
        }
    }
    
    #[test]
    fn test_style_validator_valid() {
        let pairs = vec![
            (InlineStyle::Strong, true),
            (InlineStyle::Em, true),
            (InlineStyle::Em, false),
            (InlineStyle::Strong, false),
        ];
        
        let result = StyleValidator::validate(&pairs);
        assert!(result.is_ok());
    }
    
    #[test]
    fn test_style_validator_invalid() {
        let pairs = vec![
            (InlineStyle::Strong, true),
            (InlineStyle::Em, true),
            (InlineStyle::Strong, false), // 交错
            (InlineStyle::Em, false),
        ];
        
        let result = StyleValidator::validate(&pairs);
        assert!(result.is_err());
    }
}

